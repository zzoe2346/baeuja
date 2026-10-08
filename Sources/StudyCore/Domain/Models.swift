import Foundation

public enum StudyError: Error, LocalizedError, Equatable {
    case invalid(String), storage(String), generation(String), cancelled, timeout
    public var errorDescription: String? {
        switch self {
        case .invalid(let message), .storage(let message), .generation(let message): return message
        case .cancelled: return "생성을 취소했습니다. 저장된 교재와 진행은 유지됩니다."
        case .timeout: return "생성 제한 시간이 지났습니다. 저장된 자료를 유지했습니다. 직접 재시도하세요."
        }
    }
}

public struct PlanPart: Codable, Equatable, Sendable {
    public var ordinal: Int
    public var title: String
    public var objectives: [String]
    public var minutes: Int
    public init(ordinal: Int, title: String, objectives: [String], minutes: Int = 35) {
        self.ordinal = ordinal; self.title = title; self.objectives = objectives;
        self.minutes = minutes
    }
}
public struct Plan: Codable, Equatable, Sendable {
    public var schemaVersion: Int = 1
    public var topic: String
    public var title: String
    public var objectives: [String]
    public var scope: String
    public var parts: [PlanPart]
    public init(
        topic: String, title: String, objectives: [String], scope: String, parts: [PlanPart]
    ) {
        self.topic = topic; self.title = title; self.objectives = objectives; self.scope = scope;
        self.parts = parts
    }
    public func validate() throws {
        guard schemaVersion == 1, !topic.trimmed.isEmpty, !title.trimmed.isEmpty,
            !scope.trimmed.isEmpty, !objectives.isEmpty,
            objectives.allSatisfy({ !$0.trimmed.isEmpty }),
            !parts.isEmpty, parts.count <= 20
        else { throw StudyError.invalid("과정 제목·목표·범위와 파트 구성을 확인하세요.") }
        for (index, part) in parts.enumerated() {
            guard part.ordinal == index + 1, (30...45).contains(part.minutes),
                !part.title.trimmed.isEmpty,
                !part.objectives.isEmpty, part.objectives.allSatisfy({ !$0.trimmed.isEmpty })
            else {
                throw StudyError.invalid("파트 번호는 연속이며, 각 파트는 목표와 30~45분 분량이 필요합니다.")
            }
        }
    }
}
public struct LessonSection: Codable, Equatable, Sendable {
    public var kind: String
    public var title: String
    public var bodyMarkdown: String
    public var visualIds: [String]
    public var sourceIds: [String]
    public init(
        kind: String, title: String, bodyMarkdown: String, visualIds: [String] = [],
        sourceIds: [String] = []
    ) {
        self.kind = kind; self.title = title; self.bodyMarkdown = bodyMarkdown
        self.visualIds = visualIds; self.sourceIds = sourceIds
    }
}
public struct VisualCandidate: Codable, Equatable, Sendable {
    public var kind: String
    public var source: String
    public init(kind: String, source: String) { self.kind = kind; self.source = source }
}
public struct LessonVisual: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var kind: String
    public var source: String
    public var caption: String
    public var altText: String
    public var fallbacks: [VisualCandidate]
    public init(
        id: String, kind: String, source: String, caption: String, altText: String,
        fallbacks: [VisualCandidate] = []
    ) {
        self.id = id; self.kind = kind; self.source = source; self.caption = caption;
        self.altText = altText; self.fallbacks = fallbacks
    }
}
public struct Quiz: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var question: String
    public var answer: String
    public var explanation: String
    public init(id: String, question: String, answer: String, explanation: String) {
        self.id = id; self.question = question; self.answer = answer; self.explanation = explanation
    }
}
public struct LessonSource: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var url: String
    public var checkedAt: String?
    public init(id: String, title: String, url: String, checkedAt: String? = nil) {
        self.id = id; self.title = title; self.url = url; self.checkedAt = checkedAt
    }
}
public struct FollowUp: Codable, Equatable, Sendable {
    public var topic: String
    public var reason: String
    public init(topic: String, reason: String) { self.topic = topic; self.reason = reason }
}
public struct Lesson: Codable, Equatable, Sendable {
    public var schemaVersion: Int = 1
    public var title: String
    public var minutes: Int
    public var sections: [LessonSection]
    public var visuals: [LessonVisual]
    public var quizzes: [Quiz]
    public var sources: [LessonSource]
    public var followUps: [FollowUp]
    public init(
        title: String, minutes: Int = 35, sections: [LessonSection], visuals: [LessonVisual],
        quizzes: [Quiz], sources: [LessonSource], followUps: [FollowUp]
    ) {
        self.title = title; self.minutes = minutes; self.sections = sections; self.visuals = visuals
        self.quizzes = quizzes; self.sources = sources; self.followUps = followUps
    }
    public func validate() throws {
        guard schemaVersion == 1, !title.trimmed.isEmpty, (30...45).contains(minutes),
            sections.count >= 4,
            !visuals.isEmpty, !quizzes.isEmpty, !sources.isEmpty, !followUps.isEmpty
        else {
            throw StudyError.invalid("교재 구성이나 학습 시간이 올바르지 않습니다.")
        }
        guard Set(sections.map(\.kind)) == Set(["concept", "mechanism", "example", "summary"])
        else {
            throw StudyError.invalid("교재에는 개념·원리·예제·요약이 필요합니다.")
        }
        try uniqueIDs(visuals.map(\.id), prefix: "v"); try uniqueIDs(quizzes.map(\.id), prefix: "q")
        try uniqueIDs(sources.map(\.id), prefix: "s")
        let visualIDs = Set(visuals.map(\.id)), sourceIDs = Set(sources.map(\.id))
        guard Set(sections.flatMap(\.visualIds)) == visualIDs,
            Set(sections.flatMap(\.sourceIds)) == sourceIDs
        else {
            throw StudyError.invalid("본문의 그림·출처 참조가 맞지 않습니다.")
        }
        for section in sections {
            guard !section.title.trimmed.isEmpty, !section.bodyMarkdown.trimmed.isEmpty else {
                throw StudyError.invalid("본문 제목이나 내용이 비어 있습니다.")
            }
        }
        for visual in visuals {
            let candidates =
                [VisualCandidate(kind: visual.kind, source: visual.source)] + visual.fallbacks
            guard ["mermaid", "svg", "image_prompt", "ascii"].contains(visual.kind),
                !visual.caption.trimmed.isEmpty,
                !visual.altText.trimmed.isEmpty, visual.fallbacks.count <= 2,
                candidates.allSatisfy({ !$0.source.trimmed.isEmpty }),
                visual.fallbacks.allSatisfy({ ["mermaid", "svg", "ascii"].contains($0.kind) }),
                visual.kind == "ascii" || visual.fallbacks.last?.kind == "ascii"
            else {
                throw StudyError.invalid("그림 정의와 저장된 ASCII 대체 후보를 확인하세요.")
            }
            for candidate in candidates where candidate.kind == "ascii" {
                try validateASCII(candidate.source)
            }
        }
        for source in sources {
            guard !source.title.trimmed.isEmpty, let url = URL(string: source.url),
                ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil
            else {
                throw StudyError.invalid("출처는 올바른 HTTP(S) 문서 주소여야 합니다.")
            }
        }
        guard
            quizzes.allSatisfy({
                !$0.question.trimmed.isEmpty && !$0.answer.trimmed.isEmpty
                    && !$0.explanation.trimmed.isEmpty
            }),
            followUps.allSatisfy({ !$0.topic.trimmed.isEmpty && !$0.reason.trimmed.isEmpty })
        else {
            throw StudyError.invalid("퀴즈나 후속 주제 내용이 비어 있습니다.")
        }
    }
}
private func uniqueIDs(_ ids: [String], prefix: String) throws {
    guard Set(ids).count == ids.count,
        ids.allSatisfy({
            $0.range(of: "^\(prefix)[1-9][0-9]*$", options: .regularExpression) != nil
        })
    else {
        throw StudyError.invalid("교재 ID 형식이 잘못됐거나 중복되었습니다.")
    }
}
public func validateASCII(_ value: String) throws {
    guard !value.trimmed.isEmpty,
        value.unicodeScalars.allSatisfy({ $0.value == 10 || (32...126).contains($0.value) }),
        value.components(separatedBy: "\n").allSatisfy({ $0.count <= 72 })
    else {
        throw StudyError.invalid("ASCII 도식은 탭 없이 줄당 72열 이내의 인쇄 가능한 문자여야 합니다.")
    }
}
public extension String { var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) } }

public struct RenderedVisual: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var kind: String
    public var content: String
    public var file: String?
    public var fallbackReason: String?
    public init(
        id: String, kind: String, content: String, file: String? = nil,
        fallbackReason: String? = nil
    ) {
        self.id = id; self.kind = kind; self.content = content; self.file = file;
        self.fallbackReason = fallbackReason
    }
}
public struct LessonRecord: Codable, Equatable, Sendable {
    public var revision: UUID = UUID()
    public var lesson: Lesson
    public var visuals: [RenderedVisual]
    public var materialDirectory: String
    public init(lesson: Lesson, visuals: [RenderedVisual], materialDirectory: String) {
        self.lesson = lesson; self.visuals = visuals; self.materialDirectory = materialDirectory
    }
}
public struct PartProgress: Codable, Equatable, Sendable {
    public var completed = false
    public var section = 0
    public var scrollOffset: Double = 0
    public var notes: [String: String] = [:]
    public var revealed: Set<String> = []
    public init() {}
}
public enum CourseStatus: String, Codable, Sendable { case draft, active, complete }
public struct Course: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID = UUID()
    public var plan: Plan
    public var status: CourseStatus = .draft
    public var currentPart = 1
    public var lessons: [String: LessonRecord] = [:]
    public var progress: [String: PartProgress] = [:]
    public var isDemo = false
    public var createdAt = Date()
    public init(plan: Plan, isDemo: Bool = false) { self.plan = plan; self.isDemo = isDemo }
    public mutating func completeCurrent() {
        guard status != .draft else { return }
        var value = progress[String(currentPart)] ?? PartProgress(); value.completed = true;
        progress[String(currentPart)] = value
        if let next = plan.parts.first(where: {
            !(progress[String($0.ordinal)]?.completed ?? false)
        }) {
            currentPart = next.ordinal; status = .active
        } else {
            status = .complete
        }
    }
    public var completionCount: Int {
        plan.parts.filter { progress[String($0.ordinal)]?.completed == true }.count
    }
}
public struct LibraryState: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var courses: [Course] = []
    public var selectedCourseId: UUID?
    public init() {}
}
