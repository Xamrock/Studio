import SwiftUI
import AppKit

struct ScrollableCanvas<Content: View>: NSViewRepresentable {
    let content: Content
    let onScroll: (CGFloat, CGFloat) -> Void

    init(onScroll: @escaping (CGFloat, CGFloat) -> Void, @ViewBuilder content: () -> Content) {
        self.onScroll = onScroll
        self.content = content()
    }

    func makeNSView(context: Context) -> NSView {
        let hostingView = NSHostingView(rootView: content)
        let wrapper = ScrollWrapperView(hostingView: hostingView, onScroll: onScroll)
        return wrapper
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let wrapper = nsView as? ScrollWrapperView,
           let hostingView = wrapper.hostingView as? NSHostingView<Content> {
            hostingView.rootView = content
        }
    }
}

private class ScrollWrapperView: NSView {
    let hostingView: NSView
    let onScroll: (CGFloat, CGFloat) -> Void

    init<Content: View>(hostingView: NSHostingView<Content>, onScroll: @escaping (CGFloat, CGFloat) -> Void) {
        self.hostingView = hostingView
        self.onScroll = onScroll
        super.init(frame: .zero)

        hostingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func scrollWheel(with event: NSEvent) {
        onScroll(event.scrollingDeltaX, event.scrollingDeltaY)
    }
}
