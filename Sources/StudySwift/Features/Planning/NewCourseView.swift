import SwiftUI
import StudyCore

struct NewCourseView: View {
    @ObservedObject var store: StudyStore
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("새 학습 과정").font(.title2.weight(.semibold))
            Text("어떤 주제를 공부하고 싶나요?").font(.body)
            TextField("예: 별의 일생, 미분의 의미, B-tree 인덱스", text: $store.newTopic, axis: .vertical)
                .textFieldStyle(.roundedBorder).font(.system(size: 17)).lineLimit(2...4).onSubmit {
                    create()
                }
            Text("먼저 목표와 계획을 확인합니다. 파트는 30~45분이며, 시작 전에 편집할 수 있습니다.")
                .font(.callout).foregroundStyle(.secondary)
            if store.busy {
                HStack {
                    ProgressView().controlSize(.small); Text(store.activity).font(.callout);
                    Button("취소") { store.cancel() }
                }
            }
            HStack {
                Button("취소") { store.showingNewCourse = false }.keyboardShortcut(.cancelAction)
                    .disabled(store.busy)
                Spacer()
                Button(store.busy ? "구성 중…" : "계획 만들기") { create() }
                    .keyboardShortcut(.defaultAction).studyActionStyle(prominent: true)
                    .disabled(store.busy || store.newTopic.trimmed.isEmpty)
            }.padding(.top, 8)
        }.padding(24).frame(width: 460).interactiveDismissDisabled(store.busy)
    }
    private func create() {
        if !store.busy && !store.newTopic.trimmed.isEmpty {
            store.requestPlan(topic: store.newTopic)
        }
    }
}
