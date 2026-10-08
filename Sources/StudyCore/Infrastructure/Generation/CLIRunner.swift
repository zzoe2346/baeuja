import Foundation
import Darwin

public struct CLIResult: Sendable {
    public var exitCode: Int32
    public var output: Data
    public var error: Data
    public var completed: Bool
    public var failed: Bool
}
// Shared fields are protected by lock; cancellation and process installation can race.
// ProcessTests exercise cancellation, shutdown and child-group lifetime.
public final class ProcessControl: @unchecked Sendable {
    private let lock = NSLock()
    private var pid: pid_t = 0
    private var cancelled = false
    private var immediate = false
    public init() {}
    func install(_ value: pid_t) {
        lock.lock(); pid = value; let stop = cancelled, force = immediate; lock.unlock();
        if stop { kill(-value, force ? SIGKILL : SIGTERM) }
    }
    func clear() { lock.lock(); pid = 0; lock.unlock() }
    public func cancel() {
        lock.lock(); cancelled = true; let value = pid; lock.unlock();
        if value > 0 { kill(-value, SIGTERM) }
    }
    func stopImmediately() {
        lock.lock(); cancelled = true; immediate = true; let value = pid; lock.unlock();
        if value > 0 { kill(-value, SIGKILL) }
    }
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
}
public enum CLIRunner {
    private static let registryLock = NSLock()
    private static var active: [UUID: ProcessControl] = [:]
    public static func terminateAll() {
        let values = registryLock.withLock { Array(active.values) }
        values.forEach { $0.stopImmediately() }
    }
    public static func environment(_ source: [String: String] = ProcessInfo.processInfo.environment)
        -> [String: String]
    {
        source.filter { !["OPENAI_API_KEY", "CODEX_API_KEY"].contains($0.key) }
    }
    public static func run(
        executable: String, arguments: [String], input: String = "", cwd: URL? = nil,
        timeout: Double = 600, environment: [String: String]? = nil
    ) async throws -> CLIResult {
        let control = ProcessControl()
        let id = UUID()
        registryLock.withLock { active[id] = control }
        defer { registryLock.withLock { _ = active.removeValue(forKey: id) } }
        return try await withTaskCancellationHandler(
            operation: {
                try Task.checkCancellation()
                return try await withCheckedThrowingContinuation { continuation in
                    DispatchQueue.global(qos: .userInitiated).async {
                        do {
                            continuation.resume(
                                returning: try blocking(
                                    executable: executable, arguments: arguments, input: input,
                                    cwd: cwd, timeout: timeout,
                                    environment: environment ?? self.environment(), control: control
                                ))
                        } catch { continuation.resume(throwing: error) }
                    }
                }
            }, onCancel: { control.cancel() })
    }
    private static func blocking(
        executable: String, arguments: [String], input: String, cwd: URL?, timeout: Double,
        environment: [String: String], control: ProcessControl
    ) throws -> CLIResult {
        var stdinFD: [Int32] = [0, 0], stdoutFD: [Int32] = [0, 0], stderrFD: [Int32] = [0, 0]
        guard pipe(&stdinFD) == 0, pipe(&stdoutFD) == 0, pipe(&stderrFD) == 0 else {
            throw StudyError.generation("프로세스 통신을 준비하지 못했습니다.")
        }
        defer { for fd in stdinFD + stdoutFD + stderrFD where fd >= 0 { close(fd) } }
        var actions: posix_spawn_file_actions_t?, attributes: posix_spawnattr_t?
        posix_spawn_file_actions_init(&actions); posix_spawnattr_init(&attributes)
        defer { posix_spawn_file_actions_destroy(&actions); posix_spawnattr_destroy(&attributes) }
        posix_spawn_file_actions_adddup2(&actions, stdinFD[0], STDIN_FILENO)
        posix_spawn_file_actions_adddup2(&actions, stdoutFD[1], STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&actions, stderrFD[1], STDERR_FILENO)
        if let cwd { posix_spawn_file_actions_addchdir_np(&actions, cwd.path) }
        posix_spawnattr_setpgroup(&attributes, 0)
        posix_spawnattr_setflags(
            &attributes, Int16(POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT))
        let argv = ([executable] + arguments).map { strdup($0) } + [nil]
        let envp = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer { argv.forEach { free($0) }; envp.forEach { free($0) } }
        var pid: pid_t = 0
        let status = argv.withUnsafeBufferPointer { args in
            envp.withUnsafeBufferPointer { env in
                posix_spawn(
                    &pid, executable, &actions, &attributes, args.baseAddress!, env.baseAddress!)
            }
        }
        guard status == 0 else {
            throw StudyError.generation("Codex CLI를 실행하지 못했습니다. 설정에서 실행 파일 경로를 확인하세요.")
        }
        control.install(pid)
        close(stdinFD[0]); stdinFD[0] = -1; close(stdoutFD[1]); stdoutFD[1] = -1;
        close(stderrFD[1]); stderrFD[1] = -1
        guard fcntl(stdoutFD[0], F_SETFL, O_NONBLOCK) != -1,
            fcntl(stderrFD[0], F_SETFL, O_NONBLOCK) != -1,
            fcntl(stdinFD[1], F_SETFL, O_NONBLOCK) != -1
        else {
            kill(-pid, SIGKILL); var exit: Int32 = 0; waitpid(pid, &exit, 0); control.clear();
            throw StudyError.generation("CLI 파이프를 준비하지 못했습니다.")
        }
        // A closed input pipe reports EPIPE instead of taking down the application.
        _ = fcntl(stdinFD[1], F_SETNOSIGPIPE, 1)
        let inputData = Data(input.utf8)
        var sent = 0, output = Data(), error = Data(), pending = Data(), completed = false,
            failed = false
        var childStatus: Int32 = 0, reaped = false, stopReason: StudyError?
        let deadline = Date().addingTimeInterval(timeout)
        defer {
            kill(-pid, SIGKILL)
            if !reaped { _ = waitpid(pid, &childStatus, 0) }
            control.clear()
        }
        func consume(_ fd: Int32, stderr: Bool) throws {
            var bytes = [UInt8](repeating: 0, count: 8192)
            while true {
                let count = read(fd, &bytes, bytes.count)
                if count <= 0 { break }
                let data = Data(bytes.prefix(count))
                if stderr {
                    if error.count < 65_536 { error.append(data.prefix(65_536 - error.count)) }
                } else {
                    guard output.count + count <= 32 * 1024 * 1024 else {
                        throw StudyError.generation("CLI 출력이 허용 크기를 초과했습니다.")
                    }
                    output.append(data); pending.append(data)
                    guard pending.count <= 4 * 1024 * 1024 else {
                        throw StudyError.generation("CLI 이벤트가 허용 크기를 초과했습니다.")
                    }
                    while let newline = pending.firstIndex(of: 10) {
                        let line = pending.prefix(upTo: newline); pending.removeSubrange(...newline)
                        if let object = try? JSONSerialization.jsonObject(with: line)
                            as? [String: Any], let type = object["type"] as? String
                        {
                            if type == "turn.completed" { completed = true }
                            if type == "turn.failed" || type == "error" { failed = true }
                        }
                    }
                }
            }
        }
        while true {
            if control.isCancelled { stopReason = .cancelled; break }
            if Date() >= deadline { stopReason = .timeout; break }
            if stdinFD[1] >= 0 {
                if sent < inputData.count {
                    let count = inputData.withUnsafeBytes { bytes in
                        write(
                            stdinFD[1], bytes.baseAddress!.advanced(by: sent),
                            inputData.count - sent)
                    }
                    if count > 0 {
                        sent += count
                    } else if errno == EPIPE {
                        close(stdinFD[1]); stdinFD[1] = -1
                    }
                }
                if sent == inputData.count && stdinFD[1] >= 0 { close(stdinFD[1]); stdinFD[1] = -1 }
            }
            try consume(stdoutFD[0], stderr: false); try consume(stderrFD[0], stderr: true)
            let value = waitpid(pid, &childStatus, WNOHANG)
            if value == pid {
                reaped = true; try consume(stdoutFD[0], stderr: false);
                try consume(stderrFD[0], stderr: true); break
            }
            if value < 0 { throw StudyError.generation("CLI 종료 상태를 읽지 못했습니다.") }
            Thread.sleep(forTimeInterval: 0.02)
        }
        if let stopReason { throw stopReason }
        if !pending.isEmpty,
            let object = try? JSONSerialization.jsonObject(with: pending) as? [String: Any],
            object["type"] as? String == "turn.completed"
        {
            completed = true
        }
        let exitCode =
            (childStatus & 0x7f) == 0 ? (childStatus >> 8) & 0xff : 128 + (childStatus & 0x7f)
        return CLIResult(
            exitCode: exitCode, output: output, error: error, completed: completed, failed: failed)
    }
}
