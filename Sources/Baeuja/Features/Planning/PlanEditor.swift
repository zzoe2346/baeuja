import SwiftUI
import StudyCore

// Preserve CLT property-wrapper compatibility.
private typealias ViewState<Value> = SwiftUI.State<Value>

private struct EditingPart: Identifiable {
    var id = UUID(); var title: String; var minutes: Int; var goals: String
}

struct PlanEditor: View {
    @ObservedObject var store: StudyStore
    let course: Course
    @ViewState<String> private var title = ""
    @ViewState<String> private var goals = ""
    @ViewState<String> private var scope = ""
    @ViewState<[EditingPart]> private var parts = []
    @ViewState<String> private var adjustment = ""
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("학습 계획", systemImage: "list.bullet.clipboard")
                Spacer()
                Text("시작 전에 편집할 수 있습니다").foregroundStyle(.secondary)
            }.font(.callout).padding(20)
            Divider()
            Form {
                Section("공부할 주제") {
                    TextField("제목", text: $title).accessibilityLabel("과정 제목")
                }
                Section("학습 목표 · 한 줄에 하나") {
                    TextEditor(text: $goals).font(.system(size: 16)).frame(minHeight: 90)
                        .accessibilityLabel("학습 목표")
                }
                Section("학습 범위") {
                    TextEditor(text: $scope).font(.system(size: 16)).frame(minHeight: 90)
                        .accessibilityLabel("학습 범위")
                }
                ForEach($parts) { $part in
                    Section("파트 \((parts.firstIndex(where: { $0.id == part.id }) ?? 0) + 1)") {
                        TextField("제목", text: $part.title)
                        Stepper("학습 시간 · \(part.minutes)분", value: $part.minutes, in: 30...45)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("이 파트의 목표 · 한 줄에 하나").font(.callout).foregroundStyle(.secondary)
                            TextEditor(text: $part.goals).font(.system(size: 16)).frame(
                                minHeight: 100
                            ).accessibilityLabel("파트 목표")
                        }
                        Button(role: .destructive) {
                            parts.removeAll { $0.id == part.id }
                        } label: {
                            Label("파트 삭제", systemImage: "minus.circle")
                        }.disabled(parts.count == 1)
                    }
                }
                Section {
                    Button {
                        parts.append(EditingPart(title: "새로운 파트", minutes: 30, goals: ""))
                    } label: {
                        Label("파트 추가", systemImage: "plus")
                    }.disabled(parts.count >= 20)
                }
                Section("AI에게 계획 조정 요청") {
                    TextField("예: 수식을 줄이고 생활 속 예제를 늘려줘", text: $adjustment)
                    Button("요청대로 조정") { adjust() }.disabled(adjustment.trimmed.isEmpty)
                }
            }.formStyle(.grouped)
            Divider()
            HStack {
                Button("계획 저장") { save(false) }.studyActionStyle()
                Spacer()
                Button("이 계획으로 시작") { save(true) }.studyActionStyle(prominent: true)
            }.padding(16).background(.bar)
        }.disabled(store.busy)
            .onAppear { load(course.plan) }
            .onChange(of: course.plan) { _, plan in load(plan) }
    }
    func load(_ plan: Plan) {
        title = plan.title; goals = plan.objectives.joined(separator: "\n"); scope = plan.scope;
        parts = plan.parts.map {
            EditingPart(
                title: $0.title, minutes: $0.minutes, goals: $0.objectives.joined(separator: "\n"))
        }
    }
    func editedPlan() -> Plan {
        Plan(
            topic: course.plan.topic, title: title,
            objectives: goals.components(separatedBy: "\n").map(\.trimmed).filter { !$0.isEmpty },
            scope: scope,
            parts: parts.enumerated().map { index, part in
                PlanPart(
                    ordinal: index + 1, title: part.title,
                    objectives: part.goals.components(separatedBy: "\n").map(\.trimmed).filter {
                        !$0.isEmpty
                    }, minutes: part.minutes)
            })
    }
    func save(_ start: Bool) { store.savePlan(editedPlan(), start: start) }
    func adjust() {
        let plan = editedPlan()
        do {
            try plan.validate();
            store.requestPlan(topic: course.plan.topic, previous: plan, adjustment: adjustment)
        } catch { store.error = error.localizedDescription }
    }
}
