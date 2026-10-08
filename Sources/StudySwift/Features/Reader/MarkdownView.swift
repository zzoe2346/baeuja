import SwiftUI
import StudyCore

struct MarkdownView: View {
    let text: String
    let fontSize: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(LessonMarkdown.blocks(text).enumerated()), id: \.offset) { _, block in
                switch block.kind {
                case .code(let language):
                    VStack(alignment: .leading, spacing: 10) {
                        if !language.isEmpty {
                            Text(language.uppercased()).font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16).padding(.top, 16)
                        }
                        MonospacedBlock(
                            text: block.text, fontSize: max(13, fontSize - 3), padding: 16)
                    }.background(
                        Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))
                case .heading(let level):
                    Text(LessonMarkdown.inline(block.text)).font(
                        .system(size: fontSize + Double(max(0, 5 - level)), weight: .semibold))
                case .bullet:
                    HStack(alignment: .top, spacing: 12) {
                        Text("•").foregroundStyle(Color.accentColor);
                        Text(LessonMarkdown.inline(block.text)).frame(
                            maxWidth: .infinity, alignment: .leading)
                    }.font(.system(size: fontSize)).lineSpacing(7)
                case .numbered(let number):
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(number).").foregroundStyle(Color.accentColor);
                        Text(LessonMarkdown.inline(block.text)).frame(
                            maxWidth: .infinity, alignment: .leading)
                    }.font(.system(size: fontSize)).lineSpacing(7)
                case .table(let rows):
                    Grid(alignment: .topLeading, horizontalSpacing: 1, verticalSpacing: 1) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                            GridRow {
                                ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                                    Text(LessonMarkdown.inline(cell)).font(
                                        .system(
                                            size: max(14, fontSize - 2),
                                            weight: rowIndex == 0 ? .semibold : .regular)
                                    ).lineSpacing(5).frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(12).background(
                                            rowIndex == 0
                                                ? Color.accentColor.opacity(0.09)
                                                : Color.primary.opacity(0.025))
                                }
                            }
                        }
                    }.background(Color.primary.opacity(0.1)).clipShape(
                        RoundedRectangle(cornerRadius: 8))
                case .quote:
                    Text(LessonMarkdown.inline(block.text)).font(.system(size: fontSize))
                        .foregroundStyle(.secondary).padding(.leading, 16).overlay(
                            alignment: .leading
                        ) { Rectangle().fill(Color.accentColor.opacity(0.4)).frame(width: 3) }
                case .rule: Divider()
                case .paragraph:
                    Text(LessonMarkdown.inline(block.text)).font(.system(size: fontSize))
                        .lineSpacing(8).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).fixedSize(
            horizontal: false, vertical: true)
    }
}

struct MonospacedBlock: View {
    let text: String
    let fontSize: Double
    let padding: CGFloat

    var body: some View {
        ScrollView(.horizontal) {
            Text(text).font(.system(size: fontSize, design: .monospaced))
                .fixedSize(horizontal: true, vertical: true)
                .padding(padding)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .help("폭이 부족하면 가로로 스크롤해 전체 도식과 코드를 볼 수 있습니다.")
    }
}
