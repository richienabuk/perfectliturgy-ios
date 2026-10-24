import SwiftUI

nonisolated enum LayoutSpan {
    static let wideWidth: CGFloat = 840
    static let wideHeight: CGFloat = 600
    /// iPad Air 13" landscape is 1366pt. A third column starts only past that.
    static let columnSplitWidth: CGFloat = 1400

    static func isWide(width: CGFloat, height: CGFloat) -> Bool {
        width >= wideWidth && height >= wideHeight
    }

    static func splitsColumns(width: CGFloat, height: CGFloat) -> Bool {
        isWide(width: width, height: height) && width >= columnSplitWidth
    }
}

nonisolated struct WideLayoutKey: EnvironmentKey {
    static let defaultValue = false
}

nonisolated struct SplitsColumnsKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isWideLayout: Bool {
        get { self[WideLayoutKey.self] }
        set { self[WideLayoutKey.self] = newValue }
    }

    /// Sidebar, list, and detail. Tablets stay at sidebar plus one column.
    var splitsColumns: Bool {
        get { self[SplitsColumnsKey.self] }
        set { self[SplitsColumnsKey.self] = newValue }
    }
}

extension View {
    func wideLayout() -> some View {
        modifier(WideLayoutModifier())
    }
}

private struct WideLayoutPreference: PreferenceKey {
    static let defaultValue = CGSize.zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

private struct WideLayoutModifier: ViewModifier {
    @State private var isWide = false
    @State private var splitsColumns = false

    func body(content: Content) -> some View {
        content
            .environment(\.isWideLayout, isWide)
            .environment(\.splitsColumns, splitsColumns)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: WideLayoutPreference.self,
                        value: proxy.size
                    )
                }
            }
            .onPreferenceChange(WideLayoutPreference.self) { size in
                isWide = LayoutSpan.isWide(width: size.width, height: size.height)
                splitsColumns = LayoutSpan.splitsColumns(width: size.width, height: size.height)
            }
    }
}
