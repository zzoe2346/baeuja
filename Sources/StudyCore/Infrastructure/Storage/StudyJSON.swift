import Foundation

public enum StudyJSON {
    public static func decoder() -> JSONDecoder {
        let value = JSONDecoder(); value.keyDecodingStrategy = .convertFromSnakeCase; return value
    }
    public static func encoder() -> JSONEncoder {
        let value = JSONEncoder(); value.keyEncodingStrategy = .convertToSnakeCase
        value.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes];
        return value
    }
    public static func read<T: Decodable>(_ type: T.Type, from url: URL, limit: Int = 8_388_608)
        throws -> T
    {
        let size = try url.resourceValues(forKeys: [.fileSizeKey, .isSymbolicLinkKey])
        guard size.isSymbolicLink != true, let count = size.fileSize, count <= limit else {
            throw StudyError.invalid("파일 크기나 파일 형식이 허용 범위를 벗어났습니다.")
        }
        return try decoder().decode(type, from: Data(contentsOf: url))
    }
}
