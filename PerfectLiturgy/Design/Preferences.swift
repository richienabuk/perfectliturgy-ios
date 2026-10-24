import SwiftUI

nonisolated enum AppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Appearance and reading scales. Stored in UserDefaults so they survive a relaunch.
@Observable
final class DesignPreferences {
    private let defaults: UserDefaults

    private(set) var appearance: AppearanceMode
    private(set) var headingScale: Double
    private(set) var bodyScale: Double
    private(set) var autoSync: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedMode = defaults.string(forKey: Key.appearance) ?? ""
        appearance = AppearanceMode(rawValue: storedMode) ?? .system
        headingScale = ReadingScale.clamp(defaults.object(forKey: Key.headingScale) as? Double ?? 1)
        bodyScale = ReadingScale.clamp(defaults.object(forKey: Key.bodyScale) as? Double ?? 1)
        if defaults.object(forKey: Key.autoSync) == nil {
            autoSync = true
        } else {
            autoSync = defaults.bool(forKey: Key.autoSync)
        }
    }

    var readingScale: ReadingScale {
        ReadingScale(headings: headingScale, body: bodyScale)
    }

    func setAppearance(_ mode: AppearanceMode) {
        appearance = mode
        defaults.set(mode.rawValue, forKey: Key.appearance)
    }

    func setHeadingScale(_ value: Double) {
        headingScale = ReadingScale.clamp(value)
        defaults.set(headingScale, forKey: Key.headingScale)
    }

    func setBodyScale(_ value: Double) {
        bodyScale = ReadingScale.clamp(value)
        defaults.set(bodyScale, forKey: Key.bodyScale)
    }

    func setAutoSync(_ enabled: Bool) {
        autoSync = enabled
        defaults.set(enabled, forKey: Key.autoSync)
    }

    private enum Key {
        static let appearance = "appearance"
        static let headingScale = "headingScale"
        static let bodyScale = "bodyScale"
        static let autoSync = "autoSync"
    }
}
