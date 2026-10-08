import Testing
import Foundation
@testable import StudyCore

@Suite(.serialized) final class RepositoryTests {
    var root: URL!
    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "study-swift-test-" + UUID().uuidString);
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    deinit { try? FileManager.default.removeItem(at: root) }
    @Test func testRoundTripProgressNotesAndReveal() throws {
        let repository = try LibraryRepository(root: root); var state = LibraryState();
        var course = DemoContent.course()
        var progress = PartProgress(); progress.section = 2; progress.scrollOffset = 134.5;
        progress.notes["q1"] = "복습 메모"; progress.revealed.insert("q1");
        course.progress["1"] = progress
        state.courses = [course]; state.selectedCourseId = course.id; try repository.save(state)
        expectEqual(try repository.load(), state)
    }
    @Test func testCorruptionIsNotOverwrittenByLoad() throws {
        let repository = try LibraryRepository(root: root),
            file = root.appendingPathComponent("library.json")
        let bytes = Data("broken".utf8); try bytes.write(to: file)
        expectThrows(try repository.load()); expectEqual(try Data(contentsOf: file), bytes)
    }
    @Test func testRejectsFutureVersion() throws {
        let repository = try LibraryRepository(root: root); var state = LibraryState();
        state.schemaVersion = 99; try repository.save(state); expectThrows(try repository.load())
    }
    @Test func testAssetPathRejectsTraversalAndSymlink() throws {
        let repository = try LibraryRepository(root: root)
        expectThrows(try repository.assetURL(directory: "../", name: "secret"))
        expectThrows(try repository.assetURL(directory: "materials", name: "../secret"))
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("outside"),
            withDestinationURL: root.deletingLastPathComponent())
        expectThrows(try repository.assetURL(directory: "outside", name: "secret"))
    }
    @Test func testReadRejectsOversizedFileAndSymlink() throws {
        let file = root.appendingPathComponent("oversize.json");
        try Data(repeating: 65, count: 100).write(to: file)
        expectThrows(try StudyJSON.read(Lesson.self, from: file, limit: 99))
        let link = root.appendingPathComponent("link.json");
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        expectThrows(try StudyJSON.read(Lesson.self, from: link))
    }
}
