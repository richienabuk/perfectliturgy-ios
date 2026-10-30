import SwiftUI

/// Renders verse spans, merging consecutive quote segments into one block with a leading rule.
struct ReadingBlocksView: View {
    var verses: [VerseText]
    var incipit: String?

    @Environment(\.palette) private var palette
    @Environment(\.readingScale) private var readingScale

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                switch block {
                case .plain(let text):
                    ReadingText(text: prefix(text, at: index), role: .prayer)
                case .quote(let text):
                    HStack(alignment: .top, spacing: 10) {
                        Rectangle()
                            .fill(palette.emphasis.color)
                            .frame(width: 3)
                            .accessibilityHidden(true)
                        ReadingText(text: prefix(text, at: index), role: .prayer)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(prefix(text, at: index))
                }
            }
        }
    }

    private func prefix(_ text: String, at index: Int) -> String {
        guard index == 0, let incipit, !incipit.isEmpty else { return text }
        if text.isEmpty { return incipit }
        return "\(incipit) \(text)"
    }

    private var blocks: [Block] {
        var result: [Block] = []
        for verse in verses {
            for span in verse.spans {
                let isQuote = span.style == "quote"
                if isQuote, case .quote(let existing) = result.last {
                    result[result.count - 1] = .quote(existing + span.text)
                } else if !isQuote, case .plain(let existing) = result.last {
                    result[result.count - 1] = .plain(existing + span.text)
                } else if isQuote {
                    result.append(.quote(span.text))
                } else {
                    result.append(.plain(span.text))
                }
            }
        }
        return result
    }

    private enum Block {
        case plain(String)
        case quote(String)
    }
}
