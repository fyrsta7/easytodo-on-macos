import AppKit
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

    func testRowHoverShowsOpaqueFullTitleAndRemovesCardOnExit() throws {
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
        titleView.update(title: title, isCompleted: false, font: .systemFont(ofSize: 13), isHovered: false, onDoubleClick: nil)
        XCTAssertFalse(preview.isVisible)
        XCTAssertTrue(window.childWindows?.isEmpty ?? true)
    }
}
