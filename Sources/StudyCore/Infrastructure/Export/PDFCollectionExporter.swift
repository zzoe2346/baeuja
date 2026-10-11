import Foundation
import PDFKit

@MainActor public enum PDFCollectionExporter {
    public static func merge(
        records: [LessonRecord], repository: LibraryRepository, to output: URL
    ) throws {
        guard !records.isEmpty else { throw StudyError.invalid("내보낼 파트를 선택하세요.") }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let merged = PDFDocument()
        let outline = PDFOutline()
        for (index, record) in records.enumerated() {
            let url = directory.appendingPathComponent("\(index).pdf")
            try PDFExporter.export(record: record, repository: repository, to: url)
            guard let document = PDFDocument(url: url) else {
                throw StudyError.storage("파트 PDF를 읽지 못했습니다.")
            }
            let start = merged.pageCount
            for pageIndex in 0..<document.pageCount {
                guard let page = document.page(at: pageIndex) else {
                    throw StudyError.storage("PDF 페이지를 읽지 못했습니다.")
                }
                merged.insert(page, at: merged.pageCount)
            }
            if let page = merged.page(at: start) {
                let item = PDFOutline()
                item.label = record.lesson.title
                item.destination = PDFDestination(
                    page: page, at: CGPoint(x: 0, y: page.bounds(for: .mediaBox).maxY))
                outline.insertChild(item, at: outline.numberOfChildren)
            }
        }
        merged.outlineRoot = outline
        guard let data = merged.dataRepresentation(),
            let verified = PDFDocument(data: data), verified.pageCount == merged.pageCount
        else { throw StudyError.storage("병합 PDF를 검증하지 못했습니다.") }
        try data.write(to: output, options: .atomic)
    }

    /// Publish a new folder only after every PDF succeeds; never overwrite existing files.
    public static func separate(
        records: [LessonRecord], ordinals: [Int], repository: LibraryRepository, to folder: URL
    ) throws {
        guard !records.isEmpty, records.count == ordinals.count else {
            throw StudyError.invalid("내보낼 파트를 선택하세요.")
        }
        let temporary = folder.deletingLastPathComponent().appendingPathComponent(
            ".\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        for (ordinal, record) in zip(ordinals, records) {
            try PDFExporter.export(
                record: record, repository: repository,
                to: temporary.appendingPathComponent(String(format: "파트-%02d.pdf", ordinal)))
        }
        try FileManager.default.moveItem(at: temporary, to: folder)
    }
}
