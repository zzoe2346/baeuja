import SwiftUI
import StudyCore

@MainActor final class StudyStore: ObservableObject {
    @Published private(set) var library = LibraryState()
    @Published var busy = false
    @Published var activity = ""
    @Published var error: String?
    @Published var newTopic = ""
    @Published var showingNewCourse = false
    @Published var completionPresented = false
    let repository: LibraryRepository
    private var writable = true
    private var job: Task<Void, Never>?
    init(root: URL) {
        do { repository = try LibraryRepository(root: root) }
        catch { repository = .unavailable(root: root); writable = false; self.error = "학습 자료 폴더를 준비하지 못했습니다. 저장과 생성을 중지했습니다. \(error.localizedDescription)" }
        if writable {
            do { library = try repository.load() }
            catch { writable = false; self.error = "저장된 보관함을 읽지 못했습니다. 원본을 덮어쓰지 않습니다. \(error.localizedDescription)" }
        }
        if ProcessInfo.processInfo.arguments.contains("--demo") && library.courses.isEmpty && writable { addSample() }
    }
    var selected: Course? { library.courses.first { $0.id == library.selectedCourseId } }
    var record: LessonRecord? { selected?.lessons[String(selected?.currentPart ?? 1)] }
    var progress: PartProgress { selected?.progress[String(selected?.currentPart ?? 1)] ?? PartProgress() }
    func commit(_ change: (inout LibraryState) throws -> Void) {
        guard writable else { error = "보관함을 읽지 못해 저장을 중지했습니다. 원본 파일을 확인하세요."; return }
        do { var next = library; try change(&next); try repository.save(next); library = next }
        catch { self.error = "저장하지 못했습니다. \(error.localizedDescription)" }
    }
    func update(_ id: UUID? = nil, _ change: (inout Course) throws -> Void) {
        guard let id = id ?? library.selectedCourseId else { return }
        commit { state in if let index = state.courses.firstIndex(where: { $0.id == id }) { try change(&state.courses[index]) } }
    }
    func select(_ id: UUID?) { commit { $0.selectedCourseId = id } }
    func addSample() { var course = DemoContent.course(); course.id = UUID(); commit { $0.courses.append(course); $0.selectedCourseId = course.id } }
    func setPart(_ ordinal: Int) {
        guard selected?.plan.parts.contains(where: { $0.ordinal == ordinal }) == true else { return }
        update { $0.currentPart = ordinal }
    }
    func setProgress(_ change: (inout PartProgress) -> Void) {
        update { course in let key = String(course.currentPart); var value = course.progress[key] ?? PartProgress(); change(&value); course.progress[key] = value }
    }
    func complete() {
        guard record != nil else { error = "교재를 준비한 뒤 현재 파트를 완료할 수 있습니다."; return }
        update { $0.completeCurrent() }; completionPresented = selected?.status == .complete
        if selected?.status == .active && record == nil { loadLesson() }
    }
    func savePlan(_ plan: Plan, start: Bool = false) {
        guard selected?.status == .draft else { return }
        do { try plan.validate(); update { $0.plan = plan; if start { $0.status = .active } }; if start { loadLesson() } }
        catch { self.error = error.localizedDescription }
    }
    var client: CodexClient {
        var config = CodexSettings(executable: UserDefaults.standard.string(forKey: "codexExecutable") ?? CodexSettings.defaultExecutable)
        config.search = UserDefaults.standard.string(forKey: "searchMode") ?? "cached"
        return CodexClient(root: repository.root, settings: config)
    }
    func run(_ message: String, work: @escaping () async throws -> Void) {
        guard writable else { error = "보관함을 읽지 못해 생성을 시작하지 않았습니다. 원본 저장 파일을 확인하세요."; return }
        guard !busy else { return }; busy = true; activity = message
        job = Task { [weak self] in
            defer { self?.busy = false; self?.activity = ""; self?.job = nil }
            do { try await work() }
            catch { self?.error = error.localizedDescription }
        }
    }
    func cancel() { job?.cancel() }
    func requestPlan(topic: String, previous: Plan? = nil, adjustment: String? = nil) {
        let oldID = previous == nil ? nil : selected?.id
        let client = self.client
        run("과정의 목표와 파트를 구성하고 있습니다…") { [weak self] in
            let plan = try await client.plan(topic: topic, adjustment: adjustment, previous: previous)
            try Task.checkCancellation()
            guard let self else { return }
            if let oldID { self.update(oldID) { $0.plan = plan } }
            else { let course = Course(plan: plan); self.commit { $0.courses.append(course); $0.selectedCourseId = course.id }; self.showingNewCourse = false; self.newTopic = "" }
        }
    }
    func loadLesson(force: Bool = false) {
        guard let course = selected, course.status != .draft, force || record == nil else { return }
        let ordinal = course.currentPart, client = self.client
        let images = UserDefaults.standard.object(forKey: "generateImages") as? Bool ?? true
        run("교재와 시각자료를 준비하고 있습니다…") { [weak self] in
            guard let self else { return }
            let lesson: Lesson
            if course.isDemo { lesson = DemoContent.lesson(ordinal: ordinal) }
            else { lesson = try await client.lesson(plan: course.plan, ordinal: ordinal) }
            let (relative, directory) = try self.repository.materialDirectory()
            var committed = false
            defer { if !committed { try? FileManager.default.removeItem(at: directory) } }
            let renderer = VisualRenderer()
            let provider: ((String, URL) async throws -> Void)? = images && !course.isDemo ? { prompt, output in try await client.image(prompt: prompt, destination: output) } : nil
            let visuals = try await renderer.render(lesson, directory: directory, image: provider)
            try Task.checkCancellation()
            try StudyJSON.encoder().encode(lesson).write(to: directory.appendingPathComponent("lesson.json"), options: .atomic)
            let record = LessonRecord(lesson: lesson, visuals: visuals, materialDirectory: relative)
            self.update(course.id) { $0.lessons[String(ordinal)] = record }
            committed = self.library.courses.first(where: { $0.id == course.id })?.lessons[String(ordinal)]?.revision == record.revision
        }
    }
    func retryVisuals() {
        guard let course = selected, let old = record else { return }
        let ordinal = course.currentPart, client = self.client
        let images = UserDefaults.standard.object(forKey: "generateImages") as? Bool ?? true
        run("저장된 그림 정의로 원본을 다시 준비하고 있습니다…") { [weak self] in
            guard let self else { return }; let (relative, directory) = try self.repository.materialDirectory(); var committed = false
            defer { if !committed { try? FileManager.default.removeItem(at: directory) } }
            let provider: ((String, URL) async throws -> Void)? = images && !course.isDemo ? { prompt, output in try await client.image(prompt: prompt, destination: output) } : nil
            let visuals = try await VisualRenderer().render(old.lesson, directory: directory, image: provider)
            try Task.checkCancellation()
            let value = LessonRecord(lesson: old.lesson, visuals: visuals, materialDirectory: relative)
            try StudyJSON.encoder().encode(old.lesson).write(to: directory.appendingPathComponent("lesson.json"), options: .atomic)
            self.update(course.id) { $0.lessons[String(ordinal)] = value }
            committed = self.library.courses.first(where: { $0.id == course.id })?.lessons[String(ordinal)]?.revision == value.revision
        }
    }
    func importLesson(_ url: URL) {
        run("교재 파일과 그림을 확인하고 있습니다…") { [weak self] in
            guard let self else { return }
            let accessed = url.startAccessingSecurityScopedResource(); defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let lesson = try StudyJSON.read(Lesson.self, from: url); try lesson.validate()
            let (relative, directory) = try self.repository.materialDirectory()
            var committed = false; defer { if !committed { try? FileManager.default.removeItem(at: directory) } }
            // Import never makes an AI call, including image generation.
            let visuals = try await VisualRenderer().render(lesson, directory: directory)
            let plan = Plan(topic: lesson.title, title: lesson.title, objectives: ["가져온 교재를 읽고 이해한다"], scope: "가져온 파트 한 개", parts: [PlanPart(ordinal: 1, title: lesson.title, objectives: ["교재와 퀴즈를 학습한다"], minutes: lesson.minutes)])
            var course = Course(plan: plan); course.status = .active
            let record = LessonRecord(lesson: lesson, visuals: visuals, materialDirectory: relative); course.lessons["1"] = record
            try Task.checkCancellation(); try StudyJSON.encoder().encode(lesson).write(to: directory.appendingPathComponent("lesson.json"), options: .atomic)
            self.commit { $0.courses.append(course); $0.selectedCourseId = course.id }
            committed = self.library.courses.contains(where: { $0.id == course.id })
        }
    }
    func exportPDF() {
        guard let record else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.pdf]; panel.nameFieldStringValue = "\(record.lesson.title).pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try PDFExporter.export(record: record, repository: repository, to: url); NSWorkspace.shared.open(url) }
        catch { self.error = error.localizedDescription }
    }
}
