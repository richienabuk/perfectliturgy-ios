import SwiftUI
import UIKit

/// How tall each fitted sheet was the last time it opened.
///
/// A sheet cannot be measured before it is on screen. Opening at the remembered height
/// means it does not open at a guess and then resize. The first open after install uses
/// the estimate. A text size change is corrected by the next measurement.
enum SheetHeights {
    private static func storageKey(_ key: String) -> String { "sheetHeight.\(key)" }

    static func remembered(_ key: String) -> CGFloat? {
        let value = UserDefaults.standard.double(forKey: storageKey(key))
        return value > 1 ? CGFloat(value) : nil
    }

    static func remember(_ height: CGFloat, for key: String) {
        UserDefaults.standard.set(Double(height), forKey: storageKey(key))
    }
}

extension View {
    /// Sizes a sheet to its content. `key` names the sheet so its height can be remembered.
    /// Use a different key when the content changes shape, such as a different row count.
    func fittedBottomSheet(key: String, estimate: CGFloat) -> some View {
        modifier(FittedBottomSheet(key: key, estimate: estimate))
    }
}

struct FittedBottomSheet: ViewModifier {
    let key: String
    @State private var height: CGFloat
    @Environment(\.palette) private var palette

    init(key: String, estimate: CGFloat) {
        self.key = key
        _height = State(initialValue: SheetHeights.remembered(key) ?? estimate)
    }

    func body(content: Content) -> some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            // Runs when the measured height changes, not on every pass of `body`.
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { measured in
                // The sheet's own bottom inset flips once the detent grows to fit it.
                // Adding that inset back into the detent makes the height chase itself,
                // so it is read here, once per measurement, and not from `body`.
                let next = measured + InterfaceAnchor.window.safeAreaInsets.bottom
                guard next > 1, abs(height - next) > 1 else { return }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    height = next
                }
                SheetHeights.remember(next, for: key)
            }
            .presentationDetents([.height(max(height, 1))])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(Radius.sheet)
            .presentationBackground(palette.background.color)
    }
}
