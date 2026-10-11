import Foundation

/// Runs one part at a time. Each successful part is adopted before the next starts.
@MainActor public enum LessonBatch {
    public static func generate(
        course: Course,
        progress: (Int, Int, PlanPart) -> Void,
        prepare: (PlanPart) async throws -> Void
    ) async throws {
        let parts = course.plan.parts.sorted { $0.ordinal < $1.ordinal }
            .filter { course.lessons[String($0.ordinal)] == nil }
        for (index, part) in parts.enumerated() {
            try Task.checkCancellation()
            progress(index + 1, parts.count, part)
            try await prepare(part)
            try Task.checkCancellation()
        }
    }
}
