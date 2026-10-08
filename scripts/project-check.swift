import CryptoKit
import Foundation

struct ScreenshotManifest: Decodable {
    struct Entry: Decodable {
        let file: String
        let sha256: String
        let origin: String
    }
    let captureDate: String
    let appVersion: String
    let sourceRevision: String
    let executableSHA256: String
    let runtimeOS: String
    let sdk: String
    let files: [Entry]
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let manager = FileManager.default
var failures: [String] = []
func check(_ condition: Bool, _ message: String) {
    if !condition { failures.append(message) }
}
let domain = root.appendingPathComponent("Sources/StudyCore/Domain")
check(manager.fileExists(atPath: domain.path), "Domain 폴더가 없습니다.")
if let files = manager.enumerator(at: domain, includingPropertiesForKeys: nil) {
    for case let file as URL in files where file.pathExtension == "swift" {
        let source = try String(contentsOf: file, encoding: .utf8)
        let imports = source.components(separatedBy: .newlines).filter {
            $0.trimmingCharacters(in: .whitespaces).hasPrefix("import ")
        }
        check(
            imports.allSatisfy { $0.trimmingCharacters(in: .whitespaces) == "import Foundation" },
            "Domain의 허용되지 않은 import: \(file.lastPathComponent)")
    }
}
var documents = [
    root.appendingPathComponent("README.md"), root.appendingPathComponent("AGENTS.md"),
]
if let files = manager.enumerator(
    at: root.appendingPathComponent("docs"), includingPropertiesForKeys: nil)
{
    for case let file as URL in files where file.pathExtension == "md" { documents.append(file) }
}
let links = try NSRegularExpression(pattern: #"\]\(([^\s)]+)(?:\s+\"[^\"]*\")?\)"#)
for file in documents {
    let source = try String(contentsOf: file, encoding: .utf8)
    let matches = links.matches(in: source, range: NSRange(source.startIndex..., in: source))
    for match in matches {
        guard let range = Range(match.range(at: 1), in: source) else { continue }
        let link = String(source[range])
        if link.hasPrefix("#") || URL(string: link)?.scheme != nil { continue }
        let path =
            String(link.split(separator: "#", maxSplits: 1)[0]).removingPercentEncoding ?? link
        check(
            manager.fileExists(
                atPath: file.deletingLastPathComponent().appendingPathComponent(path).path),
            "문서 링크 누락: \(file.lastPathComponent) → \(link)")
    }
}
let assets = root.appendingPathComponent("docs/assets")
let manifest = try JSONDecoder().decode(
    ScreenshotManifest.self,
    from: Data(contentsOf: assets.appendingPathComponent("screenshots.json")))
check(
    !manifest.captureDate.isEmpty && !manifest.appVersion.isEmpty && !manifest.runtimeOS.isEmpty
        && !manifest.sdk.isEmpty, "스크린샷 환경 기록이 비어 있습니다.")
check(
    manifest.sourceRevision.range(of: #"^[a-f0-9]{40}$"#, options: .regularExpression) != nil,
    "스크린샷 소스 revision이 유효하지 않습니다.")
check(
    manifest.executableSHA256.range(of: #"^[a-f0-9]{64}$"#, options: .regularExpression) != nil,
    "스크린샷 앱 바이너리 해시가 유효하지 않습니다.")
let names = manifest.files.map(\.file)
check(Set(names).count == names.count, "중복 스크린샷 기록입니다.")
for entry in manifest.files {
    check(
        entry.file == URL(fileURLWithPath: entry.file).lastPathComponent
            && entry.file.hasSuffix(".png"),
        "스크린샷 파일 이름이 유효하지 않습니다: \(entry.file)")
    guard manager.fileExists(atPath: assets.appendingPathComponent(entry.file).path) else {
        failures.append("스크린샷 누락: \(entry.file)"); continue
    }
    let bytes = try Data(contentsOf: assets.appendingPathComponent(entry.file))
    let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    check(bytes.starts(with: [137, 80, 78, 71, 13, 10, 26, 10]), "PNG 형식 오류: \(entry.file)")
    check(digest == entry.sha256, "스크린샷 해시 기록 불일치: \(entry.file)")
    check(!entry.origin.isEmpty, "스크린샷 출처 누락: \(entry.file)")
}
let pngs = try manager.contentsOfDirectory(at: assets, includingPropertiesForKeys: nil)
    .filter { $0.pathExtension == "png" }.map(\.lastPathComponent)
check(Set(pngs) == Set(names), "PNG와 스크린샷 기록 목록이 다릅니다.")
if !failures.isEmpty {
    for failure in failures { fputs("검사 실패: \(failure)\n", stderr) }
    exit(1)
}
print("구조·문서 링크·스크린샷 \(names.count)개 기록 검사 통과")
