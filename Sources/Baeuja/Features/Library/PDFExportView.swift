import SwiftUI
import StudyCore

private typealias ViewState<Value> = SwiftUI.State<Value>

struct PDFExportView: View {
    @ObservedObject var store: StudyStore
    @Environment(\.dismiss) private var dismiss
    @ViewState<Set<Int>> private var selection: Set<Int> = []
    @ViewState<Bool> private var merged = true

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("PDF 묶음 내보내기").font(.title2.bold())
            Text(store.selected?.plan.title ?? "").foregroundStyle(.secondary)
            HStack {
                Text("\(selection.count)개 파트 선택").font(.headline)
                Spacer()
                Button("전체 선택") { selection = Set(store.exportableParts.map(\.ordinal)) }
                Button("선택 해제") { selection.removeAll() }
            }
            List {
                ForEach(store.selected?.plan.parts ?? [], id: \.ordinal) { part in
                    let ready = store.selected?.lessons[String(part.ordinal)] != nil
                    Toggle(
                        isOn: Binding(
                            get: { selection.contains(part.ordinal) },
                            set: { value in
                                if value {
                                    selection.insert(part.ordinal)
                                } else {
                                    selection.remove(part.ordinal)
                                }
                            }
                        )
                    ) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("파트 \(part.ordinal). \(part.title)")
                            if !ready {
                                Text("아직 생성하지 않은 교재").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }.disabled(!ready)
                }
            }.frame(minHeight: 160, maxHeight: 280)
            Picker("저장 방식", selection: $merged) {
                Text("PDF 하나로 병합").tag(true)
                Text("파트별 PDF 폴더").tag(false)
            }.pickerStyle(.segmented)
            Text("목차 순서로 저장하며, 각 파트의 퀴즈 정답은 문제 뒤 별도 페이지에 담습니다.")
                .font(.callout).foregroundStyle(.secondary)
            if store.missingLessonCount > 0 {
                Text("미생성 파트는 제외됩니다. 모두 포함하려면 먼저 ‘전체 교재 준비’를 실행하세요.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            HStack {
                Button("취소") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("\(selection.count)개 파트 내보내기…") {
                    store.exportParts(selection, merged: merged)
                }.keyboardShortcut(.defaultAction).disabled(selection.isEmpty || store.busy)
            }
        }.padding(24).frame(width: 540)
            .onAppear { selection = Set(store.exportableParts.map(\.ordinal)) }
    }
}

extension StudyStore {
    func exportParts(_ selection: Set<Int>, merged: Bool) {
        guard !busy, let course = selected else { return }
        let parts = exportableParts.filter { selection.contains($0.ordinal) }
        let records = parts.compactMap { course.lessons[String($0.ordinal)] }
        guard !records.isEmpty else { return }
        let output: URL
        if merged {
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.pdf]
            let filename = course.plan.title.replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
            panel.nameFieldStringValue = "\(filename).pdf"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            output = url
        } else {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false; panel.canChooseDirectories = true
            panel.canCreateDirectories = true; panel.allowsMultipleSelection = false
            panel.prompt = "여기에 저장"
            panel.message = "선택한 폴더 안에 새 폴더를 만들고 파트별 PDF를 저장합니다."
            guard panel.runModal() == .OK, let url = panel.url else { return }
            output = url.appendingPathComponent(
                "학습자료-\(UUID().uuidString.prefix(8))", isDirectory: true)
        }
        do {
            if merged {
                try PDFCollectionExporter.merge(
                    records: records, repository: repository, to: output)
            } else {
                try PDFCollectionExporter.separate(
                    records: records, ordinals: parts.map(\.ordinal), repository: repository,
                    to: output)
            }
            showingPDFExport = false
            NSWorkspace.shared.activateFileViewerSelecting([output])
        } catch { self.error = error.localizedDescription }
    }
}
