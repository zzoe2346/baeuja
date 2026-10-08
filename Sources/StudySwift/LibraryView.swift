import SwiftUI
import UniformTypeIdentifiers
import StudyCore

// Use the property-wrapper spelling through an alias so Command Line Tools
// builds don't require the Xcode-only SwiftUI macro plugin in the macOS 27 SDK.
private typealias ViewState<Value> = SwiftUI.State<Value>

struct LibraryView: View {
    @ObservedObject var store: StudyStore
    @AppStorage("appearance") private var appearance = "light"
    @AppStorage("readerFontSize") private var fontSize = 18.0
    @ViewState<Bool> private var importing = false
    @ViewState<String> private var search = ""
    var courses: [Course] { store.library.courses.filter { search.isEmpty || $0.plan.title.localizedCaseInsensitiveContains(search) || $0.plan.topic.localizedCaseInsensitiveContains(search) } }
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "book.closed.fill").font(.title2).foregroundStyle(.white).frame(width: 42, height: 42).background(Color.accentColor, in: RoundedRectangle(cornerRadius: 13))
                    VStack(alignment: .leading, spacing: 2) { Text("Study Swift").font(.title3.bold()); Text("조금씩, 깊이 있게").font(.caption).foregroundStyle(.secondary) }
                }.padding(20)
                Text("나의 공부").font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.horizontal, 20).padding(.bottom, 10)
                List(selection: Binding(get: { store.library.selectedCourseId }, set: { store.select($0) })) {
                    ForEach(courses) { course in
                        VStack(alignment: .leading, spacing: 7) {
                            Text(course.plan.title).font(.system(size: 14, weight: .semibold)).lineLimit(2)
                            HStack { Text(course.status == .draft ? "과정 초안" : "\(course.completionCount) / \(course.plan.parts.count) 파트"); if course.isDemo { Text("샘플") } }.font(.caption).foregroundStyle(.secondary)
                            if course.status != .draft { ProgressView(value: Double(course.completionCount), total: Double(course.plan.parts.count)).tint(.accentColor) }
                        }.padding(.vertical, 7).tag(course.id)
                    }
                }.listStyle(.sidebar)
                VStack(spacing: 10) {
                    Button { store.showingNewCourse = true } label: { Label("새 학습 과정", systemImage: "plus").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent)
                    Button { importing = true } label: { Label("교재 가져오기", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity) }.buttonStyle(.bordered)
                    Text("학습 자료와 메모는 이 Mac에 저장됩니다.").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                }.padding(16)
            }.navigationSplitViewColumnWidth(min: 230, ideal: 250, max: 300)
        } detail: {
            VStack(spacing: 0) {
                if store.busy {
                    HStack(spacing: 12) { ProgressView().controlSize(.small); Text(store.activity).font(.callout); Spacer(); Button("생성 취소") { store.cancel() } }.padding(12).background(Color.accentColor.opacity(0.08))
                }
                if let course = store.selected {
                    if course.status == .draft { PlanEditor(store: store, course: course).id(course.id) }
                    else { ReaderView(store: store, course: course).id(course.id) }
                } else { welcome }
            }.background(.background)
        }
        .searchable(text: $search, placement: .sidebar, prompt: "보관함 검색")
        .toolbar {
            ToolbarItemGroup {
                Button { fontSize = max(14, fontSize - 1) } label: { Image(systemName: "textformat.size.smaller") }.help("본문 작게")
                Text("\(Int(fontSize))pt").font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                Button { fontSize = min(28, fontSize + 1) } label: { Image(systemName: "textformat.size.larger") }.help("본문 크게")
                Picker("화면 밝기", selection: $appearance) {
                    Label("밝게", systemImage: "sun.max").tag("light")
                    Label("어둡게", systemImage: "moon").tag("dark")
                    Label("시스템", systemImage: "circle.lefthalf.filled").tag("system")
                }.pickerStyle(.menu).frame(width: 86)
                Button { store.exportPDF() } label: { Label("PDF", systemImage: "arrow.down.document") }.disabled(store.record == nil || store.busy)
            }
        }
        .sheet(isPresented: $store.showingNewCourse) { NewCourseView(store: store) }
        .alert("확인이 필요합니다", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("확인") { store.error = nil } } message: { Text(store.error ?? "") }
        .sheet(isPresented: $store.completionPresented) { CompletionView(store: store) }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result { case .success(let url): store.importLesson(url); case .failure(let error): store.error = error.localizedDescription }
        }
        .disabled(false)
    }
    var welcome: some View {
        VStack(alignment: .leading, spacing: 24) {
            Image(systemName: "sparkles.rectangle.stack").font(.system(size: 46)).foregroundStyle(Color.accentColor)
            Text("궁금한 것을,\n나만의 공부로.").font(.system(size: 38, weight: .bold)).lineSpacing(8)
            Text("하나의 주제로 시작해 목표를 정하고,\n짧은 파트를 읽으며 이해를 쌓아가세요.").font(.system(size: 18)).foregroundStyle(.secondary).lineSpacing(7)
            HStack { Button("새 학습 과정 만들기") { store.showingNewCourse = true }.buttonStyle(.borderedProminent); Button("샘플 교재 둘러보기") { store.addSample() }.buttonStyle(.bordered) }
            HStack(spacing: 30) { Label("글자 크기 조절", systemImage: "textformat.size"); Label("파트별 PDF", systemImage: "doc"); Label("진도 자동 저장", systemImage: "checkmark.circle") }.font(.callout).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading).padding(60)
    }
}

struct NewCourseView: View {
    @ObservedObject var store: StudyStore
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack { Image(systemName: "sparkles").foregroundStyle(Color.accentColor); Text("새로운 공부").font(.title2.bold()); Spacer() }
            Text("어떤 주제를 공부하고 싶나요?").font(.system(size: 23, weight: .semibold))
            Text("소프트웨어 공학, 과학, 역사, 언어 등 궁금한 주제를 입력하세요. 먼저 목표와 과정 초안을 확인합니다.").font(.body).foregroundStyle(.secondary)
            TextField("예: B-tree 인덱스, 별의 일생, 미분의 의미", text: $store.newTopic).textFieldStyle(.roundedBorder).onSubmit { create() }
            Text("30~45분 단위 · 시작 전 계획 조정 · 긴 설문 없이 시작").font(.caption).foregroundStyle(.secondary)
            HStack { Button("닫기") { store.showingNewCourse = false }.keyboardShortcut(.cancelAction); Spacer(); Button(store.busy ? "과정 구성 중…" : "과정 초안 만들기") { create() }.buttonStyle(.borderedProminent).disabled(store.busy || store.newTopic.trimmed.isEmpty) }
            if store.busy { HStack { ProgressView().controlSize(.small); Text(store.activity); Button("취소") { store.cancel() } } }
        }.padding(30).frame(width: 560).interactiveDismissDisabled(store.busy)
    }
    func create() { if !store.busy && !store.newTopic.trimmed.isEmpty { store.requestPlan(topic: store.newTopic) } }
}

private struct EditingPart: Identifiable { var id = UUID(); var title: String; var minutes: Int; var goals: String }

struct PlanEditor: View {
    @ObservedObject var store: StudyStore
    let course: Course
    @ViewState<String> private var title = ""
    @ViewState<String> private var goals = ""
    @ViewState<String> private var scope = ""
    @ViewState<[EditingPart]> private var parts = []
    @ViewState<String> private var adjustment = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Label("시작하기 전에", systemImage: "list.bullet.clipboard").font(.callout.weight(.semibold)).foregroundStyle(Color.accentColor)
                Text("이렇게 공부해볼까요?").font(.system(size: 32, weight: .bold))
                Text("목표와 범위를 살펴보고 필요한 부분을 고치세요. 시작한 뒤에는 계획을 고정하고 파트별로 진행합니다.").foregroundStyle(.secondary)
                Group { field("과정 제목", text: $title); field("학습 목표 · 한 줄에 하나", text: $goals, multiline: true); field("학습 범위", text: $scope, multiline: true) }
                Text("파트별 계획").font(.headline)
                ForEach($parts) { $part in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("파트 \((parts.firstIndex(where: { $0.id == part.id }) ?? 0) + 1)").font(.headline)
                            Spacer()
                            Stepper("\(part.minutes)분", value: $part.minutes, in: 30...45).fixedSize()
                            Button { parts.removeAll { $0.id == part.id } } label: { Image(systemName: "minus.circle") }.help("파트 삭제").disabled(parts.count == 1)
                        }
                        TextField("파트 제목", text: $part.title).textFieldStyle(.roundedBorder).font(.system(size: 17))
                        Text("이 파트의 목표 · 한 줄에 하나").font(.callout).foregroundStyle(.secondary)
                        TextEditor(text: $part.goals).font(.system(size: 16)).frame(minHeight: 150).padding(8).overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                    }.padding(18).background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 12))
                }
                Button { parts.append(EditingPart(title: "새로운 파트", minutes: 30, goals: "")) } label: { Label("파트 추가", systemImage: "plus") }.disabled(parts.count >= 20)
                HStack { Button("계획 저장") { save(false) }; Spacer(); Button("이 계획으로 시작") { save(true) }.buttonStyle(.borderedProminent) }
                Divider()
                Text("AI에게 조정 요청").font(.headline)
                TextField("예: 수식을 줄이고 생활 속 예제를 늘려줘", text: $adjustment).textFieldStyle(.roundedBorder)
                Button("요청대로 과정 조정") { adjust() }.disabled(adjustment.trimmed.isEmpty)
            }.padding(40).frame(maxWidth: 850, alignment: .leading).frame(maxWidth: .infinity)
        }.disabled(store.busy)
            .onAppear { load(course.plan) }
            .onChange(of: course.plan) { _, plan in load(plan) }
    }
    func field(_ name: String, text: Binding<String>, multiline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) { Text(name).font(.headline); if multiline { TextEditor(text: text).font(.system(size: 16)).frame(minHeight: name.hasPrefix("학습 범위") ? 130 : 100).padding(8).overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary)) } else { TextField(name, text: text).textFieldStyle(.roundedBorder).font(.system(size: 18)) } }
    }
    func load(_ plan: Plan) { title = plan.title; goals = plan.objectives.joined(separator: "\n"); scope = plan.scope; parts = plan.parts.map { EditingPart(title: $0.title, minutes: $0.minutes, goals: $0.objectives.joined(separator: "\n")) } }
    func editedPlan() -> Plan {
        Plan(topic: course.plan.topic, title: title, objectives: goals.components(separatedBy: "\n").map(\.trimmed).filter { !$0.isEmpty }, scope: scope,
             parts: parts.enumerated().map { index, part in PlanPart(ordinal: index + 1, title: part.title, objectives: part.goals.components(separatedBy: "\n").map(\.trimmed).filter { !$0.isEmpty }, minutes: part.minutes) })
    }
    func save(_ start: Bool) { store.savePlan(editedPlan(), start: start) }
    func adjust() {
        let plan = editedPlan()
        do { try plan.validate(); store.requestPlan(topic: course.plan.topic, previous: plan, adjustment: adjustment) }
        catch { store.error = error.localizedDescription }
    }
}

struct CompletionView: View {
    @ObservedObject var store: StudyStore
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 44)).foregroundStyle(.green)
            Text("기본 과정을 마쳤어요.").font(.title.bold())
            Text("완료한 파트는 언제든 다시 읽을 수 있습니다. 더 궁금한 주제는 선택할 때 새 과정으로 이어집니다.").foregroundStyle(.secondary)
            if let record = store.record {
                ForEach(Array(record.lesson.followUps.enumerated()), id: \.offset) { _, follow in
                    Button { store.completionPresented = false; store.newTopic = follow.topic; store.showingNewCourse = true } label: { VStack(alignment: .leading) { Text(follow.topic).font(.headline); Text(follow.reason).font(.callout).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding(12) }.buttonStyle(.bordered)
                }
            }
            Button("교재로 돌아가기") { store.completionPresented = false }.keyboardShortcut(.cancelAction)
        }.padding(32).frame(width: 540)
    }
}
