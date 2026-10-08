import Foundation

public enum DemoContent {
    public static func course() -> Course {
        let plan = Plan(topic: "데이터베이스 인덱스", title: "인덱스를 이해하는 두 번의 공부", objectives: ["인덱스가 탐색을 줄이는 원리를 설명한다", "조회 성능과 쓰기 비용의 균형을 판단한다"], scope: "B-tree 탐색과 복합 인덱스의 기본. PostgreSQL의 실행 계획을 읽는 첫 단계까지 다룹니다.", parts: [
            PlanPart(ordinal: 1, title: "찾는 순서를 바꾸면 생기는 일", objectives: ["전체 탐색과 인덱스 탐색의 차이를 설명한다"]),
            PlanPart(ordinal: 2, title: "좋은 인덱스에도 비용이 있다", objectives: ["복합 인덱스와 쓰기 비용을 함께 판단한다"])
        ])
        var course = Course(plan: plan, isDemo: true); course.status = .active
        for part in plan.parts {
            let lesson = self.lesson(ordinal: part.ordinal)
            let visuals = lesson.visuals.map { RenderedVisual(id: $0.id, kind: "ascii", content: $0.fallbacks.last?.source ?? $0.source, fallbackReason: "샘플은 저장된 ASCII 도식으로도 읽을 수 있습니다.") }
            course.lessons[String(part.ordinal)] = LessonRecord(lesson: lesson, visuals: visuals, materialDirectory: "samples")
        }
        return course
    }
    public static func lesson(ordinal: Int = 1) -> Lesson {
        let first = ordinal == 1
        let diagram = "+----------------+\n|  Root: 10, 30  |\n+-------+--------+\n        |\n   +----+----+\n   |         |\n+--+---+  +--+----+\n| 1..9 |  | 10..29|\n+------+  +-------+"
        let visual = LessonVisual(id: "v1", kind: "mermaid", source: "flowchart TD\n R[Root: 10, 30] --> A[Leaf: 1 to 9]\n R --> B[Leaf: 10 to 29]", caption: "분기 조건을 따라 필요한 구간으로 이동합니다. 실제 B-tree에는 더 많은 노드와 연결 정보가 있습니다.", altText: "루트가 값의 범위에 따라 두 리프 구간으로 분기하는 간략한 그림.", fallbacks: [VisualCandidate(kind: "ascii", source: diagram)])
        return Lesson(title: first ? "찾는 순서를 바꾸면 생기는 일" : "좋은 인덱스에도 비용이 있다", sections: [
            LessonSection(kind: "concept", title: first ? "책의 목차처럼, 찾는 길을 만든다" : "조회가 빨라지는 만큼 관리도 필요하다", bodyMarkdown: first ? "데이터베이스에서 **인덱스**는 원하는 행으로 가는 길을 따로 정리한 자료 구조입니다. 책의 모든 페이지를 넘기는 대신 목차에서 위치를 찾는 것과 비슷합니다.\n\n인덱스가 없으면 조건을 만족하는 행을 찾기 위해 많은 행을 확인할 수 있습니다. 인덱스가 있으면 정렬된 키를 따라 탐색 범위를 좁힐 수 있습니다.\n\n- 인덱스가 항상 더 빠른 것은 아닙니다.\n- 대부분의 행이 필요한 조회에는 전체 탐색이 유리할 수 있습니다.\n- 읽기가 빨라지는 대신 저장 공간과 쓰기 비용이 늘어납니다.\n\n**생각해보기** · 전화번호부에서 이름으로 찾는 경우와 주소만으로 찾는 경우를 비교해보세요." : "인덱스는 테이블과 함께 갱신됩니다. 행이 추가되거나 키가 바뀌면 관련 인덱스도 수정해야 합니다. 조회 조건에 맞는 인덱스를 선택하되 쓰기 빈도와 저장 공간을 함께 고려합니다.", sourceIds: ["s1"]),
            LessonSection(kind: "mechanism", title: "범위를 줄여가는 탐색", bodyMarkdown: "B-tree는 여러 단계의 분기와 정렬된 키를 통해 탐색할 범위를 좁힙니다. 다음 그림의 `Root`는 찾는 값에 따라 적절한 구간을 선택하는 시작점입니다.\n\n1. 찾는 값을 루트의 경계값과 비교합니다.\n2. 해당하는 하위 구간으로 이동합니다.\n3. 같은 방식으로 탐색을 반복해 리프에 도달합니다.\n\n그림의 숫자는 구조를 설명하기 위한 예시입니다. 실제 구현의 페이지 크기나 키 수를 의미하지 않습니다.", visualIds: ["v1"]),
            LessonSection(kind: "example", title: "조건과 실행 계획을 함께 읽기", bodyMarkdown: "다음은 PostgreSQL에서 특정 이메일을 자주 찾는 상황입니다. 로컬 연습용 데이터베이스에서만 실행해보세요.\n\n```sql\nCREATE INDEX users_email_idx\n    ON users (email);\n\nEXPLAIN SELECT id, email\nFROM users\nWHERE email = 'reader@example.com';\n```\n\n실행 계획에 인덱스 탐색이 나오는지 확인하고, 같은 쿼리에서 인덱스가 없을 때와 비교합니다. 작은 테이블에서는 순차 탐색이 선택될 수 있습니다.\n\n**활동** · 읽기와 쓰기 중 어느 쪽이 더 자주 일어나는 서비스인지 적고, 인덱스를 추가할 이유를 한 문장으로 정리하세요."),
            LessonSection(kind: "summary", title: "오늘 기억할 세 가지", bodyMarkdown: "- 인덱스는 원하는 행으로 가는 탐색 범위를 줄입니다.\n- 효율은 조회 조건, 데이터 분포, 반환 행 수에 따라 달라집니다.\n- 조회 성능과 저장 공간·쓰기 비용을 함께 판단합니다.\n\n이제 퀴즈에서 직접 설명해보세요. 답을 입력하지 않아도 정답을 확인하거나 다음 파트로 이동할 수 있습니다.")
        ], visuals: [visual], quizzes: [
            Quiz(id: "q1", question: "테이블의 거의 모든 행을 읽는 쿼리에서도 인덱스가 항상 유리할까요?", answer: "항상 유리하지는 않습니다.", explanation: "인덱스를 거쳐 많은 행을 읽는 비용이 전체 탐색보다 클 수 있습니다. 옵티마이저는 데이터 분포와 비용 추정에 따라 접근 방식을 선택합니다."),
            Quiz(id: "q2", question: "인덱스를 추가할 때 조회 성능 외에 무엇을 확인해야 할까요?", answer: "저장 공간, 쓰기 빈도와 갱신 비용, 실제 조회 조건을 확인합니다.", explanation: "행 변경 시 인덱스도 갱신되어야 하므로 쓰기가 많은 서비스에서는 유지 비용이 커질 수 있습니다.")
        ], sources: [LessonSource(id: "s1", title: "PostgreSQL · Indexes", url: "https://www.postgresql.org/docs/current/indexes.html")], followUps: [FollowUp(topic: "복합 인덱스의 컬럼 순서", reason: "여러 조회 조건이 인덱스 탐색 범위에 어떤 영향을 주는지 이해할 수 있습니다."), FollowUp(topic: "별의 일생", reason: "다른 분야의 주제로도 새로운 학습 과정을 시작할 수 있습니다.")])
    }
}
