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
        .navigationTitle(store.selected?.plan.title ?? AppName.display)
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
