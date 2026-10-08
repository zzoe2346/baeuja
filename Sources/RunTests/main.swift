import Foundation

func capture(_ executable: String, _ arguments: [String]) throws -> String {
    let process = Process(), output = Pipe();
    process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments;
    process.standardOutput = output
    try process.run(); let data = output.fileHandleForReading.readDataToEndOfFile();
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw NSError(domain: "RunTests", code: Int(process.terminationStatus))
    }
    return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
}
let compiler = try capture("/usr/bin/xcrun", ["--find", "swiftc"])
let toolchain = URL(fileURLWithPath: compiler).deletingLastPathComponent()
    .deletingLastPathComponent()
let plugin = toolchain.appendingPathComponent(
    "lib/swift/host/plugins/testing/libTestingMacros.dylib")
var arguments = ["swift", "test", "--disable-xctest"]
if FileManager.default.fileExists(atPath: plugin.path) {
    arguments += ["-Xswiftc", "-load-plugin-library", "-Xswiftc", plugin.path]
}
arguments += Array(CommandLine.arguments.dropFirst())
let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/env");
process.arguments = arguments
try process.run(); process.waitUntilExit(); exit(process.terminationStatus)
