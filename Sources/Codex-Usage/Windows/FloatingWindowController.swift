import SwiftUI
import AppKit

@MainActor
final class FloatingWindowController: NSObject, NSWindowDelegate {
    private let service: UsageRefreshService
    private var window: NSPanel?
    private var settingsWindow: NSWindow?
    private var settingsWindowDelegate: SettingsWindowDelegate?

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
        if let window = window {
            window.orderFrontRegardless()
            return
        }

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
        panel.hidesOnDeactivate = false
        panel.delegate = self

        let contentView = FloatingBallView(
            service: service,
            onRefresh: { [weak service] in
                Task { await service?.refresh() }
            },
            onSettings: { [weak self] in
                self?.showSettings()
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

    /// Brings the floating panel to the front, recreating it if it was closed.
    func bringToFront() {
        show()
    }

    /// Triggers a manual refresh of the usage data.
    func refresh() {
        Task { await service.refresh() }
    }

    /// Closes the floating panel and stops the refresh service.
    func close() {
        window?.close()
    }

    // MARK: - Settings window

    func showSettings() {
        if let settingsWindow = settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            return
        }

        let delegate = SettingsWindowDelegate(controller: self)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.contentView = NSHostingView(rootView: SettingsView())
        window.center()
        window.delegate = delegate
        settingsWindow = window
        settingsWindowDelegate = delegate
        window.makeKeyAndOrderFront(nil)
    }

    fileprivate func settingsWindowDidClose() {
        settingsWindow = nil
        settingsWindowDelegate = nil
    }

    // MARK: - NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        guard let window = window,
              notification.object as? NSWindow == window else { return }
        savePosition(of: window)
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow,
              closingWindow == window else { return }
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

// MARK: - Settings window delegate

/// A dedicated delegate for the Settings window so that its lifecycle is
/// isolated from the main floating panel.
@MainActor
private final class SettingsWindowDelegate: NSObject, NSWindowDelegate {
    private weak var controller: FloatingWindowController?

    init(controller: FloatingWindowController) {
        self.controller = controller
        super.init()
    }

    func windowWillClose(_ notification: Notification) {
        controller?.settingsWindowDidClose()
    }
}
