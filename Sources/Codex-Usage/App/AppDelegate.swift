import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: FloatingWindowController?
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let service = UsageRefreshService()
        let controller = FloatingWindowController(service: service)
        controller.show()
        windowController = controller

        let statusBar = StatusBarController(windowController: controller, service: service)
        statusBar.install()
        statusBarController = statusBar
    }

    func applicationWillTerminate(_ notification: Notification) {
        windowController?.close()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        windowController?.bringToFront()
        return true
    }
}
