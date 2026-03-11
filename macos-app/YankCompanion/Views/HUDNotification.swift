import AppKit
import SwiftUI

class HUDNotification {
    static let shared = HUDNotification()

    private var hudWindow: NSWindow?
    private var hideTimer: Timer?

    func show(message: String, duration: TimeInterval = 2.0) {
        DispatchQueue.main.async { [weak self] in
            self?.hideTimer?.invalidate()
            self?.hudWindow?.orderOut(nil)

            guard let screen = NSScreen.main else { return }
            let screenFrame = screen.visibleFrame

            let hudWidth: CGFloat = 280
            let lineCount = message.components(separatedBy: "\n").count
            let hudHeight: CGFloat = max(60, CGFloat(30 + lineCount * 24))

            let hudX = screenFrame.midX - hudWidth / 2
            let hudY = screenFrame.minY + 60

            let window = NSWindow(
                contentRect: NSRect(x: hudX, y: hudY, width: hudWidth, height: hudHeight),
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.level = .floating
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .stationary]

            let hostingView = NSHostingView(rootView: HUDView(message: message))
            hostingView.frame = NSRect(x: 0, y: 0, width: hudWidth, height: hudHeight)
            window.contentView = hostingView

            window.alphaValue = 0
            window.orderFrontRegardless()

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                window.animator().alphaValue = 1
            }

            self?.hudWindow = window
            self?.hideTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.3
                    window.animator().alphaValue = 0
                }, completionHandler: {
                    window.orderOut(nil)
                    self?.hudWindow = nil
                })
            }
        }
    }
}

struct HUDView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            )
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.black.opacity(0.6))
            )
    }
}
