import CryptoKit
import Foundation

// Keep native compiled assets so packaging also works with Command Line Tools.
// Verify both source and output hashes to reject stale or incomplete icons.
func installAppIcon(root: URL, resources: URL, refresh: Bool) throws -> [String: Any] {
    let manager = FileManager.default
    let artwork = root.appendingPathComponent("Artwork/AppIcon")
        .standardizedFileURL.resolvingSymlinksInPath()
    let source = artwork.appendingPathComponent("AppIcon.icon")
    let compiled = artwork.appendingPathComponent("Compiled")
    let manifest = compiled.appendingPathComponent("hashes.json")
    let outputs = ["AppIcon.icns", "Assets.car", "icon-info.plist"]

    func fingerprints() throws -> [String: String] {
        guard
            let files = manager.enumerator(
                at: source, includingPropertiesForKeys: [.isRegularFileKey])
        else { throw CocoaError(.fileReadNoSuchFile) }
        var result: [String: String] = [:]
        var urls: [URL] = []
        for case let file as URL in files
        where try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
            urls.append(file)
        }
        urls += outputs.map { compiled.appendingPathComponent($0) }
        for file in urls {
            let path = file.standardizedFileURL.resolvingSymlinksInPath().path
            let name = String(path.dropFirst(artwork.path.count + 1))
            result[name] = SHA256.hash(data: try Data(contentsOf: file))
                .map { String(format: "%02x", $0) }.joined()
        }
        return result
    }

    if refresh {
        let temporary = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try manager.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: temporary) }
        try run(
            "/usr/bin/xcrun",
            [
                "actool", "--compile", temporary.path, "--platform", "macosx",
                "--minimum-deployment-target", "14.0", "--app-icon", "AppIcon",
                "--output-partial-info-plist",
                temporary.appendingPathComponent("icon-info.plist").path,
                "--output-format", "human-readable-text", "--warnings", "--errors", source.path,
            ])
        try manager.createDirectory(at: compiled, withIntermediateDirectories: true)
        for name in outputs {
            let destination = compiled.appendingPathComponent(name)
            if manager.fileExists(atPath: destination.path) {
                try manager.removeItem(at: destination)
            }
            try manager.copyItem(at: temporary.appendingPathComponent(name), to: destination)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(fingerprints()).write(to: manifest, options: .atomic)
    }

    let expected = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: manifest))
    guard try expected == fingerprints() else {
        throw NSError(
            domain: "PackageApp.Icon", code: 1,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "아이콘 원본과 컴파일 결과가 다릅니다. Xcode에서 --refresh-icon으로 다시 패키징하세요."
            ])
    }
    for name in outputs where name != "icon-info.plist" {
        try manager.copyItem(
            at: compiled.appendingPathComponent(name), to: resources.appendingPathComponent(name))
    }
    guard
        let info = try PropertyListSerialization.propertyList(
            from: Data(contentsOf: compiled.appendingPathComponent("icon-info.plist")),
            format: nil) as? [String: Any],
        info["CFBundleIconName"] as? String == "AppIcon",
        info["CFBundleIconFile"] as? String == "AppIcon"
    else { throw CocoaError(.propertyListReadCorrupt) }
    return info
}
