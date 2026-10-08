import Foundation

let manager = FileManager.default
let root = URL(fileURLWithPath: manager.currentDirectoryPath)
let release = CommandLine.arguments.contains("--release")
let configuration = release ? "release" : "debug"
func run(_ executable: String, _ arguments: [String]) throws {
    let process = Process(); process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments
    try process.run(); process.waitUntilExit()
    guard process.terminationStatus == 0 else { throw NSError(domain: "PackageApp", code: Int(process.terminationStatus)) }
}
func output(_ executable: String, _ arguments: [String]) throws -> String {
    let process = Process(); process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments
    let pipe = Pipe(); process.standardOutput = pipe
    try process.run(); let data = pipe.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
    guard process.terminationStatus == 0, let value = String(data: data, encoding: .utf8), !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw NSError(domain: "PackageApp", code: Int(process.terminationStatus))
    }
    return value.trimmingCharacters(in: .whitespacesAndNewlines)
}
let minimumVersion = "14.0"
let sdkPath = try output("/usr/bin/xcrun", ["--sdk", "macosx", "--show-sdk-path"])
let sdkVersion = try output("/usr/bin/xcrun", ["--sdk", "macosx", "--show-sdk-version"])
guard sdkVersion.range(of: #"^\d+\.\d+(\.\d+)?$"#, options: .regularExpression) != nil else { fatalError("SDK 버전을 확인하지 못했습니다.") }
// Swift Build can record the deployment target as the linked SDK. That enables
// legacy AppKit appearances even when compiling against the current SDK.
// Link with the real SDK reported by xcrun, keeping the minimum OS separate.
let buildOptions = ["-c", configuration, "--sdk", sdkPath,
                    "-Xlinker", "-platform_version", "-Xlinker", "macos",
                    "-Xlinker", minimumVersion, "-Xlinker", sdkVersion]
if !CommandLine.arguments.contains("--no-build") {
    try run("/usr/bin/env", ["swift", "build"] + buildOptions + ["--product", "StudySwift"])
}
let path = try output("/usr/bin/env", ["swift", "build"] + buildOptions + ["--show-bin-path"])
let build = URL(fileURLWithPath: path)
let loadCommands = try output("/usr/bin/otool", ["-l", build.appendingPathComponent("StudySwift").path])
let sdkPattern = #"\bsdk\s+"# + NSRegularExpression.escapedPattern(for: sdkVersion) + #"(?:\s|$)"#
guard loadCommands.range(of: sdkPattern, options: .regularExpression) != nil else {
    fatalError("실행 파일의 SDK가 현재 SDK와 다릅니다. --no-build 없이 다시 빌드하세요.")
}
let bundle = root.appendingPathComponent("dist/Study Swift.app")
let contents = bundle.appendingPathComponent("Contents"), macOS = contents.appendingPathComponent("MacOS"), resources = contents.appendingPathComponent("Resources")
if manager.fileExists(atPath: bundle.path) { try manager.removeItem(at: bundle) }
try manager.createDirectory(at: macOS, withIntermediateDirectories: true)
try manager.createDirectory(at: resources, withIntermediateDirectories: true)
try manager.copyItem(at: build.appendingPathComponent("StudySwift"), to: macOS.appendingPathComponent("StudySwift"))
for item in try manager.contentsOfDirectory(at: build, includingPropertiesForKeys: nil) where item.pathExtension == "bundle" {
    try manager.copyItem(at: item, to: resources.appendingPathComponent(item.lastPathComponent))
}
let info: [String: Any] = ["CFBundleName": "Study Swift", "CFBundleDisplayName": "Study Swift", "CFBundleIdentifier": "com.zzoe.study-swift", "CFBundleExecutable": "StudySwift", "CFBundlePackageType": "APPL", "CFBundleShortVersionString": "0.1.0", "CFBundleVersion": "1", "LSMinimumSystemVersion": minimumVersion, "DTSDKName": "macosx" + sdkVersion, "NSHighResolutionCapable": true, "NSPrincipalClass": "NSApplication"]
try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: contents.appendingPathComponent("Info.plist"))
try run("/usr/bin/codesign", ["--force", "--deep", "--sign", "-", bundle.path])
print("앱 생성: \(bundle.path) · SDK \(sdkVersion) / 최소 macOS \(minimumVersion)")
