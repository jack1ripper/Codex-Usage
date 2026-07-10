import SwiftUI
import AppKit

@MainActor
final class FloatingWindowController: NSObject, NSWindowDelegate {
    private let service: UsageRefreshService
    private var window: NSPanel?

    init(service: UsageRefreshService) {
        self.service = service
        super.init()
    }

    deinit {
        // `deinit` is non-isolated, so stop the service asynchronously on the
        // main actor. Callers should close the window explicitly via `close()`
        // to ensure the timer is stopped synchronously.
        let service = self.service
        Task { @MainActor in
            service.stop()
        }
    }

    func show() {
        guard window == nil else { return }

        let panel = NSPanel(
            contentRect: NSRect(x: 100, y: 100, width: 140, height: 140),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.isMovableByWindowBackground = true
        panel.delegate = self

        let contentView = FloatingBallView(
            service: service,
            onRefresh: { [weak service] in
                Task { await service?.refresh() }
            },
            onQuit: {
                NSApplication.shared.terminate(nil)
            }
        )
        panel.contentView = NSHostingView(rootView: contentView)

        restorePosition(for: panel)

        self.window = panel
        panel.orderFrontRegardless()
        service.start()
    }

    /// Closes the floating panel and stops the refresh service.
    func close() {
        window?.close()
    }

    // MARK: - NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        guard let window = window else { return }
        savePosition(of: window)
    }

    func windowWillClose(_ notification: Notification) {
        service.stop()
        window = nil
    }

    // MARK: - Position persistence

    private func savePosition(of window: NSWindow) {
        let origin = window.frame.origin
        UserDefaults.standard.set(Double(origin.x), forKey: "floatingBallX")
        UserDefaults.standard.set(Double(origin.y), forKey: "floatingBallY")
    }

    private func restorePosition(for window: NSWindow) {
        let defaultOrigin = NSPoint(x: 100, y: 100)
        let savedX = UserDefaults.standard.object(forKey: "floatingBallX") as? Double
        let savedY = UserDefaults.standard.object(forKey: "floatingBallY") as? Double
        let savedOrigin = NSPoint(
            x: savedX.map { CGFloat($0) } ?? defaultOrigin.x,
            y: savedY.map { CGFloat($0) } ?? defaultOrigin.y
        )

        let screen = window.screen ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSRect(origin: .zero, size: window.frame.size)

        let clampedOrigin = NSPoint(
            x: max(visibleFrame.minX, min(savedOrigin.x, visibleFrame.maxX - window.frame.width)),
            y: max(visibleFrame.minY, min(savedOrigin.y, visibleFrame.maxY - window.frame.height))
        )

        window.setFrameOrigin(clampedOrigin)
    }
}
