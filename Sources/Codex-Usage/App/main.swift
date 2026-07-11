import AppKit

autoreleasepool {
    // If another instance of this app is already running, activate it and
    // terminate the current process so the user never ends up with two copies.
    let bundleID = Bundle.main.bundleIdentifier ?? "com.codexusage.Codex-Usage"
    let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    let currentPID = NSRunningApplication.current.processIdentifier
    if let existingApp = runningApps.first(where: { $0.processIdentifier != currentPID }), !existingApp.isTerminated {
        existingApp.activate(options: .activateAllWindows)
        exit(0)
    }

    let app = NSApplication.shared
    NSApp.setActivationPolicy(.accessory)
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
