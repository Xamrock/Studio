import SwiftUI
import AppKit

struct ScrollableCanvas<Content: View>: NSViewRepresentable {
    let content: Content
    let onScroll: (CGFloat, CGFloat) -> Void

    init(onScroll: @escaping (CGFloat, CGFloat) -> Void, @ViewBuilder content: () -> Content) {
        self.onScroll = onScroll
        self.content = content()
    }

    func makeNSView(context: Context) -> NSHostingView<Content> {
        let hostingView = ScrollCaptureHostingView(rootView: content, onScroll: onScroll)
        return hostingView
    }

    func updateNSView(_ nsView: NSHostingView<Content>, context: Context) {
        nsView.rootView = content
    }

    class ScrollCaptureHostingView<Content: View>: NSHostingView<Content> {
        let onScroll: (CGFloat, CGFloat) -> Void

        init(rootView: Content, onScroll: @escaping (CGFloat, CGFloat) -> Void) {
            self.onScroll = onScroll
            super.init(rootView: rootView)
        }

        required init(rootView: Content) {
            fatalError("Use init(rootView:onScroll:)")
        }

        @MainActor required dynamic init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func scrollWheel(with event: NSEvent) {
            onScroll(event.scrollingDeltaX, event.scrollingDeltaY)

        }
    }
}
