import AppKit

@MainActor
final class WindowManager: NSObject, ObservableObject {
    static let shared = WindowManager()

    private var mainWindow: NSWindow?

    private override init() {
        super.init()
    }

    func configureMainWindow(_ window: NSWindow) {
        guard mainWindow !== window else {
            applyWindowSettings()
            return
        }

        mainWindow = window
        window.identifier = NSUserInterfaceItemIdentifier("easy-todo-main-window")
        window.title = "EasyTODO"
        window.minSize = NSSize(width: 280, height: 320)
        window.setContentSize(NSSize(width: 340, height: 480))
        window.isOpaque = false
        window.backgroundColor = .windowBackgroundColor
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        window.isMovableByWindowBackground = true
        window.styleMask.insert([.titled, .closable, .miniaturizable, .resizable])
        window.styleMask.remove(.fullSizeContentView)
        window.isReleasedWhenClosed = false
        configureNativeWindowControls(in: window)
        window.collectionBehavior.insert(.canJoinAllSpaces)
        window.collectionBehavior.insert(.fullScreenAuxiliary)

        applyWindowSettings()
    }

    private func configureNativeWindowControls(in window: NSWindow) {
        for type: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(type)?.isHidden = false
        }

        // Keep the task window available for reopening from the menu bar.
        let closeButton = window.standardWindowButton(.closeButton)
        closeButton?.target = self
        closeButton?.action = #selector(closeMainWindow)
    }

    func applyWindowSettings() {
        guard let window = mainWindow else { return }

        let defaults = UserDefaults.standard
        let alwaysOnTop = defaults.bool(forKey: EasyTODOSettings.alwaysOnTop)
        let transparency = defaults.double(forKey: EasyTODOSettings.transparency)

        window.level = alwaysOnTop ? .floating : .normal
        window.alphaValue = min(max(transparency, 0.50), 1.0)
    }

    func applyActivationPolicy() {
        let defaults = UserDefaults.standard
        let hideDockIcon = defaults.bool(forKey: EasyTODOSettings.hiddenDockIcon)
        let showMenuBar = defaults.bool(forKey: EasyTODOSettings.showMenuBar)

        NSApp.setActivationPolicy(hideDockIcon && showMenuBar ? .accessory : .regular)
    }

    func showMainWindow() {
        if let window = mainWindow {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }

            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func closeMainWindow() {
        mainWindow?.orderOut(nil)
    }

    func minimizeMainWindow() {
        mainWindow?.miniaturize(nil)
    }

    func zoomMainWindow() {
        mainWindow?.performZoom(nil)
    }
}
