import SwiftUI

/// One hymn in the list. It takes plain values and no environment, so SwiftUI can skip
/// a row whose values did not change. The closures are not compared.
struct HymnListRow: View, Equatable {
    var item: HymnListModel.Row
    var isSaved: Bool
    var isSelected: Bool
    var splitsColumns: Bool
    var palette: Palette
    var onOpen: (String) -> Void
    var onToggleSaved: (String) -> Void

    nonisolated static func == (lhs: HymnListRow, rhs: HymnListRow) -> Bool {
        lhs.item == rhs.item
            && lhs.isSaved == rhs.isSaved
            && lhs.isSelected == rhs.isSelected
            && lhs.splitsColumns == rhs.splitsColumns
            && lhs.palette == rhs.palette
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                onOpen(item.id)
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    if splitsColumns {
                        musicMark
                        titleBlock(lineLimit: 1)
                        Spacer(minLength: 8)
                        Text(String(item.hymnNumber))
                            .font(AppFont.interface(size: 14))
                            .foregroundStyle(palette.mutedForeground.color)
                    } else {
                        numberTile
                        titleBlock(lineLimit: 2)
                        Spacer(minLength: 4)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(item.hymnNumber), \(item.title)")
            bookmarkButton
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.mutedForeground.color)
        }
        .padding(.horizontal, splitsColumns ? 10 : 0)
        .padding(.vertical, splitsColumns ? 10 : 12)
        .background(isSelected ? palette.card.color : Color.clear, in: RoundedRectangle(cornerRadius: Radius.lg))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: Radius.lg)
                    .strokeBorder(palette.border.color, lineWidth: 1)
            }
        }
        .overlay(alignment: .bottom) {
            if !splitsColumns {
                Rectangle()
                    .fill(palette.border.color)
                    .frame(height: 1)
            }
        }
    }

    private func titleBlock(lineLimit: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(item.title)
                .font(AppFont.interface(size: 16, weight: .semibold))
                .foregroundStyle(palette.foreground.color)
                .multilineTextAlignment(.leading)
            Text(item.line)
                .font(AppFont.interface(size: 13))
                .foregroundStyle(palette.mutedForeground.color)
                .lineLimit(lineLimit)
        }
    }

    private var numberTile: some View {
        Text(String(item.hymnNumber))
            .font(AppFont.title(size: 22))
            .foregroundStyle(palette.emphasis.color)
            .minimumScaleFactor(0.55)
            .lineLimit(1)
            .frame(width: 52, height: 52)
            .background(palette.card.color, in: RoundedRectangle(cornerRadius: Radius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.lg)
                    .strokeBorder(palette.border.color, lineWidth: 1)
            }
    }

    private var musicMark: some View {
        Image(systemName: "music.note")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(palette.emphasis.color)
            .frame(width: 36, height: 36)
            .background(palette.card.color, in: RoundedRectangle(cornerRadius: Radius.md))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.md)
                    .strokeBorder(palette.border.color, lineWidth: 1)
            }
    }

    private var bookmarkButton: some View {
        Button {
            onToggleSaved(item.id)
        } label: {
            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                .font(.system(size: 16))
                .foregroundStyle(isSaved ? palette.emphasis.color : palette.foreground.color)
                .frame(width: ControlMetrics.minimumHeight, height: ControlMetrics.minimumHeight)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(isSaved ? "Remove saved hymn" : "Save hymn")
    }
}
