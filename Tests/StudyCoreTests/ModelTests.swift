import Testing
import Foundation
@testable import StudyCore

@Suite(.serialized) final class ModelTests {
    @Test func testDemoContractsAndJSONRoundTrip() throws {
        let course = DemoContent.course(); try course.plan.validate()
        for record in course.lessons.values {
            try record.lesson.validate()
            let data = try StudyJSON.encoder().encode(record.lesson)
            expectEqual(try StudyJSON.decoder().decode(Lesson.self, from: data), record.lesson)
            expectTrue(String(decoding: data, as: UTF8.self).contains("body_markdown"))
        }
    }
    @Test func testPlanRejectsInvalidDuration() { var plan = DemoContent.course().plan; plan.parts[0].minutes = 29; expectThrows(try plan.validate()) }
    @Test func testPlanRejectsGaps() { var plan = DemoContent.course().plan; plan.parts[1].ordinal = 3; expectThrows(try plan.validate()) }
    @Test func testPlanRejectsEmptyObjective() { var plan = DemoContent.course().plan; plan.objectives = [" "]; expectThrows(try plan.validate()) }
    @Test func testPlanRejectsUnknownVersion() { var plan = DemoContent.course().plan; plan.schemaVersion = 2; expectThrows(try plan.validate()) }
    @Test func testLessonRejectsMissingConcept() { var lesson = DemoContent.lesson(); lesson.sections[0].kind = "example"; expectThrows(try lesson.validate()) }
    @Test func testLessonRejectsDuplicateVisualIDs() { var lesson = DemoContent.lesson(); lesson.visuals.append(lesson.visuals[0]); expectThrows(try lesson.validate()) }
    @Test func testLessonRejectsUnknownReference() { var lesson = DemoContent.lesson(); lesson.sections[0].visualIds = ["v99"]; expectThrows(try lesson.validate()) }
    @Test func testLessonRejectsUnreferencedSource() { var lesson = DemoContent.lesson(); lesson.sections[0].sourceIds = []; expectThrows(try lesson.validate()) }
    @Test func testLessonRejectsRemoteFileSource() { var lesson = DemoContent.lesson(); lesson.sources[0].url = "file:///private/tmp/secret"; expectThrows(try lesson.validate()) }
    @Test func testLessonRequiresStoredFallback() { var lesson = DemoContent.lesson(); lesson.visuals[0].fallbacks = []; expectThrows(try lesson.validate()) }
    @Test func testLessonRejectsEmptyQuizAnswer() { var lesson = DemoContent.lesson(); lesson.quizzes[0].answer = ""; expectThrows(try lesson.validate()) }
    @Test func testLanguageLearningAllowsJapaneseExamples() throws { var lesson = DemoContent.lesson(); lesson.sections[0].bodyMarkdown = "일본어 인사: こんにちは。"; try lesson.validate() }
    @Test func testASCIIRejectsTabsUnicodeAndWideLines() {
        for value in ["a\tb", "한글", String(repeating: "a", count: 73), "a\rb"] { expectThrows(try validateASCII(value)) }
        expectNoThrow(try validateASCII("+---+\n| A |\n+---+"))
    }
    @Test func testJumpDoesNotCompleteEarlierParts() {
        var course = DemoContent.course(); course.currentPart = 2; course.completeCurrent()
        expectEqual(course.status, .active); expectEqual(course.currentPart, 1)
        expectEqual(course.completionCount, 1); expectNil(course.progress["1"])
        course.completeCurrent(); expectEqual(course.status, .complete); expectEqual(course.completionCount, 2)
        course.currentPart = 2; course.completeCurrent(); expectEqual(course.status, .complete)
    }
    @Test func testDraftCannotComplete() { var course = Course(plan: DemoContent.course().plan); course.completeCurrent(); expectEqual(course.status, .draft); expectEqual(course.completionCount, 0) }
    @Test func testMarkdownPreservesCodeWhitespace() {
        let blocks = LessonMarkdown.blocks("# 제목\n\n```sql\n  SELECT 1;\n\n```\n\n- 설명")
        expectEqual(blocks[1].kind, .code("sql")); expectEqual(blocks[1].text, "  SELECT 1;\n")
        expectEqual(blocks[2].kind, .bullet)
    }
    @Test func testMarkdownTableAndOrderedSteps() {
        let blocks = LessonMarkdown.blocks("| 종류 | 값 |\n|:---|---:|\n| 재료 | 물 \\| CO2 |\n\n1. 빛을 받는다\n2. 당을 만든다\n\nordinary | prose")
        expectEqual(blocks[0].kind, .table([["종류", "값"], ["재료", "물 | CO2"]]))
        expectEqual(blocks[1].kind, .numbered(1)); expectEqual(blocks[2].kind, .numbered(2)); expectEqual(blocks[3].kind, .paragraph)
    }
}
