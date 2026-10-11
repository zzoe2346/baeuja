import Foundation
import PDFKit
import Testing
@testable import StudyCore

@Suite @MainActor struct BatchTests {
    @Test func failedBatchResumesOnlyMissingPartsAndPreservesProgress() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let repository = try LibraryRepository(root: root)
        defer { try? FileManager.default.removeItem(at: root) }
        var course = DemoContent.course()
        course.lessons = [:]
        var state = LibraryState(); state.courses = [course]; state.selectedCourseId = course.id
        try repository.save(state)
        let originalProgress = course.progress
        var calls: [Int] = []
        do {
            try await LessonBatch.generate(course: course, progress: { _, _, _ in }) { part in
                calls.append(part.ordinal)
                if calls.count == 2 { throw StudyError.invalid("fixture failure") }
                course.lessons[String(part.ordinal)] = DemoContent.course().lessons["1"]
                state.courses = [course]; try repository.save(state)
            }
            fail()
        } catch { expectEqual(error as? StudyError, .invalid("fixture failure")) }
        expectEqual(calls, [1, 2])
        course = try repository.load().courses[0]
        calls = []
        try await LessonBatch.generate(
            course: course,
            progress: { index, count, _ in
                expectTrue(index <= count)
            }
        ) { part in calls.append(part.ordinal) }
        expectEqual(calls, course.plan.parts.map(\.ordinal).filter { $0 != 1 })
        expectEqual(course.progress, originalProgress)
    }

    @Test func cancellationStopsBeforeStartingNextPart() async throws {
        var course = DemoContent.course(); course.lessons = [:]
        var calls: [Int] = []
        let job = Task { @MainActor in
            try await LessonBatch.generate(course: course, progress: { _, _, _ in }) { part in
                calls.append(part.ordinal)
                withUnsafeCurrentTask { $0?.cancel() }
            }
        }
        do { try await job.value; fail() } catch { expectTrue(error is CancellationError) }
        expectEqual(calls, [1])
    }

    @Test func mergedPDFPreservesOrderPageCountAndAnswerBoundaries() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let repository = try LibraryRepository(root: root)
        defer { try? FileManager.default.removeItem(at: root) }
        var first = DemoContent.course().lessons["1"]!
        first.lesson.title = "첫 번째 선택 파트"
        var second = first; second.lesson.title = "두 번째 선택 파트"
        let records = [first, second]
        let folder = root.appendingPathComponent("parts")
        try PDFCollectionExporter.separate(
            records: records, ordinals: [1, 3], repository: repository, to: folder)
        let documents = try [1, 3].map { ordinal in
            try requireValue(
                PDFDocument(
                    url: folder.appendingPathComponent(String(format: "파트-%02d.pdf", ordinal))))
        }
        let output = root.appendingPathComponent("merged.pdf")
        try PDFCollectionExporter.merge(records: records, repository: repository, to: output)
        let merged = try requireValue(PDFDocument(url: output))
        expectEqual(merged.pageCount, documents.reduce(0) { $0 + $1.pageCount })
        expectEqual(merged.outlineRoot?.numberOfChildren, 2)
        let destination = try requireValue(merged.outlineRoot?.child(at: 0)?.destination)
        expectEqual(destination.point.y, merged.page(at: 0)?.bounds(for: .mediaBox).maxY)
        var offset = 0
        for (index, document) in documents.enumerated() {
            expectTrue(
                merged.page(at: offset)?.string?.contains(records[index].lesson.title) == true)
            for page in 0..<document.pageCount {
                expectEqual(merged.page(at: offset + page)?.string, document.page(at: page)?.string)
            }
            let texts = (0..<document.pageCount).map { document.page(at: $0)?.string ?? "" }
            let question = try requireValue(texts.firstIndex { $0.contains("이해도 확인") })
            let answer = try requireValue(texts.firstIndex { $0.contains("정답과 해설") })
            expectGreater(answer, question)
            offset += document.pageCount
        }
    }

    @Test func collectionFailureKeepsExistingOutputAndPublishesNoPartialFolder() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let repository = try LibraryRepository(root: root)
        defer { try? FileManager.default.removeItem(at: root) }
        let good = DemoContent.course().lessons["1"]!
        var bad = good; bad.visuals = []
        let output = root.appendingPathComponent("existing.pdf")
        let original = Data("original".utf8); try original.write(to: output)
        expectThrows(
            try PDFCollectionExporter.merge(
                records: [good, bad], repository: repository, to: output))
        expectEqual(try Data(contentsOf: output), original)
        let folder = root.appendingPathComponent("parts")
        expectThrows(
            try PDFCollectionExporter.separate(
                records: [good, bad], ordinals: [1, 2], repository: repository, to: folder))
        expectFalse(FileManager.default.fileExists(atPath: folder.path))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try original.write(to: folder.appendingPathComponent("keep.txt"))
        expectThrows(
            try PDFCollectionExporter.separate(
                records: [good], ordinals: [1], repository: repository, to: folder))
        expectEqual(try Data(contentsOf: folder.appendingPathComponent("keep.txt")), original)
    }
}
