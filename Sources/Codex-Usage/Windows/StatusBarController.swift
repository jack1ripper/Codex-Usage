import AppKit

@MainActor
final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private let windowController: FloatingWindowController
    private let service: UsageRefreshService

    init(windowController: FloatingWindowController, service: UsageRefreshService) {
        self.windowController = windowController
        self.service = service
        super.init()
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "C"
        item.button?.font = NSFont.systemFont(ofSize: 12, weight: .semibold)

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Ball", action: #selector(showBall), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Refresh", action: #selector(refresh), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        menu.items.forEach { $0.target = self }
        item.menu = menu

        statusItem = item
    }

    @objc private func showBall() {
        windowController.bringToFront()
    }

    @objc private func refresh() {
        Task { await service.refresh() }
    }

    @objc private func showSettings() {
        windowController.showSettings()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
