import Foundation

public final class LibraryRepository: @unchecked Sendable {
    public let root: URL
    private let file: URL
    public init(root: URL) throws {
        self.root = root; file = root.appendingPathComponent("library.json")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    private init(unavailableRoot: URL) {
        root = unavailableRoot; file = unavailableRoot.appendingPathComponent("library.json")
    }
    public static func unavailable(root: URL) -> LibraryRepository {
        LibraryRepository(unavailableRoot: root)
    }
    public func load() throws -> LibraryState {
        guard FileManager.default.fileExists(atPath: file.path) else { return LibraryState() }
        let value = try StudyJSON.read(LibraryState.self, from: file, limit: 64 * 1024 * 1024)
        guard value.schemaVersion == 1, Set(value.courses.map(\.id)).count == value.courses.count
        else {
            throw StudyError.storage("저장 형식을 읽을 수 없습니다. 원본 파일을 보존했습니다.")
        }
        for course in value.courses {
            try course.plan.validate()
            guard course.plan.parts.contains(where: { $0.ordinal == course.currentPart }) else {
                throw StudyError.storage("저장된 파트 위치가 올바르지 않습니다.")
            }
            for record in course.lessons.values { try record.lesson.validate() }
        }
        return value
    }
    public func save(_ state: LibraryState) throws {
        let encoded = try StudyJSON.encoder().encode(state)
        guard encoded.count <= 64 * 1024 * 1024 else {
            throw StudyError.storage("보관함 저장 크기를 초과했습니다.")
        }
        try encoded.write(to: file, options: .atomic)
    }
    public func assetURL(directory: String, name: String) throws -> URL {
        let base = root.resolvingSymlinksInPath()
        let parent = root.appendingPathComponent(directory).resolvingSymlinksInPath()
        guard (parent.path == base.path || parent.path.hasPrefix(base.path + "/")),
            !name.contains("/"), name != ".."
        else {
            throw StudyError.storage("자료 경로가 보관함 밖을 가리킵니다.")
        }
        let url = parent.appendingPathComponent(name).resolvingSymlinksInPath()
        guard url.path.hasPrefix(base.path + "/") else {
            throw StudyError.storage("자료 경로가 보관함 밖을 가리킵니다.")
        }
        return url
    }
    public func materialDirectory() throws -> (String, URL) {
        let name = "materials/" + UUID().uuidString
        let url = root.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return (name, url)
    }
}
