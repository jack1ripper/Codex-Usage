import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: FloatingWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let service = UsageRefreshService()
        let controller = FloatingWindowController(service: service)
        controller.show()
        windowController = controller
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        windowController?.close()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
