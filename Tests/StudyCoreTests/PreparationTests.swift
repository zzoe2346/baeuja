import Foundation
import Testing
@testable import StudyCore

@Suite @MainActor struct PreparationTests {
    private func repository() throws -> LibraryRepository {
        try LibraryRepository(
            root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    }
    private func directories(_ repository: LibraryRepository) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: repository.root.appendingPathComponent("materials"), includingPropertiesForKeys: nil
        )
    }
    private func rendered(_ lesson: Lesson) -> [RenderedVisual] {
        lesson.visuals.map { RenderedVisual(id: $0.id, kind: "ascii", content: "local fallback") }
    }
    @Test func successfulAdoptionPersistsBeforeKeepingMaterial() async throws {
        let repository = try repository()
        defer { try? FileManager.default.removeItem(at: repository.root) }
        let preparer = LessonPreparation(repository: repository) { lesson, _, image in
            expectNil(image)
            return rendered(lesson)
        }
        let result = try await preparer.prepare(DemoContent.lesson()) { record in
            let directory = repository.root.appendingPathComponent(record.materialDirectory)
            expectEqual(
                try StudyJSON.read(
                    Lesson.self, from: directory.appendingPathComponent("lesson.json")),
                record.lesson)
            var state = LibraryState(), course = DemoContent.course()
            course.lessons["1"] = record
            state.courses = [course]; state.selectedCourseId = course.id
            try repository.save(state)
            return true
        }
        let record = try requireValue(result)
        expectEqual(try repository.load().courses[0].lessons["1"]?.revision, record.revision)
        expectEqual(try directories(repository).count, 1)
    }
    @Test func renderingFailurePreservesLibraryAndRemovesPartialFiles() async throws {
        let repository = try repository()
        defer { try? FileManager.default.removeItem(at: repository.root) }
        var initial = LibraryState(); initial.courses = [DemoContent.course()]
        try repository.save(initial)
        let bytes = try Data(contentsOf: repository.root.appendingPathComponent("library.json"))
        let preparer = LessonPreparation(repository: repository) { _, directory, _ in
            try Data("partial".utf8).write(to: directory.appendingPathComponent("partial.png"))
            throw StudyError.invalid("rendering failed")
        }
        do {
            _ = try await preparer.prepare(DemoContent.lesson()) { _ in
                fail("채택하면 안 됩니다"); return true
            }; fail()
        } catch { expectEqual(error as? StudyError, .invalid("rendering failed")) }
        expectTrue(try directories(repository).isEmpty)
        expectEqual(
            try Data(contentsOf: repository.root.appendingPathComponent("library.json")), bytes)
    }
    @Test func rejectedAdoptionRemovesPreparedMaterial() async throws {
        let repository = try repository()
        defer { try? FileManager.default.removeItem(at: repository.root) }
        let preparer = LessonPreparation(repository: repository) { lesson, _, _ in rendered(lesson)
        }
        let result = try await preparer.prepare(DemoContent.lesson()) { _ in false }
        expectNil(result)
        expectTrue(try directories(repository).isEmpty)
    }
    @Test func throwingAdopterRemovesPreparedMaterial() async throws {
        let repository = try repository()
        defer { try? FileManager.default.removeItem(at: repository.root) }
        let preparer = LessonPreparation(repository: repository) { lesson, _, _ in rendered(lesson)
        }
        do {
            _ = try await preparer.prepare(DemoContent.lesson()) { _ in
                throw StudyError.invalid("save failed")
            }; fail()
        } catch { expectEqual(error as? StudyError, .invalid("save failed")) }
        expectTrue(try directories(repository).isEmpty)
    }
    @Test func cancellationAfterRenderingNeverAdoptsMaterial() async throws {
        let repository = try repository()
        defer { try? FileManager.default.removeItem(at: repository.root) }
        let preparer = LessonPreparation(repository: repository) { lesson, _, _ in
            withUnsafeCurrentTask { $0?.cancel() }
            return rendered(lesson)
        }
        let job = Task { @MainActor in
            try await preparer.prepare(DemoContent.lesson()) { _ in
                fail("취소된 결과를 채택하면 안 됩니다"); return true
            }
        }
        do { _ = try await job.value; fail() } catch { expectTrue(error is CancellationError) }
        expectTrue(try directories(repository).isEmpty)
    }
}
