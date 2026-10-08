import Foundation

public typealias LessonImageProvider = (String, URL) async throws -> Void

/// Prepares a new revision without replacing the currently adopted material.
@MainActor public final class LessonPreparation {
    public typealias Render =
        @MainActor (Lesson, URL, LessonImageProvider?) async throws -> [RenderedVisual]
    private let repository: LibraryRepository
    private let render: Render

    public init(
        repository: LibraryRepository,
        render: @escaping Render = { lesson, directory, image in
            try await VisualRenderer().render(lesson, directory: directory, image: image)
        }
    ) {
        self.repository = repository
        self.render = render
    }

    /// The adopter returns true only after its atomic library write succeeds.
    /// A failure, cancellation or rejected adoption removes the new directory.
    @discardableResult public func prepare(
        _ lesson: Lesson,
        image: LessonImageProvider? = nil,
        adopt: (LessonRecord) throws -> Bool
    ) async throws -> LessonRecord? {
        try lesson.validate()
        try Task.checkCancellation()
        let (relative, directory) = try repository.materialDirectory()
        var adopted = false
        defer { if !adopted { try? FileManager.default.removeItem(at: directory) } }
        let visuals = try await render(lesson, directory, image)
        try Task.checkCancellation()
        try StudyJSON.encoder().encode(lesson).write(
            to: directory.appendingPathComponent("lesson.json"), options: .atomic)
        let record = LessonRecord(lesson: lesson, visuals: visuals, materialDirectory: relative)
        try Task.checkCancellation()
        adopted = try adopt(record)
        return adopted ? record : nil
    }
}
