import SwiftUI
import StudyCore

@main struct StudySwiftApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store: StudyStore
    @AppStorage("readerFontSize") private var fontSize = ReaderTypography.defaultSize
    @AppStorage("appearance") private var appearance = "light"
    init() {
        let args = ProcessInfo.processInfo.arguments
        let root: URL
        if let index = args.firstIndex(of: "--data-dir"), args.indices.contains(index + 1) { root = URL(fileURLWithPath: args[index + 1], isDirectory: true) }
        else { root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("StudySwift") }
        _store = StateObject(wrappedValue: StudyStore(root: root))
    }
    var body: some Scene {
        Window("Study Swift", id: "study") {
            LibraryView(store: store)
                .preferredColorScheme(appearance == "system" ? nil : appearance == "dark" ? .dark : .light)
                .frame(minWidth: 860, minHeight: 600)
                .onAppear { delegate.store = store }
        }
        .defaultSize(width: 1120, height: 780)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("새 학습 과정") { store.showingNewCourse = true }.keyboardShortcut("n").disabled(store.busy)
                Button("파트 PDF 내보내기") { store.exportPDF() }.keyboardShortcut("p").disabled(store.record == nil || store.busy)
            }
            CommandGroup(after: .textEditing) {
                Button("본문 크게") { fontSize = min(ReaderTypography.sizeRange.upperBound, fontSize + 1) }.keyboardShortcut("+", modifiers: .command)
                Button("본문 작게") { fontSize = max(ReaderTypography.sizeRange.lowerBound, fontSize - 1) }.keyboardShortcut("-", modifiers: .command)
                Button("기본 글자 크기") { fontSize = ReaderTypography.defaultSize }.keyboardShortcut("0", modifiers: .command)
            }
            CommandGroup(replacing: .help) { Button("사용 안내") { NSWorkspace.shared.open(URL(string: "https://github.com/zzoe2346/study-swift#readme")!) } }
        }
        Settings { SettingsView().frame(width: 520).preferredColorScheme(appearance == "system" ? nil : appearance == "dark" ? .dark : .light) }
    }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var store: StudyStore?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular); NSApplication.shared.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillResignActive(_ notification: Notification) { store?.flushScrollOffset() }
    func applicationWillTerminate(_ notification: Notification) { store?.flushScrollOffset(); CLIRunner.terminateAll() }
}

struct SettingsView: View {
    @AppStorage("readerFontSize") private var fontSize = ReaderTypography.defaultSize
    @AppStorage("appearance") private var appearance = "light"
    @AppStorage("codexExecutable") private var executable = CodexSettings.defaultExecutable
    @AppStorage("searchMode") private var search = "cached"
    @AppStorage("generateImages") private var images = true
    var body: some View {
        Form {
            Section("읽기 환경") {
                Picker("화면 밝기", selection: $appearance) { Text("밝게").tag("light"); Text("어둡게").tag("dark"); Text("시스템 설정").tag("system") }
                Slider(value: $fontSize, in: ReaderTypography.sizeRange, step: 1) { Text("본문 크기 · \(Int(fontSize))pt") }
                Text("글자 크기와 테마는 앱을 다시 열어도 유지됩니다.").foregroundStyle(.secondary)
            }
            Section("교재 생성") {
                TextField("Codex 실행 파일", text: $executable)
                Picker("출처 검색", selection: $search) { Text("기본 검색").tag("cached"); Text("최신 자료 확인").tag("live") }
                Toggle("필요한 삽화 생성", isOn: $images)
                Text("기존 ChatGPT 구독 로그인으로 생성합니다. 구독 한도가 적용되며, API 키로 전환하지 않습니다.").foregroundStyle(.secondary)
            }
        }.formStyle(.grouped).padding(12)
    }
}
