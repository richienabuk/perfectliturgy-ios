import SwiftUI

nonisolated enum Radius {
    static let sm: CGFloat = 4
    static let md: CGFloat = 6
    static let lg: CGFloat = 8
    static let sheet: CGFloat = 18
}

nonisolated enum ControlMetrics {
    static let minimumHeight: CGFloat = 44
    static let pressScale: CGFloat = 0.97
    static let pressDuration: TimeInterval = 0.15
}

nonisolated enum InterfaceWeight: Sendable {
    case regular
    case medium
    case semibold
}

nonisolated enum AppFont {
    static let wordmarkSize: CGFloat = 13
    static let wordmarkTracking: CGFloat = wordmarkSize * 0.04
    static let headingTrackingFactor: CGFloat = -0.015
    static let eyebrowSize: CGFloat = 12
    static let eyebrowTracking: CGFloat = eyebrowSize * 0.16
    static let bodySize: CGFloat = 16
    static let bodyLeading: CGFloat = 1.625

    static func wordmark() -> Font {
        .custom("Cinzel-SemiBold", size: wordmarkSize)
    }

    static func heading(size: CGFloat, italic: Bool = false) -> Font {
        .custom(italic ? "CormorantGaramond-MediumItalic" : "CormorantGaramond-Medium", size: size)
    }

    static func title(size: CGFloat) -> Font {
        .custom("CormorantGaramond-SemiBold", size: size)
    }

    static func interface(size: CGFloat, weight: InterfaceWeight = .regular) -> Font {
        switch weight {
        case .regular:
            .custom("PlusJakartaSans-Regular", size: size)
        case .medium:
            .custom("PlusJakartaSans-Medium", size: size)
        case .semibold:
            .custom("PlusJakartaSans-SemiBold", size: size)
        }
    }

    static func body(size: CGFloat = bodySize) -> Font {
        interface(size: size)
    }

    static func eyebrow() -> Font {
        interface(size: eyebrowSize, weight: .semibold)
    }
}

/// Heading and body multipliers for reading text. Chrome, chips, and eyebrows stay at 1.
nonisolated struct ReadingScale: Equatable, Sendable {
    static let bounds = 0.8...1.4

    var headings: Double
    var body: Double

    init(headings: Double = 1, body: Double = 1) {
        self.headings = Self.clamp(headings)
        self.body = Self.clamp(body)
    }

    static func clamp(_ value: Double) -> Double {
        min(max(value, bounds.lowerBound), bounds.upperBound)
    }
}

nonisolated enum ReadingRole: Sendable {
    /// Part titles, such as a Mass part. Cormorant, heading slider.
    case partTitle
    /// Item titles inside a part. Cormorant, heading slider.
    case itemTitle
    /// Prayer text. Jakarta, body slider.
    case prayer
    /// Response text. Jakarta, body slider.
    case response

    var baseSize: CGFloat {
        switch self {
        case .partTitle: 32
        case .itemTitle: 26
        case .prayer, .response: AppFont.bodySize
        }
    }

    var usesHeadingScale: Bool {
        switch self {
        case .partTitle, .itemTitle: true
        case .prayer, .response: false
        }
    }

    /// Cormorant stays at or above 1.5rem. Jakarta has no floor.
    var fontFloor: CGFloat? {
        usesHeadingScale ? 24 : nil
    }
}

extension ReadingScale {
    func size(for role: ReadingRole) -> CGFloat {
        let factor = role.usesHeadingScale ? headings : body
        let scaled = role.baseSize * factor
        guard let floor = role.fontFloor else { return scaled }
        return max(floor, scaled)
    }
}

nonisolated struct ReadingScaleKey: EnvironmentKey {
    static let defaultValue = ReadingScale()
}

extension EnvironmentValues {
    var readingScale: ReadingScale {
        get { self[ReadingScaleKey.self] }
        set { self[ReadingScaleKey.self] = newValue }
    }
}
