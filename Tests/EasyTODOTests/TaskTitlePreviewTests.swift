import AppKit
import XCTest
@testable import EasyTODO

@MainActor
final class TaskTitlePreviewTests: XCTestCase {
    func testShortChineseTitleStillPreviewsWhenClipped() {
        let title = "这条中文待办需要完整显示"
        XCTAssertLessThan(title.count, 20)
        XCTAssertTrue(TaskTitlePreviewLayout.isTruncated(title, font: .systemFont(ofSize: 13), availableWidth: 100))
    }

    func testTruncationFollowsAvailableWidthAfterResizing() {
        let title = "WWWWWWWWWWWW"
        let font = NSFont.systemFont(ofSize: 15)
        let fullWidth = (title as NSString).size(withAttributes: [.font: font]).width
        XCTAssertTrue(TaskTitlePreviewLayout.isTruncated(title, font: font, availableWidth: fullWidth / 2))
        XCTAssertFalse(TaskTitlePreviewLayout.isTruncated(title, font: font, availableWidth: fullWidth + 4))
    }

    func testMultilinePreviewIncludesMoreThanEightLines() {
        let title = (1...12).map { "Task line \($0)" }.joined(separator: "\n")
        XCTAssertTrue(TaskTitlePreviewLayout.isTruncated(title, font: .systemFont(ofSize: 13), availableWidth: 1000))
        let size = TaskTitlePreviewLayout.size(for: title, screenWidth: 1440)
        let font = TaskTitlePreviewLayout.font
        let eightLines = 8 * (font.ascender - font.descender + font.leading)
        XCTAssertGreaterThan(size.height - 2 * TaskTitlePreviewLayout.verticalPadding, eightLines)
    }

    func testMenuBarPreviewFitsBelowTaskNearTopRightOfScreen() {
        let screen = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let source = NSRect(x: 1320, y: 850, width: 100, height: 22)
        let frame = TaskTitlePreviewLayout.frame(size: NSSize(width: 424, height: 96), source: source, screen: screen)
        XCTAssertTrue(screen.insetBy(dx: 8, dy: 8).contains(frame))
        XCTAssertLessThan(frame.maxY, source.minY)
    }

    func testPreviewMovesAboveTaskOnLowerSecondaryDisplay() {
        let screen = NSRect(x: -1440, y: -900, width: 1440, height: 900)
        let source = NSRect(x: -1400, y: -870, width: 200, height: 22)
        let frame = TaskTitlePreviewLayout.frame(size: NSSize(width: 424, height: 96), source: source, screen: screen)
        XCTAssertTrue(screen.insetBy(dx: 8, dy: 8).contains(frame))
        XCTAssertGreaterThan(frame.minY, source.maxY)
    }
}
