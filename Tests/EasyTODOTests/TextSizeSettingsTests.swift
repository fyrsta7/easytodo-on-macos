import Foundation
import XCTest
@testable import EasyTODO

final class TextSizeSettingsTests: XCTestCase {
    func testTextSizePersistsWhenDefaultsAreRegisteredAgain() throws {
        let suite = "EasyTODOTests.TextSize.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        EasyTODOSettings.registerDefaults(in: defaults)
        XCTAssertEqual(defaults.double(forKey: EasyTODOSettings.textScale), 1)
        defaults.set(1.35, forKey: EasyTODOSettings.textScale)

        let reopenedDefaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        EasyTODOSettings.registerDefaults(in: reopenedDefaults)
        XCTAssertEqual(reopenedDefaults.double(forKey: EasyTODOSettings.textScale), 1.35)
    }

    func testInvalidSavedSizesAreRepairedWithoutAffectingOtherSettings() throws {
        let suite = "EasyTODOTests.TextSize.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(0.5, forKey: EasyTODOSettings.transparency)

        for (saved, expected) in [(-1.0, 0.85), (5.0, 1.6), (Double.nan, 1.0), (Double.infinity, 1.0)] {
            defaults.set(saved, forKey: EasyTODOSettings.textScale)
            EasyTODOSettings.registerDefaults(in: defaults)
            XCTAssertEqual(defaults.double(forKey: EasyTODOSettings.textScale), expected)
            XCTAssertEqual(defaults.double(forKey: EasyTODOSettings.transparency), 0.5)
        }
    }
}
