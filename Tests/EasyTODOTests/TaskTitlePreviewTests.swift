import AppKit
import XCTest
@testable import EasyTODO

@MainActor
final class TaskTitlePreviewTests: XCTestCase {
    func testLargerPreviewUsesItsActualFontForWrappingAndHeight() {
        let title = String(repeating: "完整显示放大后的待办文字。", count: 8)
        let normalFont = NSFont.systemFont(ofSize: 13, weight: .medium)
        let largeFont = NSFont.systemFont(ofSize: TextSize.scaled(13, by: 1.6), weight: .medium)
        let normalSize = TaskTitlePreviewLayout.size(for: title, screenWidth: 1440, font: normalFont)
        let largeSize = TaskTitlePreviewLayout.size(for: title, screenWidth: 1440, font: largeFont)
        XCTAssertGreaterThan(largeSize.height, normalSize.height)

        let label = NSTextField(wrappingLabelWithString: title)
        label.font = largeFont
        label.lineBreakMode = .byCharWrapping
        label.maximumNumberOfLines = 0
        let contentSize = NSSize(
            width: largeSize.width - 2 * TaskTitlePreviewLayout.horizontalPadding,
            height: largeSize.height - 2 * TaskTitlePreviewLayout.verticalPadding
        )
        let neededSize = label.cell!.cellSize(forBounds: NSRect(origin: .zero, size: contentSize))
        XCTAssertLessThanOrEqual(neededSize.height, contentSize.height)
    }

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
