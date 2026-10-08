import SwiftUI

struct NativeReaderScroll<Content: View>: NSViewRepresentable {
    let offset: Double
    let onOffset: (Double) -> Void
    @ViewBuilder let content: () -> Content
    func makeCoordinator() -> Coordinator { Coordinator(onOffset: onOffset, offset: offset) }
    // The viewport takes its proposed size, never the document's intrinsic height.
    // This avoids recursive SwiftUI/AppKit sizing when a section contains images.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context)
        -> CGSize?
    {
        CGSize(
            width: proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? 0,
            height: proposal.height.flatMap { $0.isFinite ? $0 : nil } ?? 0)
    }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = ReaderScrollView(); scroll.hasVerticalScroller = true;
        scroll.autohidesScrollers = true; scroll.drawsBackground = false
        let host = NSHostingView(
            rootView: AnyView(content().fixedSize(horizontal: false, vertical: true)));
        host.translatesAutoresizingMaskIntoConstraints = false
        host.sizingOptions = [.intrinsicContentSize]
        scroll.documentView = host
        NSLayoutConstraint.activate([
            host.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor)
        ])
        context.coordinator.scroll = scroll
        scroll.onResize = { [weak coordinator = context.coordinator] in coordinator?.resized() }
        scroll.contentView.postsBoundsChangedNotifications = true
        context.coordinator.token = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification, object: scroll.contentView, queue: .main
        ) { [weak coordinator = context.coordinator] _ in coordinator?.changed() }
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.onOffset = onOffset
        context.coordinator.initial = offset
        context.coordinator.makeRoot = { width in
            AnyView(content().frame(width: width).fixedSize(horizontal: false, vertical: true))
        }
        context.coordinator.refresh()
    }
    final class Coordinator {
        weak var scroll: NSScrollView?
        var token: NSObjectProtocol?
        var onOffset: (Double) -> Void
        var initial: Double
        var restored = false
        var adjusting = false
        var width: CGFloat = 0
        var makeRoot: ((CGFloat) -> AnyView)?
        init(onOffset: @escaping (Double) -> Void, offset: Double) {
            self.onOffset = onOffset; initial = offset
        }
        func resized() { if let scroll, abs(scroll.contentSize.width - width) > 0.5 { refresh() } }
        func refresh() {
            guard let scroll, let host = scroll.documentView as? NSHostingView<AnyView>,
                let makeRoot, scroll.contentSize.width > 0
            else { return }
            adjusting = true; width = scroll.contentSize.width
            host.rootView = makeRoot(width)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                host.invalidateIntrinsicContentSize(); scroll.layoutSubtreeIfNeeded();
                host.layoutSubtreeIfNeeded()
                self.restore(); self.adjusting = false
            }
        }
        func restore() {
            guard let scroll, let view = scroll.documentView else { return }
            restored = true
            let y = min(
                max(0, initial), max(0, view.frame.height - scroll.contentView.bounds.height))
            scroll.contentView.scroll(to: NSPoint(x: 0, y: y));
            scroll.reflectScrolledClipView(scroll.contentView)
        }
        func changed() {
            guard restored, !adjusting, let scroll else { return };
            onOffset(max(0, scroll.contentView.bounds.origin.y))
        }
        deinit { if let token { NotificationCenter.default.removeObserver(token) } }
    }
}

private final class ReaderScrollView: NSScrollView {
    var onResize: (() -> Void)?
    override func layout() { super.layout(); onResize?() }
}
