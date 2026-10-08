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
if !CommandLine.arguments.contains("--no-build") { try run("/usr/bin/env", ["swift", "build", "-c", configuration, "--product", "StudySwift"]) }
let bundle = root.appendingPathComponent("dist/Study Swift.app")
let contents = bundle.appendingPathComponent("Contents"), macOS = contents.appendingPathComponent("MacOS"), resources = contents.appendingPathComponent("Resources")
if manager.fileExists(atPath: bundle.path) { try manager.removeItem(at: bundle) }
try manager.createDirectory(at: macOS, withIntermediateDirectories: true)
try manager.createDirectory(at: resources, withIntermediateDirectories: true)
let locate = Process(); locate.executableURL = URL(fileURLWithPath: "/usr/bin/env")
locate.arguments = ["swift", "build", "-c", configuration, "--show-bin-path"]
let pipe = Pipe(); locate.standardOutput = pipe
try locate.run(); let location = pipe.fileHandleForReading.readDataToEndOfFile(); locate.waitUntilExit()
guard locate.terminationStatus == 0, let path = String(data: location, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty else { fatalError("빌드 결과 위치를 확인하지 못했습니다.") }
let build = URL(fileURLWithPath: path)
try manager.copyItem(at: build.appendingPathComponent("StudySwift"), to: macOS.appendingPathComponent("StudySwift"))
for item in try manager.contentsOfDirectory(at: build, includingPropertiesForKeys: nil) where item.pathExtension == "bundle" {
    try manager.copyItem(at: item, to: resources.appendingPathComponent(item.lastPathComponent))
}
let info: [String: Any] = ["CFBundleName": "Study Swift", "CFBundleDisplayName": "Study Swift", "CFBundleIdentifier": "com.zzoe.study-swift", "CFBundleExecutable": "StudySwift", "CFBundlePackageType": "APPL", "CFBundleShortVersionString": "0.1.0", "CFBundleVersion": "1", "LSMinimumSystemVersion": "14.0", "NSHighResolutionCapable": true, "NSPrincipalClass": "NSApplication"]
try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: contents.appendingPathComponent("Info.plist"))
try run("/usr/bin/codesign", ["--force", "--deep", "--sign", "-", bundle.path])
print("앱 생성: \(bundle.path)")
