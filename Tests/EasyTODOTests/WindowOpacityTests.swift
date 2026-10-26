import AppKit
import XCTest
@testable import EasyTODO

@MainActor
final class WindowOpacityTests: XCTestCase {
    func testIntermediateOpacityIncludingNinetyPercentSurvivesRelaunch() throws {
        let suite = "EasyTODOTests.Opacity.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(0.42, forKey: EasyTODOSettings.widgetTransparency)
        defaults.set(1.25, forKey: EasyTODOSettings.textScale)

        for value in [0.5, 0.67, 0.9, 1.0] {
            defaults.set(value, forKey: EasyTODOSettings.transparency)
            let reopenedDefaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            EasyTODOSettings.registerDefaults(in: reopenedDefaults)
            XCTAssertEqual(reopenedDefaults.double(forKey: EasyTODOSettings.transparency), value)
            XCTAssertEqual(reopenedDefaults.double(forKey: EasyTODOSettings.widgetTransparency), 0.42)
            XCTAssertEqual(reopenedDefaults.double(forKey: EasyTODOSettings.textScale), 1.25)
        }
    }

    func testWindowAppliesIntermediateOpacityWithoutReopening() throws {
        _ = NSApplication.shared
        let suite = "EasyTODOTests.Opacity.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        EasyTODOSettings.registerDefaults(in: defaults)
        let window = NSWindow(
            contentRect: NSRect(x: -10000, y: -10000, width: 340, height: 480),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        defer { window.orderOut(nil) }
        WindowManager.shared.configureMainWindow(window)
        window.orderFront(nil)

        for value in [0.67, 0.9, 0.5, 1.0] {
            defaults.set(value, forKey: EasyTODOSettings.transparency)
            WindowManager.shared.applyWindowSettings(in: defaults)
            XCTAssertEqual(window.alphaValue, value, accuracy: 0.001)
            XCTAssertTrue(window.isVisible)
        }
    }
}
