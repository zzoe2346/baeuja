import Testing
import AppKit
import PDFKit
@testable import StudyCore

@Suite(.serialized) final class RenderingTests {
    @Test func testSVGRejectsExecutableAndExternalContent() {
        for content in [
            "<script>alert(1)</script>", "<foreignObject/>", "<text onclick='x'>A</text>",
            "<use href='https://example.com/a.svg'/>",
            "<style>@import 'https://example.com/a';</style>",
        ] {
            expectThrows(
                try VisualSafety.svg("<svg xmlns='http://www.w3.org/2000/svg'>\(content)</svg>"))
        }
        expectThrows(
            try VisualSafety.svg(
                "<!DOCTYPE svg [<!ENTITY x SYSTEM 'file:///etc/passwd'>]><svg>&x;</svg>"))
        expectNoThrow(
            try VisualSafety.svg(
                "<svg xmlns='http://www.w3.org/2000/svg'><rect width='10' height='10'/><text>A</text></svg>"
            ))
        expectNoThrow(
            try VisualSafety.svg(
                "<svg xmlns='http://www.w3.org/2000/svg'><defs><marker id='arrow'/></defs><path d='M0 0L1 1' style='marker-end:url(#arrow)'/></svg>"
            ))
        expectThrows(
            try VisualSafety.svg(
                "<svg xmlns='http://www.w3.org/2000/svg'><style><![CDATA[rect{fill:url(https://example.com/x)}]]></style></svg>"
            ))
    }
    @Test func testSVGAllowsLocalSequenceSymbolsButRejectsUnsafeContents() {
        let prefix = "<svg xmlns='http://www.w3.org/2000/svg'><defs><symbol id='actor'>"
        let suffix = "</symbol></defs><use href='#actor'/></svg>"
        expectNoThrow(
            try VisualSafety.svg(prefix + "<path d='M0 0L1 1'/><text>Actor</text>" + suffix))
        expectThrows(try VisualSafety.svg(prefix + "<script>alert(1)</script>" + suffix))
        expectThrows(
            try VisualSafety.svg(prefix + "<use href='https://example.com/actor.svg'/>" + suffix))
        expectThrows(try VisualSafety.svg(prefix + "<path onclick='alert(1)'/>" + suffix))
    }
    @Test @MainActor func testStoredASCIIFallbackDoesNotCallAI() async throws {
        var lesson = DemoContent.lesson(); lesson.visuals[0].kind = "image_prompt"
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true);
        defer { try? FileManager.default.removeItem(at: directory) }
        let result = try await VisualRenderer().render(lesson, directory: directory)
        expectEqual(result[0].kind, "ascii"); expectNotNil(result[0].fallbackReason)
    }
    @Test @MainActor func testAllCandidatesFailWithoutPartialReady() async {
        var lesson = DemoContent.lesson(); lesson.visuals[0].kind = "image_prompt";
        lesson.visuals[0].fallbacks = [VisualCandidate(kind: "ascii", source: "bad\t")]
        do {
            _ = try await VisualRenderer().render(
                lesson, directory: FileManager.default.temporaryDirectory);
            fail()
        } catch {}
    }
    @Test @MainActor func testPDFContainsKoreanAndSeparatesAnswers() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let repository = try LibraryRepository(root: root);
        defer { try? FileManager.default.removeItem(at: root) }
        let output = root.appendingPathComponent("part.pdf"),
            record = DemoContent.course().lessons["1"]!
        var withTable = record
        withTable.lesson.sections[0].bodyMarkdown +=
            "\n\n본문에서도 정답과 해설이라는 말을 사용할 수 있습니다.\n\n| 이름 | 용도 |\n|---|---|\n| 인덱스 | 빠른 탐색 |"
        try PDFExporter.export(record: withTable, repository: repository, to: output)
        let document = try requireValue(PDFDocument(url: output));
        expectAtLeast(document.pageCount, 3)
        let strings = (0..<document.pageCount).map { document.page(at: $0)?.string ?? "" }
        expectTrue(strings.joined().contains("책의 목차"));
        expectTrue(strings.joined().contains("SELECT"))
        func heading(_ value: String, in text: String) -> Bool {
            text.components(separatedBy: .newlines).contains { $0.trimmed == value }
        }
        let questions = try requireValue(strings.firstIndex(where: { heading("이해도 확인", in: $0) }))
        let answers = try requireValue(strings.firstIndex(where: { heading("정답과 해설", in: $0) }))
        expectTrue(strings.joined().contains("빠른 탐색"))
        expectGreater(answers, questions);
        expectFalse(strings[questions].contains("항상 유리하지는 않습니다."))
    }
    @Test @MainActor func testPDFFailurePreservesExistingOutput() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
            repository = try LibraryRepository(root: root)
        defer { try? FileManager.default.removeItem(at: root) }
        let output = root.appendingPathComponent("part.pdf"), bytes = Data("previous".utf8);
        try bytes.write(to: output)
        var record = DemoContent.course().lessons["1"]!; record.visuals = []
        expectThrows(try PDFExporter.export(record: record, repository: repository, to: output));
        expectEqual(try Data(contentsOf: output), bytes)
    }
}
