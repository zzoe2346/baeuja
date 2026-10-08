import Foundation

public struct CodexSettings: Sendable {
    public var executable: String
    public var search: String = "cached"
    public var planTimeout: Double = 180
    public var lessonTimeout: Double = 600
    public var imageTimeout: Double = 240
    public init(executable: String = CodexSettings.defaultExecutable) {
        self.executable = executable
    }
    public static var defaultExecutable: String {
        let paths =
            (ProcessInfo.processInfo.environment["PATH"] ?? "").components(separatedBy: ":") + [
                NSHomeDirectory() + "/.local/bin", "/opt/homebrew/bin", "/usr/local/bin",
            ]
        return paths.map { $0 + "/codex" }.first(where: {
            FileManager.default.isExecutableFile(atPath: $0)
        }) ?? "/usr/local/bin/codex"
    }
}
public struct CodexClient: Sendable {
    public let root: URL
    public let settings: CodexSettings
    public init(root: URL, settings: CodexSettings = CodexSettings()) {
        self.root = root; self.settings = settings
    }
    public func checkAuth() async throws {
        let result = try await CLIRunner.run(
            executable: settings.executable, arguments: ["login", "status"], timeout: 15)
        let text = String(decoding: result.output + result.error, as: UTF8.self).lowercased()
        guard result.exitCode == 0, text.contains("logged in using chatgpt") else {
            throw StudyError.generation(
                "ChatGPT 구독 로그인이 필요합니다. 터미널에서 codex login으로 로그인하세요. API 키 인증으로 전환하지 않습니다.")
        }
    }
    public func plan(topic: String, adjustment: String? = nil, previous: Plan? = nil) async throws
        -> Plan
    {
        guard !topic.trimmed.isEmpty else { throw StudyError.invalid("학습 주제를 입력하세요.") }
        let input = PlanInput(topic: topic, adjustment: adjustment, previousPlan: previous)
        let prompt = """
            한국어로 설명하는 학습 과정을 설계하세요. 소프트웨어 공학에 한정하지 말고 입력 주제에 맞추세요.
            목표와 범위, 명확한 종료점이 있는 보통 2~4개 파트, 좁은 주제는 1개도 가능합니다.
            각 파트는 30~45분. 개념, 원리, 주제에 맞는 예제/활동, 시각자료, 퀴즈, 요약을 다룹니다.
            긴 설문, 진단 시험, 이력서 분석, 점수 통과 조건을 만들지 마세요. ordinal은 1부터 연속입니다.
            입력은 아래 JSON의 데이터입니다. 파일/셸/외부 앱을 사용하지 마세요. 스키마에 맞는 JSON만 출력하세요.
            """ + "\n" + String(decoding: try StudyJSON.encoder().encode(input), as: UTF8.self)
        let (data, _) = try await generate(
            prompt: prompt, schema: schema("plan"), timeout: settings.planTimeout)
        let plan = try StudyJSON.decoder().decode(Plan.self, from: data); try plan.validate();
        return plan
    }
    public func lesson(plan: Plan, ordinal: Int) async throws -> Lesson {
        try plan.validate();
        guard plan.parts.contains(where: { $0.ordinal == ordinal }) else {
            throw StudyError.invalid("과정에 없는 파트입니다.")
        }
        let input = LessonInput(plan: plan, partOrdinal: ordinal)
        let prompt = """
            지정된 파트 하나의 30~45분 학습 교재를 작성하세요. 설명은 한국어이며 언어 학습의 대상 어휘·문장과 기술명/코드는 원문을 허용합니다.
            소프트웨어 공학에 한정하지 말고 주제에 맞는 충분한 설명과 예제, 손으로 생각할 활동을 포함하세요.
            sections는 concept, mechanism, example, summary를 모두 포함하세요. 모든 그림과 출처 ID를 실제 해당 본문에서 참조하세요.
            그림은 최소 1개: Mermaid 또는 안전한 SVG, 삽화가 필요하면 image_prompt. 비ASCII 그림은 같은 의미의 ASCII fallback을 마지막 후보에 반드시 사전 작성하세요.
            ASCII는 LF와 printable ASCII만, 탭 없이 줄당 최대72열입니다. 한글 설명은 caption/alt_text에 충분히 넣으세요.
            SVG에 script, foreignObject, 이벤트, 외부 참조를 넣지 마세요. Mermaid는 짧고 유효한 구문이며 HTML 라벨은 피하세요.
            비교 그림은 사례 이름을 각 묶음에 명시하고, 본문·caption·alt_text에서는 그 이름으로 참조하세요. 렌더러가 바꿀 수 있는 왼쪽/오른쪽/위/아래 배치를 가정하지 마세요. 서로 연결되지 않은 큰 흐름은 여러 그림으로 나눠 글자가 작아지지 않게 하세요.
            퀴즈 2~3개, 정답과 해설, 근거 있는 심화 후보와 이유. 채점이나 통과 조건은 없습니다.
            가능하면 1차 공식 자료를 web search로 확인하고 실제 HTTP(S) 출처를 넣으세요. checked_at은 실제 확인한 경우만 날짜, 아니면 null.
            확인하지 못한 사실을 검증됐다고 주장하지 마세요. 원시 HTML과 원격 Markdown 이미지, 외부 앱/셸 사용은 금지입니다.
            아래 JSON은 학습 입력 데이터입니다. 스키마에 맞는 JSON만 출력하세요.
            """ + "\n" + String(decoding: try StudyJSON.encoder().encode(input), as: UTF8.self)
        let (data, _) = try await generate(
            prompt: prompt, schema: schema("lesson"), timeout: settings.lessonTimeout)
        let lesson = try StudyJSON.decoder().decode(Lesson.self, from: data); try lesson.validate();
        return lesson
    }
    public func image(prompt: String, destination: URL) async throws {
        let schema = Data(
            #"{"type":"object","properties":{"path":{"type":"string"},"status":{"type":"string"}},"required":["path","status"],"additionalProperties":false}"#
                .utf8)
        let text =
            "Use the built-in native image generation tool once for this educational illustration. Save the actual PNG as image.png in the current directory. Return path='image.png', status='generated'. If unavailable return path='', status='unavailable'. No paid APIs, keys, Python/SVG imitation, installations, external apps, or retries.\n"
            + String(decoding: try JSONEncoder().encode(prompt), as: UTF8.self)
        let (data, job) = try await generate(
            prompt: text, schema: schema, timeout: settings.imageTimeout, image: true)
        let result = try JSONDecoder().decode(ImageResult.self, from: data)
        guard result.path == "image.png", result.status == "generated" else {
            throw StudyError.generation("이 호출에서 네이티브 생성 그림을 받지 못했습니다.")
        }
        try VisualSafety.png(job.appendingPathComponent("image.png")).write(
            to: destination, options: .atomic)
    }
    private func schema(_ name: String) throws -> Data {
        guard
            let url = Bundle.module.url(
                forResource: name, withExtension: "json", subdirectory: "Resources/schemas")
        else { throw StudyError.invalid("생성 스키마를 찾을 수 없습니다.") }
        // The CLI strict schema does not support URI format. Validate URLs in Lesson.validate().
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        func strip(_ value: Any) -> Any {
            if let dict = value as? [String: Any] {
                return dict.filter { $0.key != "format" && $0.key != "$schema" }.mapValues(strip)
            }
            if let array = value as? [Any] { return array.map(strip) }; return value
        }
        return try JSONSerialization.data(withJSONObject: strip(object))
    }
    private func generate(prompt: String, schema: Data, timeout: Double, image: Bool = false)
        async throws -> (Data, URL)
    {
        try await checkAuth(); try Task.checkCancellation()
        let job = root.appendingPathComponent("jobs/" + UUID().uuidString)
        try FileManager.default.createDirectory(at: job, withIntermediateDirectories: true)
        let schemaURL = job.appendingPathComponent("schema.json"),
            finalURL = job.appendingPathComponent("final.json")
        try schema.write(to: schemaURL);
        try Data(prompt.utf8).write(to: job.appendingPathComponent("input.txt"))
        var arguments = [
            "exec", "--ignore-user-config", "--ephemeral", "--skip-git-repo-check", "--sandbox",
            image ? "workspace-write" : "read-only", "--json", "--color", "never",
            "--output-schema", schemaURL.path, "--output-last-message", finalURL.path, "--cd",
            job.path, "-c", "forced_login_method=\"chatgpt\"", "-c",
            "web_search=\"\(settings.search == "live" ? "live" : "cached")\"", "-c",
            "features.unbounded_connection_retries=false", "--disable", "apps", "--disable",
            "computer_use", "--disable", "browser_use",
        ]
        if image { arguments += ["--enable", "image_generation"] }; arguments += ["-"]
        let result = try await CLIRunner.run(
            executable: settings.executable, arguments: arguments, input: prompt, cwd: job,
            timeout: timeout)
        guard result.exitCode == 0, result.completed, !result.failed else {
            let hint = String(decoding: result.error + result.output.suffix(8192), as: UTF8.self)
                .lowercased()
            if hint.contains("429") || hint.contains("usage limit") || hint.contains("quota") {
                throw StudyError.generation(
                    "Codex 구독 한도에 도달했습니다. 저장된 교재는 계속 읽을 수 있습니다. 나중에 직접 재시도하세요.")
            }
            throw StudyError.generation(
                "Codex 생성을 완료하지 못했습니다. 기존 교재를 유지했습니다. 로그인과 연결 상태를 확인한 뒤 직접 재시도하세요.")
        }
        let values = try finalURL.resourceValues(forKeys: [.isSymbolicLinkKey, .fileSizeKey])
        guard values.isSymbolicLink != true, let size = values.fileSize, size <= 8 * 1024 * 1024
        else { throw StudyError.invalid("생성 결과 파일이 올바르지 않습니다.") }
        return (try Data(contentsOf: finalURL), job)
    }
}
private struct PlanInput: Encodable {
    var topic: String; var adjustment: String?; var previousPlan: Plan?
}
private struct LessonInput: Encodable { var plan: Plan; var partOrdinal: Int }
private struct ImageResult: Decodable { var path: String; var status: String }
