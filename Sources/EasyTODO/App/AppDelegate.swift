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
        // Reuse the main window even if Settings or the widget is already visible.
        // Only allow default scene creation before a main window has been registered.
        return !WindowManager.shared.showMainWindow()
    }
}
