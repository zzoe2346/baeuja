import Testing
import Foundation
import Darwin
@testable import StudyCore

@Suite(.serialized) final class ProcessTests {
    @Test func testSubscriptionEnvironmentStripsAPIKeys() {
        let value = CLIRunner.environment(["OPENAI_API_KEY": "secret", "CODEX_API_KEY": "secret", "CODEX_HOME": "existing", "PATH": "/bin"])
        expectNil(value["OPENAI_API_KEY"]); expectNil(value["CODEX_API_KEY"]); expectEqual(value["CODEX_HOME"], "existing")
    }
    @Test func testStructuredEventsAndNonZeroExit() async throws {
        let result = try await CLIRunner.run(executable: "/bin/sh", arguments: ["-c", "printf '%s\\n' '{\"type\":\"turn.completed\"}'; exit 7"], timeout: 2)
        expectTrue(result.completed); expectEqual(result.exitCode, 7)
    }
    @Test func testFailedEventIsNotCompletion() async throws {
        let result = try await CLIRunner.run(executable: "/bin/sh", arguments: ["-c", "printf '%s\\n' '{\"type\":\"turn.failed\"}' '{\"type\":\"turn.completed\"}'"], timeout: 2)
        expectTrue(result.failed)
    }
    @Test func testLargePromptIsWrittenWithoutBlocking() async throws {
        let prompt = String(repeating: "x", count: 200_000)
        let result = try await CLIRunner.run(executable: "/bin/cat", arguments: [], input: prompt, timeout: 3)
        expectEqual(result.output.count, prompt.count); expectEqual(result.exitCode, 0)
    }
    @Test func testClosedStdinDoesNotCrashApp() async throws {
        let result = try await CLIRunner.run(executable: "/usr/bin/true", arguments: [], input: String(repeating: "x", count: 200_000), timeout: 3)
        expectEqual(result.exitCode, 0)
    }
    @Test func testTimeoutStopsIgnoringChildGroup() async {
        let start = Date()
        do { _ = try await CLIRunner.run(executable: "/bin/sh", arguments: ["-c", "trap '' TERM; sleep 20 & wait"], timeout: 0.15); fail("시간 제한이 필요합니다") }
        catch { expectEqual(error as? StudyError, .timeout) }
        expectLess(Date().timeIntervalSince(start), 3)
    }
    @Test func testCancellationStopsGroup() async {
        let task = Task { try await CLIRunner.run(executable: "/bin/sh", arguments: ["-c", "sleep 20 & wait"], timeout: 20) }
        try? await Task.sleep(nanoseconds: 100_000_000); task.cancel()
        do { _ = try await task.value; fail("취소가 필요합니다") } catch { expectEqual(error as? StudyError, .cancelled) }
    }
    @Test func testMissingExecutableReportsSafeError() async { do { _ = try await CLIRunner.run(executable: "/missing/codex", arguments: [], timeout: 1); fail() } catch { expectTrue(error.localizedDescription.contains("경로")) } }
    @Test func testAppShutdownStopsActiveProcessGroup() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        let task = Task { try await CLIRunner.run(executable: "/bin/sh", arguments: ["-c", "trap '' TERM; sleep 20 & printf '%s' \"$$\" > \"$1\"; wait", "fixture", file.path], timeout: 20) }
        for _ in 0..<100 { if FileManager.default.fileExists(atPath: file.path) { break }; try await Task.sleep(nanoseconds: 20_000_000) }
        let pid = try requireValue(Int32(String(contentsOf: file, encoding: .utf8)))
        CLIRunner.terminateAll()
        do { _ = try await task.value; fail("종료 시 실행 중인 생성도 멈춰야 합니다") } catch { expectEqual(error as? StudyError, .cancelled) }
        expectEqual(kill(pid, 0), -1)
    }
}
