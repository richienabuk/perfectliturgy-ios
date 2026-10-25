import SwiftUI

/// The one language control. It shows the language in use and opens `LanguageSheet`.
/// Full width suits a screen that scrolls. A compact button sits beside other controls.
struct LanguageButton: View {
    let title: String
    var accessibilityLabel: String
    var fillsWidth = true
    let action: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: fillsWidth ? 12 : 8) {
                Image(systemName: "character.book.closed")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.emphasis.color)
                    .frame(width: 24, height: 24)
                Text(title)
                    .font(AppFont.interface(size: 15, weight: .semibold))
                    .foregroundStyle(palette.foreground.color)
                    .lineLimit(1)
                    .frame(maxWidth: fillsWidth ? .infinity : Self.compactMaxWidth, alignment: .leading)
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.emphasis.color)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: ControlMetrics.minimumHeight, alignment: .leading)
            .background(palette.card.color, in: RoundedRectangle(cornerRadius: Radius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.lg)
                    .strokeBorder(palette.border.color, lineWidth: 1)
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        .fixedSize(horizontal: !fillsWidth, vertical: false)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(title)
    }

    /// A long name is cut here so it cannot push the other controls off the row.
    private static let compactMaxWidth: CGFloat = 220
}

/// Lists the languages a pack type has on this device, and nothing else.
/// Only Hymns passes `offersAll`. Closing comes first, then the choice is applied,
/// so the screen behind the sheet changes after the sheet is gone.
struct LanguageSheet: View {
    var title: String
    var languages: [PackLanguage]
    /// The code in use. Nil with `offersAll` means every language.
    var selected: String?
    var offersAll = false
    var onSelect: (String?) -> Void
    var onDownload: () -> Void

    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Text("Choose a language on this device.")
                .font(AppFont.interface(size: 16))
                .foregroundStyle(palette.mutedForeground.color)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            VStack(alignment: .leading, spacing: 4) {
                if offersAll {
                    choiceRow(title: "All languages", subtitle: nil, isSelected: selected == nil) {
                        choose(nil)
                    }
                }
                ForEach(languages) { language in
                    choiceRow(
                        title: language.name,
                        subtitle: language.packName == language.name ? nil : language.packName,
                        isSelected: language.code == selected
                    ) {
                        choose(language.code)
                    }
                }
                downloadRow
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.background.color)
        // One height per row count, so a list of three languages is not sized as a list of one.
        .fittedBottomSheet(key: "language.\(offersAll ? "all" : "one").\(languages.count)", estimate: 300)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(AppFont.heading(size: 32))
                .foregroundStyle(palette.foreground.color)
                .tracking(32 * AppFont.headingTrackingFactor)
            Spacer(minLength: 8)
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.foreground.color)
                    .frame(width: ControlMetrics.minimumHeight, height: ControlMetrics.minimumHeight)
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var downloadRow: some View {
        Button {
            dismiss()
            onDownload()
        } label: {
            HStack(spacing: 8) {
                Text("Download more languages")
                    .font(AppFont.interface(size: 17, weight: .semibold))
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(palette.foreground.color)
            .frame(maxWidth: .infinity, minHeight: ControlMetrics.minimumHeight, alignment: .leading)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Download more languages")
    }

    private func choose(_ code: String?) {
        dismiss()
        onSelect(code)
    }

    private func choiceRow(title: String, subtitle: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppFont.interface(size: 17, weight: .semibold))
                        .foregroundStyle(palette.foreground.color)
                    if let subtitle {
                        Text(subtitle)
                            .font(AppFont.interface(size: 15))
                            .foregroundStyle(palette.mutedForeground.color)
                    }
                }
                Spacer(minLength: 8)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(palette.primaryForeground.color)
                        .frame(width: 28, height: 28)
                        .background(palette.primary.color, in: Circle())
                }
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, minHeight: ControlMetrics.minimumHeight, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
