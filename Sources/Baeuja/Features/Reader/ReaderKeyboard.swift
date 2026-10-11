import SwiftUI

/// Observe only this reader's window, leaving text editing and native controls their keys.
struct ReaderKeyboard: NSViewRepresentable {
    let move: (Int) -> Bool
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.view = view
        context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            [weak coordinator = context.coordinator] event in
            guard let coordinator, let window = coordinator.view?.window,
                event.window === window, window.isKeyWindow, window.attachedSheet == nil,
                NSApp.modalWindow == nil,
                event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty,
                event.keyCode == 123 || event.keyCode == 124,
                !(window.firstResponder is NSTextView),
                !(window.firstResponder is NSControl)
            else { return event }
            return coordinator.move?(event.keyCode == 123 ? -1 : 1) == true ? nil : event
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) { context.coordinator.move = move }
    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        if let monitor = coordinator.monitor { NSEvent.removeMonitor(monitor) }
        coordinator.monitor = nil
    }
    final class Coordinator {
        weak var view: NSView?
        var monitor: Any?
        var move: ((Int) -> Bool)?
    }
}
