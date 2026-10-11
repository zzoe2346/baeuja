import Foundation
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
}
