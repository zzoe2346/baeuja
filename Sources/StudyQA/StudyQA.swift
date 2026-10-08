import Foundation
import AppKit
import PDFKit
import StudyCore

@main enum StudyQA {
    @MainActor static func main() {
        let app = NSApplication.shared; app.setActivationPolicy(.prohibited)
        Task { @MainActor in
            do { try await run(); print("QA 완료"); exit(0) } catch {
                fputs("QA 실패: \(error.localizedDescription)\n", stderr); exit(1)
            }
        }
        app.run()
    }
    @MainActor static func run() async throws {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--data-dir"), args.indices.contains(index + 1) else {
            throw StudyError.invalid("--data-dir로 QA 전용 폴더를 지정하세요.")
        }
        let root = URL(fileURLWithPath: args[index + 1], isDirectory: true)
        let repository = try LibraryRepository(root: root), client = CodexClient(root: root)
        var state = try repository.load()
        if args.contains("--live-image") {
            try await client.image(
                prompt:
                    "A simple educational botanical illustration of a green leaf receiving sunlight, with water entering from below and oxygen leaving. Clean white background, no text, no logos.",
                destination: root.appendingPathComponent("native-image.png"))
            print("실제 구독 PNG 생성 검증 완료")
        }
        if args.contains("--live") {
            let plan = try await client.plan(topic: "광합성의 기본 원리. 처음 공부하는 사람을 위한 한 파트 과정")
            print("실제 과정 생성: \(plan.parts.count)개 파트")
            let lesson = try await client.lesson(plan: plan, ordinal: 1)
            let (relative, directory) = try repository.materialDirectory()
            let visuals = try await VisualRenderer().render(
                lesson, directory: directory,
                image: { prompt, output in
                    try await client.image(prompt: prompt, destination: output)
                })
            var course = Course(plan: plan); course.status = .active
            let record = LessonRecord(lesson: lesson, visuals: visuals, materialDirectory: relative)
            course.lessons["1"] = record; state.courses.append(course);
            state.selectedCourseId = course.id
            try StudyJSON.encoder().encode(plan).write(
                to: root.appendingPathComponent("verified-plan.json"), options: .atomic)
            try StudyJSON.encoder().encode(lesson).write(
                to: root.appendingPathComponent("verified-lesson.json"), options: .atomic)
            try StudyJSON.encoder().encode(lesson).write(
                to: directory.appendingPathComponent("lesson.json"), options: .atomic)
            try repository.save(state); print("실제 교재 생성·시각자료·저장 검증 완료")
            try pdf(record: record, repository: repository, name: "live-part")
        }
        if args.contains("--render-demo") {
            var course = DemoContent.course()
            for ordinal in 1...course.plan.parts.count {
                let lesson = DemoContent.lesson(ordinal: ordinal)
                let renderer = VisualRenderer()
                let preparation = LessonPreparation(repository: repository) {
                    lesson, directory, image in
                    try await renderer.render(lesson, directory: directory, image: image)
                }
                guard
                    let record = try await preparation.prepare(
                        lesson,
                        adopt: { record in
                            guard
                                record.visuals.allSatisfy({
                                    $0.kind == "image" && $0.fallbackReason == nil
                                })
                            else {
                                throw StudyError.invalid(
                                    "유효한 샘플 Mermaid가 렌더링되지 않았습니다: "
                                        + renderer.diagnostics.joined(separator: "; "))
                            }
                            course.lessons[String(ordinal)] = record
                            var next = state
                            if let index = next.courses.firstIndex(where: { $0.id == course.id }) {
                                next.courses[index] = course
                            } else {
                                next.courses.append(course)
                            }
                            next.selectedCourseId = course.id
                            try repository.save(next)
                            state = next
                            return true
                        })
                else { throw StudyError.invalid("QA 교재가 채택되지 않았습니다.") }
                try pdf(record: record, repository: repository, name: "demo-part-\(ordinal)")
            }
            print("공통 자료 준비·로컬 Mermaid·PNG·샘플 PDF 검증 완료")
        }
        if args.contains("--stress-pdf") {
            var record = DemoContent.course().lessons["1"]!
            record.lesson.sections[2].bodyMarkdown +=
                "\n\n```sql\n"
                + String(
                    repeating: "SELECT '" + String(repeating: "long_value_", count: 18) + "';\n",
                    count: 25) + "```\n\n"
                + String(
                    repeating:
                        "한글 문장과 긴 코드의 줄바꿈, 페이지 경계를 확인하는 활동입니다. 읽기 자료는 페이지 폭 안에 배치되어야 합니다.\n\n",
                    count: 25)
            try pdf(record: record, repository: repository, name: "stress-part")
        }
        if args.contains("--reopen") {
            guard let id = state.selectedCourseId,
                let selected = state.courses.first(where: { $0.id == id }),
                selected.lessons["1"] != nil
            else { throw StudyError.invalid("재개할 QA 교재가 없습니다.") }
            print("저장 교재 재개 검증 완료 · AI 호출 없음")
        }
        if args.contains("--verify-saved-visuals") {
            guard let course = state.courses.first(where: { $0.id == state.selectedCourseId }),
                let record = course.lessons[String(course.currentPart)]
            else { throw StudyError.invalid("검증할 저장 교재가 없습니다.") }
            let directory = root.appendingPathComponent("verified-visuals")
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            let renderer = VisualRenderer()
            let visuals = try await renderer.render(record.lesson, directory: directory)
            for visual in visuals {
                print("\(visual.id): \(visual.kind) · 대체 \(visual.fallbackReason != nil)")
            }
            for diagnostic in renderer.diagnostics { print("렌더링 진단: " + diagnostic) }
            guard
                zip(record.lesson.visuals, visuals).allSatisfy({
                    $0.kind == "ascii" || $1.fallbackReason == nil
                })
            else {
                throw StudyError.invalid("원본 그림 렌더링 실패를 대체 도식으로 처리했습니다.")
            }
            print("저장된 원본 시각자료 재검증 완료 · AI 호출·보관함 변경 없음")
        }
        if args.contains("--export-saved") {
            guard let course = state.courses.first(where: { $0.id == state.selectedCourseId }),
                let record = course.lessons[String(course.currentPart)]
            else { throw StudyError.invalid("내보낼 저장 교재가 없습니다.") }
            try pdf(record: record, repository: repository, name: "saved-part")
        }
    }
    @MainActor static func pdf(record: LessonRecord, repository: LibraryRepository, name: String)
        throws
    {
        let output = repository.root.appendingPathComponent(name + ".pdf")
        try PDFExporter.export(record: record, repository: repository, to: output)
        guard let document = PDFDocument(url: output) else {
            throw StudyError.invalid("PDF를 읽을 수 없습니다.")
        }
        let directory = repository.root.appendingPathComponent(name + "-pages")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else {
                throw StudyError.invalid("PDF 페이지가 없습니다.")
            }
            let image = page.thumbnail(of: NSSize(width: 1190, height: 1684), for: .mediaBox)
            guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
                let png = bitmap.representation(using: .png, properties: [:])
            else { throw StudyError.invalid("PDF 페이지를 캡처하지 못했습니다.") }
            try png.write(
                to: directory.appendingPathComponent(String(format: "page-%02d.png", index + 1)))
        }
        let strings = (0..<document.pageCount).map { document.page(at: $0)?.string ?? "" }
        try strings.joined(separator: "\n\n--- PAGE ---\n\n").write(
            to: repository.root.appendingPathComponent(name + "-text.txt"), atomically: true,
            encoding: .utf8)
        func heading(_ value: String, in text: String) -> Bool {
            text.components(separatedBy: .newlines).contains { $0.trimmed == value }
        }
        guard let questions = strings.firstIndex(where: { heading("이해도 확인", in: $0) }),
            let answers = strings.firstIndex(where: { heading("정답과 해설", in: $0) }),
            answers > questions
        else { throw StudyError.invalid("퀴즈 문제와 정답의 페이지 분리를 확인하지 못했습니다.") }
        print("\(name) PDF \(document.pageCount)페이지 · 문제 \(questions + 1) / 정답 \(answers + 1)")
    }
}
