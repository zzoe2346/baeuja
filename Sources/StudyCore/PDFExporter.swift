import AppKit
import CoreText
import PDFKit

@MainActor public enum PDFExporter {
    public static func export(record: LessonRecord, repository: LibraryRepository, to output: URL) throws {
        try record.lesson.validate()
        guard Set(record.visuals.map(\.id)) == Set(record.lesson.visuals.map(\.id)) else { throw StudyError.invalid("PDF에 필요한 그림이 완성되지 않았습니다.") }
        let temporary = output.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: temporary) }
        guard let consumer = CGDataConsumer(url: temporary as CFURL) else { throw StudyError.storage("PDF 파일을 만들 수 없습니다.") }
        var bounds = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
        guard let context = CGContext(consumer: consumer, mediaBox: &bounds, nil) else { throw StudyError.storage("PDF 문서를 만들 수 없습니다.") }
        let writer = PDFWriter(context: context, title: record.lesson.title)
        writer.newPage()
        writer.text(record.lesson.title, size: 24, bold: true)
        writer.text("\(record.lesson.minutes)분 학습 · 개념 / 원리 / 예제 / 퀴즈", size: 10)
        for section in record.lesson.sections {
            writer.keepSectionStart()
            writer.heading(section.title)
            for block in LessonMarkdown.blocks(section.bodyMarkdown) {
                switch block.kind {
                case .code: writer.text(block.text, size: 9, mono: true)
                case .heading(let level): writer.text(block.text, size: max(12, 18 - CGFloat(level)), bold: true)
                case .bullet: writer.markdown("• " + block.text)
                case .numbered(let number): writer.markdown("\(number). " + block.text)
                case .table(let rows): writer.table(rows)
                case .quote: writer.text(block.text, size: 11)
                case .rule: writer.space(12)
                case .paragraph: writer.markdown(block.text)
                }
            }
            for id in section.visualIds {
                guard let visual = record.visuals.first(where: { $0.id == id }), let definition = record.lesson.visuals.first(where: { $0.id == id }) else { throw StudyError.invalid("그림 참조가 올바르지 않습니다.") }
                if visual.kind == "ascii" { try validateASCII(visual.content); writer.text(visual.content, size: 8, mono: true) }
                else if visual.kind == "image", let file = visual.file {
                    let data = try VisualSafety.png(repository.assetURL(directory: record.materialDirectory, name: file))
                    guard let image = NSImage(data: data), let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { throw StudyError.invalid("PDF 그림을 읽을 수 없습니다.") }
                    writer.image(cg, caption: definition.caption)
                } else { throw StudyError.invalid("PDF 그림 종류가 올바르지 않습니다.") }
                writer.text(definition.caption, size: 10)
                if let reason = visual.fallbackReason { writer.text(reason, size: 9) }
            }
        }
        writer.heading("출처")
        for source in record.lesson.sources { writer.text("\(source.title)\n\(source.url)", size: 9) }
        writer.newPage()
        writer.heading("이해도 확인")
        writer.text("종이나 메모에 자유롭게 풀어보세요. 풀이 내용은 별도의 다음 페이지부터 시작합니다.")
        for (index, quiz) in record.lesson.quizzes.enumerated() {
            writer.heading("\(index + 1). \(quiz.question)")
            writer.space(75)
        }
        writer.newPage()
        writer.heading("정답과 해설")
        for (index, quiz) in record.lesson.quizzes.enumerated() {
            writer.heading("\(index + 1). \(quiz.question)")
            writer.markdown(quiz.answer); writer.markdown(quiz.explanation)
        }
        writer.heading("다음에 공부할 수 있는 주제")
        for follow in record.lesson.followUps { writer.text("\(follow.topic)\n\(follow.reason)") }
        writer.close()
        guard let document = PDFDocument(url: temporary), document.pageCount >= 3,
              (0..<document.pageCount).allSatisfy({ document.page(at: $0) != nil }) else { throw StudyError.storage("PDF 결과를 검증하지 못했습니다.") }
        let data = try Data(contentsOf: temporary); try data.write(to: output, options: .atomic)
    }
}

@MainActor private final class PDFWriter {
    let context: CGContext
    let title: String
    var cursor: CGFloat = 786
    var page = 0
    let width: CGFloat = 499.28
    init(context: CGContext, title: String) { self.context = context; self.title = title }
    func newPage() {
        if page > 0 { footer(); context.endPDFPage() }
        context.beginPDFPage(nil); page += 1; cursor = 786
        context.setFillColor(NSColor.white.cgColor); context.fill(CGRect(x: 0, y: 0, width: 595.28, height: 841.89))
    }
    func close() { footer(); context.endPDFPage(); context.closePDF() }
    func footer() {
        let value = NSAttributedString(string: "STUDY SWIFT   ·   \(page)", attributes: [.font: NSFont.systemFont(ofSize: 8), .foregroundColor: NSColor.darkGray])
        draw(value, in: CGRect(x: 48, y: 25, width: width, height: 16))
    }
    func space(_ value: CGFloat) { if cursor - value < 55 { newPage() } else { cursor -= value } }
    func heading(_ value: String) {
        if cursor < 155 { newPage() }; space(16); text(value, size: 16, bold: true)
    }
    func keepSectionStart() { if cursor < 230 { newPage() } }
    func markdown(_ value: String) {
        let attributed = NSMutableAttributedString(LessonMarkdown.inline(value))
        let style = NSMutableParagraphStyle(); style.lineSpacing = 5
        attributed.addAttributes([.font: NSFont.systemFont(ofSize: 11.5), .foregroundColor: NSColor.black, .paragraphStyle: style], range: NSRange(location: 0, length: attributed.length))
        flow(attributed)
    }
    func text(_ value: String, size: CGFloat = 11.5, bold: Bool = false, mono: Bool = false) {
        let font = mono ? NSFont.monospacedSystemFont(ofSize: size, weight: .regular) : NSFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular)
        let style = NSMutableParagraphStyle(); style.lineSpacing = mono ? 2 : 5
        let attributed = NSAttributedString(string: value, attributes: [.font: font, .foregroundColor: NSColor.black, .paragraphStyle: style])
        flow(attributed)
    }
    func flow(_ value: NSAttributedString) {
        guard value.length > 0 else { return }
        let setter = CTFramesetterCreateWithAttributedString(value)
        var offset = 0
        while offset < value.length {
            if cursor < 100 { newPage() }
            let available = cursor - 55
            var fitted = CFRange()
            let size = CTFramesetterSuggestFrameSizeWithConstraints(setter, CFRange(location: offset, length: 0), nil, CGSize(width: width, height: available), &fitted)
            guard fitted.length > 0 else { newPage(); continue }
            let height = min(available, ceil(size.height) + 4)
            let path = CGPath(rect: CGRect(x: 48, y: cursor - height, width: width, height: height), transform: nil)
            let frame = CTFramesetterCreateFrame(setter, CFRange(location: offset, length: fitted.length), path, nil)
            CTFrameDraw(frame, context); offset += fitted.length; cursor -= height + 12
            if offset < value.length { newPage() }
        }
    }
    func draw(_ value: NSAttributedString, in rect: CGRect) {
        let setter = CTFramesetterCreateWithAttributedString(value)
        CTFrameDraw(CTFramesetterCreateFrame(setter, CFRange(location: 0, length: 0), CGPath(rect: rect, transform: nil), nil), context)
    }
    func table(_ rows: [[String]]) {
        guard let header = rows.first, !header.isEmpty else { return }
        let cellWidth = width / CGFloat(header.count)
        func attributed(_ value: String, bold: Bool) -> NSAttributedString {
            let style = NSMutableParagraphStyle(); style.lineSpacing = 4
            return NSAttributedString(string: value, attributes: [.font: NSFont.systemFont(ofSize: 10.5, weight: bold ? .semibold : .regular), .foregroundColor: NSColor.black, .paragraphStyle: style])
        }
        func row(_ cells: [String], bold: Bool) {
            let strings = cells.map { attributed($0, bold: bold) }
            let height = max(32, strings.map { ceil(CTFramesetterSuggestFrameSizeWithConstraints(CTFramesetterCreateWithAttributedString($0), CFRange(location: 0, length: 0), nil, CGSize(width: cellWidth - 16, height: .greatestFiniteMagnitude), nil).height) + 16 }.max() ?? 32)
            if height > 650 { for (index, value) in cells.enumerated() { text("\(header[index]): \(value)") }; return }
            if cursor - height < 55 {
                newPage()
                let headerHeight = max(32, header.map { ceil(CTFramesetterSuggestFrameSizeWithConstraints(CTFramesetterCreateWithAttributedString(attributed($0, bold: true)), CFRange(location: 0, length: 0), nil, CGSize(width: cellWidth - 16, height: .greatestFiniteMagnitude), nil).height) + 16 }.max() ?? 32)
                if !bold && cursor - height - headerHeight >= 55 { row(header, bold: true) }
            }
            for (index, string) in strings.enumerated() {
                let rect = CGRect(x: 48 + CGFloat(index) * cellWidth, y: cursor - height, width: cellWidth, height: height)
                context.setFillColor((bold ? NSColor(calibratedRed: 0.92, green: 0.95, blue: 1, alpha: 1) : NSColor.white).cgColor); context.fill(rect)
                context.setStrokeColor(NSColor.lightGray.cgColor); context.setLineWidth(0.5); context.stroke(rect)
                draw(string, in: rect.insetBy(dx: 8, dy: 8))
            }
            cursor -= height
        }
        for (index, cells) in rows.enumerated() { row(cells, bold: index == 0) }
        cursor -= 16
    }
    func image(_ image: CGImage, caption: String) {
        let ratio = CGFloat(image.height) / CGFloat(image.width)
        let targetWidth = min(width, 300 / ratio), height = targetWidth * ratio
        let style = NSMutableParagraphStyle(); style.lineSpacing = 5
        let text = NSAttributedString(string: caption, attributes: [.font: NSFont.systemFont(ofSize: 10), .paragraphStyle: style])
        let captionHeight = CTFramesetterSuggestFrameSizeWithConstraints(CTFramesetterCreateWithAttributedString(text), CFRange(location: 0, length: 0), nil, CGSize(width: width, height: .greatestFiniteMagnitude), nil).height
        if cursor - height - min(150, captionHeight) - 32 < 55 { newPage() }
        context.draw(image, in: CGRect(x: 48 + (width - targetWidth) / 2, y: cursor - height, width: targetWidth, height: height))
        cursor -= height + 16
    }
}
