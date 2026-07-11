import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var service: UsageRefreshService?
    private var windowController: FloatingWindowController?
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent macOS from terminating the LSUIElement app when it has no
        // visible windows (e.g. after the settings window is hidden).
        ProcessInfo.processInfo.disableSuddenTermination()
        ProcessInfo.processInfo.disableAutomaticTermination("menu bar")

        let service = UsageRefreshService()
        let controller = FloatingWindowController(service: service)
        self.service = service
        windowController = controller

        let statusBar = StatusBarController(windowController: controller, service: service)
        statusBar.install()
        statusBarController = statusBar

        service.start()
        controller.applyVisibilityPreference()
    }

    func applicationWillTerminate(_ notification: Notification) {
        windowController?.close()
        service?.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApplication.shared.activate(ignoringOtherApps: true)

        if FloatingPanelPreference.isEnabled() {
            windowController?.bringToFront()
        } else {
            windowController?.showSettings()
        }
        return true
    }
}
