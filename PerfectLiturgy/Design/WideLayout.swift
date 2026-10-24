import SwiftUI

nonisolated enum LayoutSpan {
    static let wideWidth: CGFloat = 840
    static let wideHeight: CGFloat = 600

    static func isWide(width: CGFloat, height: CGFloat) -> Bool {
        width >= wideWidth && height >= wideHeight
    }
}

nonisolated struct WideLayoutKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isWideLayout: Bool {
        get { self[WideLayoutKey.self] }
        set { self[WideLayoutKey.self] = newValue }
    }
}

extension View {
    func wideLayout() -> some View {
        modifier(WideLayoutModifier())
    }
}

private struct WideLayoutPreference: PreferenceKey {
    static let defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

private struct WideLayoutModifier: ViewModifier {
    @State private var isWide = false

    func body(content: Content) -> some View {
        content
            .environment(\.isWideLayout, isWide)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: WideLayoutPreference.self,
                        value: LayoutSpan.isWide(width: proxy.size.width, height: proxy.size.height)
                    )
                }
            }
            .onPreferenceChange(WideLayoutPreference.self) { isWide = $0 }
    }
}
