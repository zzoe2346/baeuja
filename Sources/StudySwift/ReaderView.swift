import SwiftUI
import StudyCore

struct ReaderView: View {
    @ObservedObject var store: StudyStore
    let course: Course
    @AppStorage("readerFontSize") private var fontSize = 18.0
    var section: Int { store.progress.section }
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                Text("학습 과정").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(course.plan.title).font(.system(size: 17, weight: .semibold)).lineSpacing(5)
                Text("\(course.completionCount) / \(course.plan.parts.count) 파트 완료").font(.caption).foregroundStyle(.secondary)
                Divider()
                ForEach(course.plan.parts, id: \.ordinal) { part in
                    Button { store.setPart(part.ordinal) } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: course.progress[String(part.ordinal)]?.completed == true ? "checkmark.circle.fill" : course.currentPart == part.ordinal ? "circle.inset.filled" : "circle").foregroundStyle(course.currentPart == part.ordinal ? Color.accentColor : Color.secondary)
                            VStack(alignment: .leading, spacing: 6) { Text(part.title).font(.system(size: 14, weight: course.currentPart == part.ordinal ? .semibold : .regular)).multilineTextAlignment(.leading); Text("PART \(String(format: "%02d", part.ordinal)) · \(part.minutes)분").font(.caption).foregroundStyle(.secondary) }
                            Spacer(minLength: 0)
                        }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(course.currentPart == part.ordinal ? Color.accentColor.opacity(0.09) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.plain).disabled(store.busy)
                }
                Spacer()
                if course.isDemo { Label("고정 샘플 교재", systemImage: "leaf").font(.caption).foregroundStyle(.secondary) }
                if course.status == .complete { Label("기본 과정 완료", systemImage: "checkmark.seal").font(.callout).foregroundStyle(.green) }
            }.padding(20).frame(width: 220).background(Color.primary.opacity(0.025))
            Divider()
            VStack(spacing: 0) {
                if let record = store.record {
                    header(record)
                    Divider()
                    NativeReaderScroll(offset: store.progress.scrollOffset, onOffset: { value in if abs(store.progress.scrollOffset - value) > 1 { store.setProgress { $0.scrollOffset = value } } }) {
                        VStack(alignment: .leading, spacing: 26) {
                            if section < record.lesson.sections.count { lessonSection(record, index: max(0, section)) }
                            else { quizSection(record) }
                            Divider().padding(.top, 14)
                            HStack {
                                Button("이전 내용") { navigate(max(0, section - 1)) }.disabled(section == 0)
                                Spacer()
                                if section < record.lesson.sections.count { Button("다음 내용") { navigate(section + 1) }.buttonStyle(.borderedProminent) }
                                else { Button(course.status == .complete ? "복습 완료" : "이 파트 완료 · 다음") { store.complete() }.buttonStyle(.borderedProminent).disabled(store.busy) }
                            }
                        }.font(.system(size: fontSize)).textSelection(.enabled).padding(.horizontal, 42).padding(.vertical, 36).frame(maxWidth: 900, alignment: .leading).frame(maxWidth: .infinity, alignment: .top)
                    }.id("\(course.currentPart)-\(section)")
                    footer(record)
                } else {
                    VStack(spacing: 18) { Image(systemName: "book.pages").font(.system(size: 44)).foregroundStyle(Color.accentColor); Text("이 파트의 교재를 준비해볼까요?").font(.title2.bold()); Text("한 번 생성한 교재는 이 Mac에 저장되어 다시 읽을 수 있습니다.").foregroundStyle(.secondary); Button("교재 준비") { store.loadLesson() }.buttonStyle(.borderedProminent).disabled(store.busy) }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
    func header(_ record: LessonRecord) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("PART \(String(format: "%02d", course.currentPart))").font(.caption.weight(.bold)).foregroundStyle(Color.accentColor); Text("·  \(record.lesson.minutes)분").font(.caption).foregroundStyle(.secondary); Spacer(); Menu { Button("교재 다시 생성") { store.loadLesson(force: true) }; Button("원본 그림 재시도") { store.retryVisuals() } } label: { Image(systemName: "ellipsis.circle") }.menuStyle(.borderlessButton).frame(width: 24).disabled(store.busy) }
            Text(record.lesson.title).font(.system(size: 28, weight: .bold)).lineLimit(2)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(record.lesson.sections.enumerated()), id: \.offset) { index, item in tab(tabLabel(record.lesson, index: index), index: index).help(item.title) }
                    tab("퀴즈", index: record.lesson.sections.count)
                }
            }
        }.padding(.horizontal, 32).padding(.vertical, 22)
    }
    func tab(_ value: String, index: Int) -> some View {
        Button { navigate(index) } label: { Text(value).font(.system(size: 13, weight: .semibold)).padding(.horizontal, 15).padding(.vertical, 8).foregroundStyle(section == index ? Color.accentColor : Color.secondary).background(section == index ? Color.accentColor.opacity(0.1) : Color.primary.opacity(0.035), in: Capsule()) }.buttonStyle(.plain)
    }
    func label(_ kind: String) -> String { ["concept": "개념", "mechanism": "원리", "example": "예제", "summary": "요약"][kind] ?? kind }
    func tabLabel(_ lesson: Lesson, index: Int) -> String {
        let kind = lesson.sections[index].kind, title = label(kind)
        guard lesson.sections.filter({ $0.kind == kind }).count > 1 else { return title }
        return "\(title) \(lesson.sections.prefix(index + 1).filter { $0.kind == kind }.count)"
    }
    func navigate(_ index: Int) { store.setProgress { $0.section = index; $0.scrollOffset = 0 } }
    @ViewBuilder func lessonSection(_ record: LessonRecord, index: Int) -> some View {
        let value = record.lesson.sections[index]
        Text(value.title).font(.system(size: fontSize + 7, weight: .semibold))
        MarkdownView(text: value.bodyMarkdown, fontSize: fontSize)
        ForEach(value.visualIds, id: \.self) { id in
            if let visual = record.visuals.first(where: { $0.id == id }), let definition = record.lesson.visuals.first(where: { $0.id == id }) {
                VStack(alignment: .leading, spacing: 16) {
                    Label("그림으로 이해하기", systemImage: "point.3.connected.trianglepath.dotted").font(.callout.weight(.semibold)).foregroundStyle(Color.accentColor)
                    if visual.kind == "image", let file = visual.file, let url = try? store.repository.assetURL(directory: record.materialDirectory, name: file), let data = try? VisualSafety.png(url), let image = NSImage(data: data) {
                        Image(nsImage: image).resizable().scaledToFit().frame(maxHeight: 420).accessibilityLabel(definition.altText)
                    } else if visual.kind == "ascii" { Text(visual.content).font(.system(size: max(12, fontSize - 3), design: .monospaced)).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading) }
                    else { Label("저장된 그림을 읽지 못했습니다. 상단 메뉴에서 원본 그림 재시도를 선택하세요.", systemImage: "photo.badge.exclamationmark").font(.callout).foregroundStyle(.secondary) }
                    Text(definition.caption).font(.system(size: fontSize - 2)).lineSpacing(5)
                    if let reason = visual.fallbackReason { Label(reason, systemImage: "info.circle").font(.caption).foregroundStyle(.secondary) }
                }.padding(22).background(Color.accentColor.opacity(0.05), in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.accentColor.opacity(0.15)))
            }
        }
        if !value.sourceIds.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("더 확인하기").font(.callout.weight(.semibold)).foregroundStyle(.secondary)
                ForEach(record.lesson.sources.filter { value.sourceIds.contains($0.id) }) { source in if let url = URL(string: source.url) { Link(destination: url) { Label(source.title, systemImage: "arrow.up.right") }.font(.callout) } }
            }.padding(.top, 6)
        }
    }
    @ViewBuilder func quizSection(_ record: LessonRecord) -> some View {
        Text("내 말로 설명해보기").font(.system(size: fontSize + 7, weight: .semibold))
        Text("메모를 남기거나 종이에 풀어보세요. 정답은 원할 때 펼칠 수 있고, 다음 파트로 가는 조건은 없습니다.").foregroundStyle(.secondary).lineSpacing(6)
        ForEach(Array(record.lesson.quizzes.enumerated()), id: \.element.id) { index, quiz in
            VStack(alignment: .leading, spacing: 16) {
                Text("\(index + 1). \(quiz.question)").font(.system(size: fontSize, weight: .semibold)).lineSpacing(5)
                TextEditor(text: Binding(get: { store.progress.notes[quiz.id] ?? "" }, set: { text in store.setProgress { $0.notes[quiz.id] = text } })).font(.system(size: fontSize - 1)).frame(minHeight: 100).padding(10).background(.background, in: RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                Button(store.progress.revealed.contains(quiz.id) ? "정답 접기" : "정답과 해설 보기") { store.setProgress { if $0.revealed.contains(quiz.id) { $0.revealed.remove(quiz.id) } else { $0.revealed.insert(quiz.id) } } }.buttonStyle(.bordered)
                if store.progress.revealed.contains(quiz.id) {
                    VStack(alignment: .leading, spacing: 10) { Text("정답").font(.callout.bold()).foregroundStyle(Color.accentColor); MarkdownView(text: quiz.answer, fontSize: fontSize); MarkdownView(text: quiz.explanation, fontSize: fontSize - 1) }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(Color.accentColor.opacity(0.065), in: RoundedRectangle(cornerRadius: 10))
                }
            }.padding(22).background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 14))
        }
    }
    func footer(_ record: LessonRecord) -> some View {
        HStack { Image(systemName: "checkmark.circle").foregroundStyle(.green); Text("읽던 위치와 메모 자동 저장"); Spacer(); Text("\(min(section + 1, record.lesson.sections.count + 1)) / \(record.lesson.sections.count + 1) 내용") }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 28).padding(.vertical, 12).background(Color.primary.opacity(0.02))
    }
}

struct MarkdownView: View {
    let text: String
    let fontSize: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(LessonMarkdown.blocks(text).enumerated()), id: \.offset) { _, block in
                switch block.kind {
                case .code(let language): VStack(alignment: .leading, spacing: 10) { if !language.isEmpty { Text(language.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary) }; Text(block.text).font(.system(size: max(13, fontSize - 3), design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading) }.padding(18).background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))
                case .heading(let level): Text(LessonMarkdown.inline(block.text)).font(.system(size: fontSize + Double(max(0, 5 - level)), weight: .semibold))
                case .bullet: HStack(alignment: .top, spacing: 12) { Text("•").foregroundStyle(Color.accentColor); Text(LessonMarkdown.inline(block.text)).frame(maxWidth: .infinity, alignment: .leading) }.font(.system(size: fontSize)).lineSpacing(7)
                case .numbered(let number): HStack(alignment: .top, spacing: 12) { Text("\(number).").foregroundStyle(Color.accentColor); Text(LessonMarkdown.inline(block.text)).frame(maxWidth: .infinity, alignment: .leading) }.font(.system(size: fontSize)).lineSpacing(7)
                case .table(let rows):
                    Grid(alignment: .topLeading, horizontalSpacing: 1, verticalSpacing: 1) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                            GridRow {
                                ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                                    Text(LessonMarkdown.inline(cell)).font(.system(size: max(14, fontSize - 2), weight: rowIndex == 0 ? .semibold : .regular)).lineSpacing(5).frame(maxWidth: .infinity, alignment: .leading).padding(12).background(rowIndex == 0 ? Color.accentColor.opacity(0.09) : Color.primary.opacity(0.025))
                                }
                            }
                        }
                    }.background(Color.primary.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 8))
                case .quote: Text(LessonMarkdown.inline(block.text)).font(.system(size: fontSize)).foregroundStyle(.secondary).padding(.leading, 16).overlay(alignment: .leading) { Rectangle().fill(Color.accentColor.opacity(0.4)).frame(width: 3) }
                case .rule: Divider()
                case .paragraph: Text(LessonMarkdown.inline(block.text)).font(.system(size: fontSize)).lineSpacing(8).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
    }
}

struct NativeReaderScroll<Content: View>: NSViewRepresentable {
    let offset: Double
    let onOffset: (Double) -> Void
    @ViewBuilder let content: () -> Content
    func makeCoordinator() -> Coordinator { Coordinator(onOffset: onOffset, offset: offset) }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = ReaderScrollView(); scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true; scroll.drawsBackground = false
        let host = NSHostingView(rootView: AnyView(content().fixedSize(horizontal: false, vertical: true))); host.translatesAutoresizingMaskIntoConstraints = false
        host.sizingOptions = [.intrinsicContentSize]
        scroll.documentView = host
        NSLayoutConstraint.activate([host.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor)])
        context.coordinator.scroll = scroll
        scroll.onResize = { [weak coordinator = context.coordinator] in coordinator?.resized() }
        scroll.contentView.postsBoundsChangedNotifications = true
        context.coordinator.token = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: scroll.contentView, queue: .main) { [weak coordinator = context.coordinator] _ in coordinator?.changed() }
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.onOffset = onOffset
        context.coordinator.initial = offset
        context.coordinator.makeRoot = { width in AnyView(content().frame(width: width).fixedSize(horizontal: false, vertical: true)) }
        context.coordinator.refresh()
    }
    final class Coordinator {
        weak var scroll: NSScrollView?
        var token: NSObjectProtocol?
        var onOffset: (Double) -> Void
        var initial: Double
        var restored = false
        var adjusting = false
        var width: CGFloat = 0
        var makeRoot: ((CGFloat) -> AnyView)?
        init(onOffset: @escaping (Double) -> Void, offset: Double) { self.onOffset = onOffset; initial = offset }
        func resized() { if let scroll, abs(scroll.contentSize.width - width) > 0.5 { refresh() } }
        func refresh() {
            guard let scroll, let host = scroll.documentView as? NSHostingView<AnyView>, let makeRoot, scroll.contentSize.width > 0 else { return }
            adjusting = true; width = scroll.contentSize.width
            host.rootView = makeRoot(width)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                host.invalidateIntrinsicContentSize(); scroll.layoutSubtreeIfNeeded(); host.layoutSubtreeIfNeeded()
                self.restore(); self.adjusting = false
            }
        }
        func restore() {
            guard let scroll, let view = scroll.documentView else { return }
            restored = true
            let y = min(max(0, initial), max(0, view.frame.height - scroll.contentView.bounds.height))
            scroll.contentView.scroll(to: NSPoint(x: 0, y: y)); scroll.reflectScrolledClipView(scroll.contentView)
        }
        func changed() { guard restored, !adjusting, let scroll else { return }; onOffset(max(0, scroll.contentView.bounds.origin.y)) }
        deinit { if let token { NotificationCenter.default.removeObserver(token) } }
    }
}

private final class ReaderScrollView: NSScrollView {
    var onResize: (() -> Void)?
    override func layout() { super.layout(); onResize?() }
}
