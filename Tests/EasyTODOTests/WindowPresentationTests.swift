import AppKit
import SwiftUI
import XCTest
@testable import EasyTODO

@MainActor
final class WindowPresentationTests: XCTestCase {
    func testNativeCloseButtonHidesWindowAndMenuBarCanReopenIt() throws {
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(x: -10000, y: -10000, width: 340, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        defer { window.orderOut(nil) }
        WindowManager.shared.configureMainWindow(window)
        window.orderFront(nil)
        XCTAssertTrue(window.isVisible)
        let close = try XCTUnwrap(window.standardWindowButton(.closeButton))
        XCTAssertFalse(close.isHidden)
        close.performClick(nil)
        XCTAssertFalse(window.isVisible)
        WindowManager.shared.showMainWindow()
        XCTAssertTrue(window.isVisible)
        XCTAssertEqual(window.identifier?.rawValue, "easy-todo-main-window")
    }

    func testNativeMinimizeButtonMinimizesAndMainWindowCanBeRestored() throws {
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(x: -10000, y: -10000, width: 340, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        defer { window.orderOut(nil) }
        WindowManager.shared.configureMainWindow(window)
        window.orderFront(nil)
        let minimize = try XCTUnwrap(window.standardWindowButton(.miniaturizeButton))
        XCTAssertFalse(minimize.isHidden)
        XCTAssertTrue(minimize.isEnabled)
        minimize.performClick(nil)
        let deadline = Date().addingTimeInterval(2)
        while !window.isMiniaturized && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
        XCTAssertTrue(window.isMiniaturized)
        WindowManager.shared.showMainWindow()
        XCTAssertFalse(window.isMiniaturized)
        XCTAssertTrue(window.isVisible)
    }

    func testRowHoverShowsOpaqueCardsForLongAndShortTitlesAndHidesOnExit() throws {
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(x: -10000, y: -10000, width: 260, height: 200),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        defer { window.orderOut(nil) }
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 200))
        let titleView = FloatingTaskTitleView(frame: NSRect(x: 20, y: 100, width: 100, height: 24))
        host.addSubview(titleView)
        window.contentView = host
        window.orderFront(nil)
        let title = "这条中文待办需要完整显示，包括最后一段文字。"
        titleView.update(title: title, isCompleted: false, font: .systemFont(ofSize: 13), isHovered: true, onDoubleClick: nil)
        let preview = try XCTUnwrap(window.childWindows?.first)
        XCTAssertTrue(preview.isVisible)
        XCTAssertEqual(preview.alphaValue, 1)
        XCTAssertTrue(preview.ignoresMouseEvents)
        let card = try XCTUnwrap(preview.contentView as? NSBox)
        XCTAssertFalse(card.isTransparent)
        XCTAssertEqual(card.fillColor.usingColorSpace(.deviceRGB)?.alphaComponent, 1)
        let label = try XCTUnwrap(card.contentView?.subviews.compactMap { $0 as? NSTextField }.first)
        XCTAssertEqual(label.stringValue, title)
        XCTAssertEqual(label.maximumNumberOfLines, 0)
        let largeFont = NSFont.systemFont(ofSize: TextSize.scaled(13, by: 1.6))
        titleView.update(title: title, isCompleted: false, font: largeFont, isHovered: true, onDoubleClick: nil)
        let enlargedPreview = try XCTUnwrap(window.childWindows?.first)
        let enlargedCard = try XCTUnwrap(enlargedPreview.contentView as? NSBox)
        let enlargedLabel = try XCTUnwrap(enlargedCard.contentView?.subviews.compactMap { $0 as? NSTextField }.first)
        XCTAssertFalse(preview.isVisible)
        XCTAssertEqual(enlargedLabel.font?.pointSize, largeFont.pointSize)
        XCTAssertGreaterThan(enlargedPreview.frame.height, preview.frame.height)
        XCTAssertEqual(window.childWindows?.count, 1)
        titleView.update(title: title, isCompleted: false, font: largeFont, isHovered: false, onDoubleClick: nil)
        XCTAssertFalse(enlargedPreview.isVisible)
        XCTAssertFalse(preview.isVisible)
        XCTAssertTrue(window.childWindows?.isEmpty ?? true)

        let shortTitle = "喝水"
        XCTAssertLessThan((shortTitle as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 13)]).width, titleView.bounds.width)
        titleView.update(title: shortTitle, isCompleted: false, font: .systemFont(ofSize: 13), isHovered: true, onDoubleClick: nil)
        let shortPreview = try XCTUnwrap(window.childWindows?.first)
        let shortCard = try XCTUnwrap(shortPreview.contentView as? NSBox)
        let shortLabel = try XCTUnwrap(shortCard.contentView?.subviews.compactMap { $0 as? NSTextField }.first)
        XCTAssertTrue(shortPreview.isVisible)
        XCTAssertEqual(shortLabel.stringValue, shortTitle)
        XCTAssertEqual(shortCard.fillColor, card.fillColor)
        XCTAssertEqual(shortCard.cornerRadius, card.cornerRadius)
        XCTAssertFalse(shortCard.isTransparent)
        titleView.update(title: shortTitle, isCompleted: false, font: .systemFont(ofSize: 13), isHovered: false, onDoubleClick: nil)
        XCTAssertFalse(shortPreview.isVisible)
        XCTAssertTrue(window.childWindows?.isEmpty ?? true)
    }

    func testFullyVisibleShortTasksPreviewInMainRowAndWidget() throws {
        _ = NSApplication.shared
        let container = try PersistenceController.modelContainer(inMemory: true)
        let task = TodoTask(title: "喝水")
        container.mainContext.insert(task)
        try container.mainContext.save()
        let suite = "EasyTODOTests.ShortTitleHover.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        EasyTODOSettings.registerDefaults(in: defaults)

        // Exercise the actual callers so a menu-only fix cannot pass this regression.
        let views = [
            AnyView(TaskRow(task: task, onUpdate: {}, onCompletionChanged: { _, _, _ in }, onDelete: {}).padding()),
            AnyView(WidgetTodoView())
        ]
        for view in views {
            let window = NSWindow(
                contentRect: NSRect(x: -10000, y: -10000, width: 340, height: 312),
                styleMask: [.borderless], backing: .buffered, defer: false
            )
            defer { window.orderOut(nil) }
            let host = NSHostingView(rootView: view.modelContainer(container).defaultAppStorage(defaults))
            window.contentView = host
            window.orderFront(nil)
            let deadline = Date().addingTimeInterval(1)
            while titleViews(in: host).isEmpty && Date() < deadline {
                host.layoutSubtreeIfNeeded()
                RunLoop.current.run(until: Date().addingTimeInterval(0.01))
            }
            host.layoutSubtreeIfNeeded()
            let titleView = try XCTUnwrap(titleViews(in: host).first)
            let titleLabel = try XCTUnwrap(titleView.subviews.compactMap { $0 as? NSTextField }.first)
            XCTAssertGreaterThan(titleView.bounds.width, titleLabel.attributedStringValue.size().width)
            titleView.updateTrackingAreas()
            XCTAssertFalse(titleView.trackingAreas.isEmpty)

            let entered = try XCTUnwrap(NSEvent.enterExitEvent(
                with: .mouseEntered, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: window.windowNumber, context: nil,
                eventNumber: 0, trackingNumber: 0, userData: nil
            ))
            titleView.mouseEntered(with: entered)
            let preview = try XCTUnwrap(window.childWindows?.first)
            let card = try XCTUnwrap(preview.contentView as? NSBox)
            let label = try XCTUnwrap(card.contentView?.subviews.compactMap { $0 as? NSTextField }.first)
            XCTAssertTrue(preview.isVisible)
            XCTAssertFalse(card.isTransparent)
            XCTAssertEqual(label.stringValue, task.title)

            let exited = try XCTUnwrap(NSEvent.enterExitEvent(
                with: .mouseExited, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: window.windowNumber, context: nil,
                eventNumber: 0, trackingNumber: 0, userData: nil
            ))
            titleView.mouseExited(with: exited)
            XCTAssertFalse(preview.isVisible)
            XCTAssertTrue(window.childWindows?.isEmpty ?? true)
        }
    }

    private func titleViews(in view: NSView) -> [FloatingTaskTitleView] {
        if let titleView = view as? FloatingTaskTitleView { return [titleView] }
        return view.subviews.flatMap { titleViews(in: $0) }
    }
}
