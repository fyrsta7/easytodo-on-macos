import Foundation

enum EasyTODOSettings {
    static let launchAtLogin = "launchAtLogin"
    static let alwaysOnTop = "alwaysOnTop"
    static let showMenuBar = "showMenuBar"
    static let hiddenDockIcon = "hiddenDockIcon"
    static let transparency = "transparency"
    static let widgetTransparency = "widgetTransparency"
    static let theme = "theme"
    static let textScale = "textScale"

    static func registerDefaults(in defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            launchAtLogin: false,
            alwaysOnTop: true,
            showMenuBar: true,
            hiddenDockIcon: false,
            transparency: 0.80,
            widgetTransparency: 0.80,
            theme: ThemeOption.light.rawValue,
            textScale: TextSize.defaultScale
        ])

        let savedTextScale = defaults.double(forKey: textScale)
        let validTextScale = TextSize.normalized(savedTextScale)
        if savedTextScale != validTextScale {
            defaults.set(validTextScale, forKey: textScale)
        }

        if abs(defaults.double(forKey: transparency) - 0.90) < 0.001 {
            defaults.set(0.80, forKey: transparency)
        }

        if ThemeOption(rawValue: defaults.string(forKey: theme) ?? "") == nil {
            defaults.set(ThemeOption.light.rawValue, forKey: theme)
        }
    }
}

enum TextSize {
    static let defaultScale = 1.0
    static let range = 0.85...1.60

    static func normalized(_ scale: Double) -> Double {
        guard scale.isFinite else { return defaultScale }
        return min(max(scale, range.lowerBound), range.upperBound)
    }

    static var currentScale: Double {
        normalized(UserDefaults.standard.object(forKey: EasyTODOSettings.textScale) as? Double ?? defaultScale)
    }

    static func scaled(_ size: CGFloat, by scale: Double) -> CGFloat {
        size * normalized(scale)
    }

    static func rowHeight(baseFontSize: CGFloat, scale: Double) -> CGFloat {
        max(22, ceil(scaled(baseFontSize, by: scale) * 1.5))
    }

    // Keep compact panels usable at smaller sizes and give enlarged text more room.
    static func panelDimension(_ size: CGFloat, scale: Double) -> CGFloat {
        ceil(size * max(1, normalized(scale)))
    }

    static func widgetSize(scale: Double) -> CGSize {
        CGSize(width: panelDimension(236, scale: scale), height: panelDimension(312, scale: scale))
    }
}

enum ThemeOption: String, CaseIterable, Identifiable {
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light:
            "Light"
        case .dark:
            "Dark"
        }
    }
}
