import Foundation

enum GeneratedLesson {
    static func decode(_ data: Data) throws -> Lesson {
        var lesson = try StudyJSON.decoder().decode(Lesson.self, from: data)
        let visualIDs = Set(lesson.visuals.map(\.id))
        let sourceIDs = Set(lesson.sources.map(\.id))
        // Repair casing only when the referenced definition actually exists.
        // Unknown references, duplicate definitions and missing references still fail validation.
        for index in lesson.sections.indices {
            lesson.sections[index].visualIds = lesson.sections[index].visualIds.map {
                visualIDs.contains($0.lowercased()) ? $0.lowercased() : $0
            }
            lesson.sections[index].sourceIds = lesson.sections[index].sourceIds.map {
                sourceIDs.contains($0.lowercased()) ? $0.lowercased() : $0
            }
        }
        try lesson.validate()
        return lesson
    }
}
