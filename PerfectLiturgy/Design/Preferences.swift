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

/// Session appearance and the reading scale. Persistence arrives with Settings.
@Observable
final class DesignPreferences {
    var appearance: AppearanceMode = .system
    var readingScale = ReadingScale()
}
