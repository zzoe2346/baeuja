import SwiftUI
import UniformTypeIdentifiers
import StudyCore

// Keep the property-wrapper spelling compatible with Command Line Tools.
private typealias ViewState<Value> = SwiftUI.State<Value>

private enum SidebarSelection: Hashable {
    case course(UUID)
    case part(UUID, Int)
}

struct LibraryView: View {
    @ObservedObject var store: StudyStore
    @AppStorage("appearance") private var appearance = "light"
    @AppStorage("readerFontSize") private var fontSize = ReaderTypography.defaultSize
    @ViewState<String> private var search = ""

    private var courses: [Course] {
        store.library.courses.filter {
            search.isEmpty || $0.plan.title.localizedCaseInsensitiveContains(search)
                || $0.plan.topic.localizedCaseInsensitiveContains(search)
        }
    }
    private var selection: Binding<SidebarSelection?> {
        Binding(
            get: {
                guard let course = store.selected else { return nil }
                return course.status == .draft
                    ? .course(course.id) : .part(course.id, course.currentPart)
            },
            set: { value in
                guard !store.busy, let value else { return }
                switch value {
                case .course(let id):
                    if id != store.library.selectedCourseId { store.select(id) }
                case .part(let id, let ordinal):
                    if id != store.library.selectedCourseId { store.select(id) }
                    if ordinal != store.selected?.currentPart { store.setPart(ordinal) }
                }
            })
    }
    var body: some View {
        NavigationSplitView {
            List(selection: selection) {
                Section("보관함") {
                    ForEach(courses) { course in
                        Label {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(course.plan.title)
                                    .font(
                                        .body.weight(
                                            course.id == store.library.selectedCourseId
                                                ? .semibold : .regular)
                                    )
                                    .lineLimit(2)
                                Text(
                                    course.status == .draft
                                        ? "과정 초안"
                                        : "\(course.completionCount)/\(course.plan.parts.count) 완료\(course.isDemo ? " · 샘플" : "")"
                                )
                                .font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(
                                systemName: course.status == .draft
                                    ? "doc.text"
                                    : course.status == .complete
                                        ? "checkmark.circle" : "book.closed"
                            )
                            .foregroundStyle(.secondary)
                        }.tag(SidebarSelection.course(course.id))
                    }
                    if courses.isEmpty && !search.isEmpty {
                        Text("검색 결과가 없습니다").foregroundStyle(.secondary)
                    }
                }
                if let course = store.selected, course.status != .draft {
                    Section("목차") {
                        ForEach(course.plan.parts, id: \.ordinal) { part in
                            Label {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(part.title).font(.body).lineLimit(2)
                                    Text("파트 \(part.ordinal) · \(part.minutes)분").font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(
                                    systemName: course.progress[String(part.ordinal)]?.completed
                                        == true ? "checkmark.circle.fill" : "circle"
                                )
                                .foregroundStyle(.secondary)
                            }.tag(SidebarSelection.part(course.id, part.ordinal))
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
            .disabled(store.busy)
        } detail: {
            // The document's AppKit intrinsic size must not enlarge the split column.
            GeometryReader { detail in
                VStack(spacing: 0) {
                    if store.busy {
                        HStack(spacing: 10) {
                            ProgressView().controlSize(.small)
                            Text(store.activity).font(.callout)
                            Spacer()
                            Button("취소") { store.cancel() }
                        }.padding(12).background(.bar)
                        Divider()
                    }
                    if let course = store.selected {
                        if course.status == .draft {
                            PlanEditor(store: store, course: course).id(course.id)
                        } else {
                            ReaderView(store: store, course: course).id(course.id)
                        }
                    } else {
                        welcome
                    }
                }.frame(width: detail.size.width, height: detail.size.height, alignment: .top)
                    .clipped()
            }.background(.background)
        }
        .navigationTitle(store.selected?.plan.title ?? "Study Swift")
        .searchable(text: $search, placement: .sidebar, prompt: "보관함 검색")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.showingNewCourse = true
                } label: {
                    Label("새 과정", systemImage: "square.and.pencil").labelStyle(.titleAndIcon)
                }
                .help("새 학습 과정 (⌘N)").disabled(store.busy)
            }
            if store.selected != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.showingReadingOptions.toggle()
                    } label: {
                        Label("읽기 설정", systemImage: "textformat.size").labelStyle(.titleAndIcon)
                    }
                    .help("글자 크기와 테마")
                    .popover(isPresented: $store.showingReadingOptions) {
                        ReadingOptions(fontSize: $fontSize, appearance: $appearance)
                    }
                }
            }
            if store.record != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.exportPDF()
                    } label: {
                        Label("PDF 내보내기", systemImage: "square.and.arrow.up").labelStyle(
                            .titleAndIcon)
                    }
                    .help("파트 PDF 내보내기 (⌘P)").disabled(store.busy)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        store.showingImport = true
                    } label: {
                        Label("교재 가져오기…", systemImage: "square.and.arrow.down")
                    }
                    if store.record != nil {
                        Divider()
                        Button("교재 다시 생성") { store.loadLesson(force: true) }
                        Button("원본 그림 재시도") { store.retryVisuals() }
                    }
                } label: {
                    Label("더 보기", systemImage: "ellipsis").labelStyle(.titleAndIcon)
                }.disabled(store.busy)
            }
        }
        .sheet(isPresented: $store.showingNewCourse) { NewCourseView(store: store) }
        .alert(
            "확인이 필요합니다",
            isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })
        ) {
            Button("확인") { store.error = nil }
        } message: {
            Text(store.error ?? "")
        }
        .sheet(isPresented: $store.completionPresented) { CompletionView(store: store) }
        .fileImporter(isPresented: $store.showingImport, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): store.importLesson(url);
            case .failure(let error): store.error = error.localizedDescription
            }
        }
    }
    private var welcome: some View {
        ContentUnavailableView {
            Label("새로운 공부를 시작하세요", systemImage: "book.closed")
        } description: {
            Text("궁금한 주제로 학습 계획을 만들거나 교재 파일을 가져오세요.")
        } actions: {
            Button("새 학습 과정") { store.showingNewCourse = true }.studyActionStyle(prominent: true)
            Button("샘플 교재 둘러보기") { store.addSample() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ReadingOptions: View {
    @Binding var fontSize: Double
    @Binding var appearance: String
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("읽기 설정").font(.headline)
            HStack {
                Text("본문 크기")
                Spacer()
                Text("\(Int(fontSize))pt").monospacedDigit().foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Image(systemName: "textformat.size.smaller").foregroundStyle(.secondary)
                Slider(value: $fontSize, in: ReaderTypography.sizeRange, step: 1)
                    .accessibilityLabel("본문 크기")
                Image(systemName: "textformat.size.larger").foregroundStyle(.secondary)
            }
            Picker("테마", selection: $appearance) {
                Text("밝게").tag("light")
                Text("어둡게").tag("dark")
                Text("시스템").tag("system")
            }.pickerStyle(.segmented)
            Button("기본 18pt로 복원") { fontSize = ReaderTypography.defaultSize }.studyActionStyle()
                .help("기본 글자 크기 (⌘0)")
        }.padding(20).frame(width: 260)
    }
}

struct NewCourseView: View {
    @ObservedObject var store: StudyStore
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("새 학습 과정").font(.title2.weight(.semibold))
            Text("어떤 주제를 공부하고 싶나요?").font(.body)
            TextField("예: 별의 일생, 미분의 의미, B-tree 인덱스", text: $store.newTopic, axis: .vertical)
                .textFieldStyle(.roundedBorder).font(.system(size: 17)).lineLimit(2...4).onSubmit {
                    create()
                }
            Text("먼저 목표와 계획을 확인합니다. 파트는 30~45분이며, 시작 전에 편집할 수 있습니다.")
                .font(.callout).foregroundStyle(.secondary)
            if store.busy {
                HStack {
                    ProgressView().controlSize(.small); Text(store.activity).font(.callout);
                    Button("취소") { store.cancel() }
                }
            }
            HStack {
                Button("취소") { store.showingNewCourse = false }.keyboardShortcut(.cancelAction)
                    .disabled(store.busy)
                Spacer()
                Button(store.busy ? "구성 중…" : "계획 만들기") { create() }
                    .keyboardShortcut(.defaultAction).studyActionStyle(prominent: true)
                    .disabled(store.busy || store.newTopic.trimmed.isEmpty)
            }.padding(.top, 8)
        }.padding(24).frame(width: 460).interactiveDismissDisabled(store.busy)
    }
    private func create() {
        if !store.busy && !store.newTopic.trimmed.isEmpty {
            store.requestPlan(topic: store.newTopic)
        }
    }
}

private struct EditingPart: Identifiable {
    var id = UUID(); var title: String; var minutes: Int; var goals: String
}

struct PlanEditor: View {
    @ObservedObject var store: StudyStore
    let course: Course
    @ViewState<String> private var title = ""
    @ViewState<String> private var goals = ""
    @ViewState<String> private var scope = ""
    @ViewState<[EditingPart]> private var parts = []
    @ViewState<String> private var adjustment = ""
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("학습 계획", systemImage: "list.bullet.clipboard")
                Spacer()
                Text("시작 전에 편집할 수 있습니다").foregroundStyle(.secondary)
            }.font(.callout).padding(20)
            Divider()
            Form {
                Section("공부할 주제") {
                    TextField("제목", text: $title).accessibilityLabel("과정 제목")
                }
                Section("학습 목표 · 한 줄에 하나") {
                    TextEditor(text: $goals).font(.system(size: 16)).frame(minHeight: 90)
                        .accessibilityLabel("학습 목표")
                }
                Section("학습 범위") {
                    TextEditor(text: $scope).font(.system(size: 16)).frame(minHeight: 90)
                        .accessibilityLabel("학습 범위")
                }
                ForEach($parts) { $part in
                    Section("파트 \((parts.firstIndex(where: { $0.id == part.id }) ?? 0) + 1)") {
                        TextField("제목", text: $part.title)
                        Stepper("학습 시간 · \(part.minutes)분", value: $part.minutes, in: 30...45)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("이 파트의 목표 · 한 줄에 하나").font(.callout).foregroundStyle(.secondary)
                            TextEditor(text: $part.goals).font(.system(size: 16)).frame(
                                minHeight: 100
                            ).accessibilityLabel("파트 목표")
                        }
                        Button(role: .destructive) {
                            parts.removeAll { $0.id == part.id }
                        } label: {
                            Label("파트 삭제", systemImage: "minus.circle")
                        }.disabled(parts.count == 1)
                    }
                }
                Section {
                    Button {
                        parts.append(EditingPart(title: "새로운 파트", minutes: 30, goals: ""))
                    } label: {
                        Label("파트 추가", systemImage: "plus")
                    }.disabled(parts.count >= 20)
                }
                Section("AI에게 계획 조정 요청") {
                    TextField("예: 수식을 줄이고 생활 속 예제를 늘려줘", text: $adjustment)
                    Button("요청대로 조정") { adjust() }.disabled(adjustment.trimmed.isEmpty)
                }
            }.formStyle(.grouped)
            Divider()
            HStack {
                Button("계획 저장") { save(false) }.studyActionStyle()
                Spacer()
                Button("이 계획으로 시작") { save(true) }.studyActionStyle(prominent: true)
            }.padding(16).background(.bar)
        }.disabled(store.busy)
            .onAppear { load(course.plan) }
            .onChange(of: course.plan) { _, plan in load(plan) }
    }
    func load(_ plan: Plan) {
        title = plan.title; goals = plan.objectives.joined(separator: "\n"); scope = plan.scope;
        parts = plan.parts.map {
            EditingPart(
                title: $0.title, minutes: $0.minutes, goals: $0.objectives.joined(separator: "\n"))
        }
    }
    func editedPlan() -> Plan {
        Plan(
            topic: course.plan.topic, title: title,
            objectives: goals.components(separatedBy: "\n").map(\.trimmed).filter { !$0.isEmpty },
            scope: scope,
            parts: parts.enumerated().map { index, part in
                PlanPart(
                    ordinal: index + 1, title: part.title,
                    objectives: part.goals.components(separatedBy: "\n").map(\.trimmed).filter {
                        !$0.isEmpty
                    }, minutes: part.minutes)
            })
    }
    func save(_ start: Bool) { store.savePlan(editedPlan(), start: start) }
    func adjust() {
        let plan = editedPlan()
        do {
            try plan.validate();
            store.requestPlan(topic: course.plan.topic, previous: plan, adjustment: adjustment)
        } catch { store.error = error.localizedDescription }
    }
}

struct CompletionView: View {
    @ObservedObject var store: StudyStore
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("기본 과정을 마쳤어요", systemImage: "checkmark.seal")
                .font(.title2.weight(.semibold))
            Text("완료한 파트는 언제든 다시 읽을 수 있습니다. 더 궁금한 주제는 선택할 때 새 과정으로 이어집니다.").foregroundStyle(
                .secondary)
            if let record = store.record {
                ForEach(Array(record.lesson.followUps.enumerated()), id: \.offset) { _, follow in
                    Button {
                        store.completionPresented = false; store.newTopic = follow.topic;
                        store.showingNewCourse = true
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(follow.topic).font(.headline).lineLimit(nil).fixedSize(
                                horizontal: false, vertical: true)
                            Text(follow.reason).font(.callout).foregroundStyle(.secondary)
                                .lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                        }.multilineTextAlignment(.leading).frame(
                            maxWidth: .infinity, alignment: .leading
                        ).padding(8)
                    }.studyActionStyle()
                }
            }
            HStack {
                Spacer();
                Button("교재로 돌아가기") { store.completionPresented = false }.keyboardShortcut(
                    .cancelAction
                ).studyActionStyle()
            }
        }.padding(24).frame(width: 460)
    }
}
