import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        EasyTODOSettings.registerDefaults()
        AppLogo.applyApplicationIcon()
        GlobalShortcutManager.shared.registerQuickAddShortcut()
        WindowManager.shared.applyActivationPolicy()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        GlobalShortcutManager.shared.unregisterQuickAddShortcut()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            WindowManager.shared.showMainWindow()
        }
        return true
    }
}
