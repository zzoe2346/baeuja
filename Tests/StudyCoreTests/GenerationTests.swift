import Foundation
import Testing
@testable import StudyCore

@Suite struct GenerationTests {
    @Test func generatedReferenceCasingMatchesExistingDefinitions() throws {
        let original = DemoContent.lesson(ordinal: 1)
        var generated = original
        for index in generated.sections.indices {
            generated.sections[index].visualIds = generated.sections[index].visualIds.map {
                $0.uppercased()
            }
            generated.sections[index].sourceIds = generated.sections[index].sourceIds.map {
                $0.uppercased()
            }
        }
        expectThrows(try generated.validate())
        let decoded = try GeneratedLesson.decode(StudyJSON.encoder().encode(generated))
        expectEqual(decoded, original)
    }

    @Test func invalidReferencesAndDuplicateDefinitionsAreNotRepaired() throws {
        let original = DemoContent.lesson(ordinal: 1)
        var unknownVisual = original
        unknownVisual.sections[0].visualIds.append("V999")
        var unknownSource = original
        unknownSource.sections[0].sourceIds.append("S999")
        var missingReference = original
        for index in missingReference.sections.indices {
            missingReference.sections[index].visualIds = []
        }
        var duplicate = original
        duplicate.visuals.append(original.visuals[0])
        for lesson in [unknownVisual, unknownSource, missingReference, duplicate] {
            expectThrows(try GeneratedLesson.decode(StudyJSON.encoder().encode(lesson)))
        }
    }
}
