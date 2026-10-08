import SwiftUI
import StudyCore

struct ReaderView: View {
    @ObservedObject var store: StudyStore
    let course: Course
    @AppStorage("readerFontSize") private var fontSize = ReaderTypography.defaultSize
    var section: Int { store.progress.section }
    var body: some View {
        VStack(spacing: 0) {
            if let record = store.record {
                header(record).fixedSize(horizontal: false, vertical: true)
                Divider()
                GeometryReader { viewport in
                    NativeReaderScroll(
                        offset: store.progress.scrollOffset,
                        onOffset: { value in
                            if abs(store.progress.scrollOffset - value) > 1 {
                                store.setScrollOffset(value)
                            }
                        }
                    ) {
                        VStack(alignment: .leading, spacing: 20) {
                            if section < record.lesson.sections.count {
                                lessonSection(record, index: max(0, section))
                            } else {
                                quizSection(record)
                            }
                        }
                        .font(.system(size: fontSize)).textSelection(.enabled)
                        .padding(.horizontal, 32).padding(.vertical, 28)
                        .frame(maxWidth: 820, alignment: .leading).frame(
                            maxWidth: .infinity, alignment: .top)
                    }.frame(width: viewport.size.width, height: viewport.size.height)
                }.id("\(course.currentPart)-\(section)").clipped()
                Divider()
                footer(record).fixedSize(horizontal: false, vertical: true)
            } else {
                ContentUnavailableView {
                    Label("이 파트의 교재를 준비하세요", systemImage: "book.pages")
                } description: {
                    Text("한 번 생성한 교재는 이 Mac에 저장됩니다.")
                } actions: {
                    Button("교재 준비") { store.loadLesson() }.studyActionStyle(prominent: true)
                        .disabled(store.busy)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    private func header(_ record: LessonRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("파트 \(course.currentPart)")
                Text("· \(record.lesson.minutes)분")
                if course.isDemo { Text("· 샘플") }
                Spacer()
                if course.status == .complete { Label("과정 완료", systemImage: "checkmark.circle") }
            }.font(.callout).foregroundStyle(.secondary)
            Text(record.lesson.title).font(.title2.weight(.semibold)).fixedSize(
                horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                sectionPicker(record).pickerStyle(.segmented).fixedSize(
                    horizontal: true, vertical: false)
                sectionPicker(record).pickerStyle(.menu).fixedSize()
            }
        }.padding(.horizontal, 24).padding(.vertical, 16).frame(
            maxWidth: .infinity, alignment: .leading)
    }
    private func sectionPicker(_ record: LessonRecord) -> some View {
        Picker("내용", selection: Binding(get: { section }, set: { navigate($0) })) {
            ForEach(Array(record.lesson.sections.enumerated()), id: \.offset) { index, _ in
                Text(tabLabel(record.lesson, index: index)).tag(index)
            }
            Text("퀴즈").tag(record.lesson.sections.count)
        }.labelsHidden().disabled(store.busy)
    }
    private func tabLabel(_ lesson: Lesson, index: Int) -> String {
        let kind = lesson.sections[index].kind
        let title =
            ["concept": "개념", "mechanism": "원리", "example": "예제", "summary": "요약"][kind] ?? kind
        guard lesson.sections.filter({ $0.kind == kind }).count > 1 else { return title }
        return "\(title) \(lesson.sections.prefix(index + 1).filter { $0.kind == kind }.count)"
    }
    private func navigate(_ index: Int) {
        store.setProgress {
            $0.section = index; $0.scrollOffset = 0
        }
    }
    @ViewBuilder private func lessonSection(_ record: LessonRecord, index: Int) -> some View {
        let value = record.lesson.sections[index]
        Text(value.title).font(.system(size: fontSize + 4, weight: .semibold))
        MarkdownView(text: value.bodyMarkdown, fontSize: fontSize)
        ForEach(value.visualIds, id: \.self) { id in
            if let visual = record.visuals.first(where: { $0.id == id }),
                let definition = record.lesson.visuals.first(where: { $0.id == id })
            {
                VStack(alignment: .leading, spacing: 12) {
                    if visual.kind == "image", let file = visual.file,
                        let url = try? store.repository.assetURL(
                            directory: record.materialDirectory, name: file),
                        let data = try? VisualSafety.png(url), let image = NSImage(data: data)
                    {
                        Image(nsImage: image).resizable().scaledToFit()
                            .frame(maxWidth: 740, maxHeight: 420).accessibilityLabel(
                                definition.altText)
                        Button {
                            NSWorkspace.shared.open(url)
                        } label: {
                            Label("그림 크게 보기", systemImage: "arrow.up.left.and.arrow.down.right")
                        }.font(.callout).studyActionStyle().help("저장된 원본 그림을 기본 이미지 앱에서 엽니다.")
                    } else if visual.kind == "ascii" {
                        MonospacedBlock(
                            text: visual.content, fontSize: max(12, fontSize - 3), padding: 12
                        )
                        .background(
                            Color(nsColor: .controlBackgroundColor),
                            in: RoundedRectangle(cornerRadius: 6))
                    } else {
                        Label(
                            "저장된 그림을 읽지 못했습니다. 더 보기 메뉴에서 원본 그림 재시도를 선택하세요.",
                            systemImage: "photo.badge.exclamationmark"
                        )
                        .font(.callout).foregroundStyle(.secondary)
                    }
                    Text(definition.caption).font(.system(size: max(14, fontSize - 2)))
                        .foregroundStyle(.secondary).lineSpacing(4)
                    if let reason = visual.fallbackReason {
                        Label(reason, systemImage: "info.circle").font(.caption).foregroundStyle(
                            .secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
            }
        }
        if !value.sourceIds.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("참고 자료").font(.callout.weight(.medium)).foregroundStyle(.secondary)
                ForEach(record.lesson.sources.filter { value.sourceIds.contains($0.id) }) {
                    source in
                    if let url = URL(string: source.url) {
                        Link(source.title, destination: url).font(.callout)
                    }
                }
            }.padding(.top, 4)
        }
    }
    @ViewBuilder private func quizSection(_ record: LessonRecord) -> some View {
        Text("내 말로 설명해보기").font(.system(size: fontSize + 4, weight: .semibold))
        Text("메모나 종이에 풀고, 정답은 원하는 때 펼쳐보세요.").foregroundStyle(.secondary).lineSpacing(4)
        ForEach(Array(record.lesson.quizzes.enumerated()), id: \.element.id) { index, quiz in
            VStack(alignment: .leading, spacing: 12) {
                Text("\(index + 1). \(quiz.question)").font(
                    .system(size: fontSize, weight: .medium)
                ).lineSpacing(4)
                Text("내 답안").font(.callout).foregroundStyle(.secondary)
                TextEditor(
                    text: Binding(
                        get: { store.progress.notes[quiz.id] ?? "" },
                        set: { text in store.setProgress { $0.notes[quiz.id] = text } })
                )
                .font(.system(size: fontSize)).frame(minHeight: 120).padding(8)
                .background(
                    Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6)
                )
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                .accessibilityLabel("문제 \(index + 1) 답안 메모")
                DisclosureGroup(
                    "정답과 해설",
                    isExpanded: Binding(
                        get: { store.progress.revealed.contains(quiz.id) },
                        set: { expanded in
                            store.setProgress {
                                if expanded {
                                    $0.revealed.insert(quiz.id)
                                } else {
                                    $0.revealed.remove(quiz.id)
                                }
                            }
                        })
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        MarkdownView(text: quiz.answer, fontSize: fontSize)
                        MarkdownView(text: quiz.explanation, fontSize: fontSize)
                    }.padding(.top, 12)
                }.font(.callout)
            }.padding(.vertical, 12)
            if index < record.lesson.quizzes.count - 1 { Divider() }
        }
    }
    @ViewBuilder private func footer(_ record: LessonRecord) -> some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    pageCounter(record)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .glassEffect(.regular, in: .capsule)
                    Spacer()
                    navigationButtons(record)
                }
            }
            .controlSize(.large)
            .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 20)
        } else {
            HStack(spacing: 12) {
                pageCounter(record)
                Spacer()
                navigationButtons(record)
            }.padding(.horizontal, 20).padding(.vertical, 10).background(.bar)
        }
    }
    private func pageCounter(_ record: LessonRecord) -> some View {
        Text(
            "\(min(section + 1, record.lesson.sections.count + 1)) / \(record.lesson.sections.count + 1)"
        )
        .font(.callout.monospacedDigit()).foregroundStyle(.secondary)
        .help("읽던 위치와 메모를 자동 저장합니다")
    }
    private func navigationButtons(_ record: LessonRecord) -> some View {
        HStack(spacing: 12) {
            Button {
                navigate(max(0, section - 1))
            } label: {
                Label("이전", systemImage: "chevron.left")
            }
            .keyboardShortcut("[", modifiers: .command).studyActionStyle().disabled(
                section == 0 || store.busy)
            if section < record.lesson.sections.count {
                Button {
                    navigate(section + 1)
                } label: {
                    Label("다음", systemImage: "chevron.right")
                }
                .keyboardShortcut("]", modifiers: .command).studyActionStyle().disabled(store.busy)
            } else {
                Button(course.status == .complete ? "복습 완료" : "파트 완료") { store.complete() }
                    .studyActionStyle(prominent: true).disabled(store.busy)
            }
        }
    }

}
