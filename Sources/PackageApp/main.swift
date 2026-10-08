import Foundation

let manager = FileManager.default
let root = URL(fileURLWithPath: manager.currentDirectoryPath)
let release = CommandLine.arguments.contains("--release")
let configuration = release ? "release" : "debug"
func run(_ executable: String, _ arguments: [String]) throws {
    let process = Process(); process.executableURL = URL(fileURLWithPath: executable);
    process.arguments = arguments
    try process.run(); process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw NSError(domain: "PackageApp", code: Int(process.terminationStatus))
    }
}
func output(_ executable: String, _ arguments: [String]) throws -> String {
    let process = Process(); process.executableURL = URL(fileURLWithPath: executable);
    process.arguments = arguments
    let pipe = Pipe(); process.standardOutput = pipe
    try process.run(); let data = pipe.fileHandleForReading.readDataToEndOfFile();
    process.waitUntilExit()
    guard process.terminationStatus == 0, let value = String(data: data, encoding: .utf8),
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
        throw NSError(domain: "PackageApp", code: Int(process.terminationStatus))
    }
    return value.trimmingCharacters(in: .whitespacesAndNewlines)
}
let minimumVersion = "14.0"
let sdkPath = try output("/usr/bin/xcrun", ["--sdk", "macosx", "--show-sdk-path"])
let sdkVersion = try output("/usr/bin/xcrun", ["--sdk", "macosx", "--show-sdk-version"])
guard sdkVersion.range(of: #"^\d+\.\d+(\.\d+)?$"#, options: .regularExpression) != nil else {
    fatalError("SDK 버전을 확인하지 못했습니다.")
}
// Swift Build can record the deployment target as the linked SDK. That enables
// legacy AppKit appearances even when compiling against the current SDK.
// Link with the real SDK reported by xcrun, keeping the minimum OS separate.
let buildOptions = [
    "-c", configuration, "--sdk", sdkPath,
    "-Xlinker", "-platform_version", "-Xlinker", "macos",
    "-Xlinker", minimumVersion, "-Xlinker", sdkVersion,
]
if !CommandLine.arguments.contains("--no-build") {
    try run("/usr/bin/env", ["swift", "build"] + buildOptions + ["--product", "Baeuja"])
}
let path = try output("/usr/bin/env", ["swift", "build"] + buildOptions + ["--show-bin-path"])
let build = URL(fileURLWithPath: path)
let loadCommands = try output(
    "/usr/bin/otool", ["-l", build.appendingPathComponent("Baeuja").path])
let sdkPattern = #"\bsdk\s+"# + NSRegularExpression.escapedPattern(for: sdkVersion) + #"(?:\s|$)"#
guard loadCommands.range(of: sdkPattern, options: .regularExpression) != nil else {
    fatalError("실행 파일의 SDK가 현재 SDK와 다릅니다. --no-build 없이 다시 빌드하세요.")
}
let bundle = root.appendingPathComponent("dist/배우자.app")
let contents = bundle.appendingPathComponent("Contents"),
    macOS = contents.appendingPathComponent("MacOS"),
    resources = contents.appendingPathComponent("Resources")
if manager.fileExists(atPath: bundle.path) { try manager.removeItem(at: bundle) }
try manager.createDirectory(at: macOS, withIntermediateDirectories: true)
try manager.createDirectory(at: resources, withIntermediateDirectories: true)
try manager.copyItem(
    at: build.appendingPathComponent("Baeuja"), to: macOS.appendingPathComponent("Baeuja"))
for item in try manager.contentsOfDirectory(at: build, includingPropertiesForKeys: nil)
where item.pathExtension == "bundle" && item.lastPathComponent.hasPrefix("Baeuja_") {
    try manager.copyItem(at: item, to: resources.appendingPathComponent(item.lastPathComponent))
}
for language in ["ko", "en"] {
    let localization = root.appendingPathComponent("AppResources/" + language + ".lproj")
    try manager.copyItem(
        at: localization, to: resources.appendingPathComponent(language + ".lproj"))
}
var info: [String: Any] = [
    "CFBundleName": "배우자", "CFBundleDisplayName": "배우자",
    "CFBundleDevelopmentRegion": "ko", "CFBundleLocalizations": ["ko", "en"],
    // Keep the installed app identity so existing preferences remain available.
    "CFBundleIdentifier": "com.zzoe.study-swift", "CFBundleExecutable": "Baeuja",
    "CFBundlePackageType": "APPL", "CFBundleShortVersionString": "0.1.0", "CFBundleVersion": "3",
    "LSMinimumSystemVersion": minimumVersion, "DTSDKName": "macosx" + sdkVersion,
    "NSHighResolutionCapable": true, "NSPrincipalClass": "NSApplication",
]
let iconInfo = try installAppIcon(
    root: root, resources: resources, refresh: CommandLine.arguments.contains("--refresh-icon"))
info.merge(iconInfo) { _, iconValue in iconValue }
try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(
    to: contents.appendingPathComponent("Info.plist"))
try run("/usr/bin/codesign", ["--force", "--deep", "--sign", "-", bundle.path])
print("앱 생성: \(bundle.path) / SDK \(sdkVersion) / 최소 macOS \(minimumVersion)")
