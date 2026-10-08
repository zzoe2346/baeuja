import SwiftUI
import StudyCore

struct CompletionView: View {
    @ObservedObject var store: StudyStore
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("기본 과정을 마쳤어요", systemImage: "checkmark.seal")
                .font(.title2.weight(.semibold))
            Text("완료한 파트는 언제든 다시 읽을 수 있습니다. 더 궁금한 주제는 선택할 때 새 과정으로 이어집니다.").foregroundStyle(
                .secondary)
            if let record = store.record {
                ForEach(Array(record.lesson.followUps.enumerated()), id: \.offset) { _, follow in
                    Button {
                        store.completionPresented = false; store.newTopic = follow.topic;
                        store.showingNewCourse = true
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(follow.topic).font(.headline).lineLimit(nil).fixedSize(
                                horizontal: false, vertical: true)
                            Text(follow.reason).font(.callout).foregroundStyle(.secondary)
                                .lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                        }.multilineTextAlignment(.leading).frame(
                            maxWidth: .infinity, alignment: .leading
                        ).padding(8)
                    }.studyActionStyle()
                }
            }
            HStack {
                Spacer();
                Button("교재로 돌아가기") { store.completionPresented = false }.keyboardShortcut(
                    .cancelAction
                ).studyActionStyle()
            }
        }.padding(24).frame(width: 460)
    }
}
