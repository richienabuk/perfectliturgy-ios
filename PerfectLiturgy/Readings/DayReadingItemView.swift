import SwiftUI

/// One resolved reading, psalm, or acclamation on the Readings screen.
struct DayReadingItemView: View {
    var item: ReadingItem
    var formIndex: Int
    var onSelectForm: (Int) -> Void
    var language: String
    var seasonKey: String
    var bibleLanguageNote: String?

    @Environment(ReadingsPreferences.self) private var readings
    @Environment(\.palette) private var palette

    private var form: ReadingForm {
        let index = min(max(formIndex, 0), max(item.forms.count - 1, 0))
        return item.forms[index]
    }

    private var phraseIndex: Int {
        let phrases = item.acclamationPhrases
        guard phrases.count > 1 else { return 0 }
        if let chosen = readings.acclamationPhrase(language: language, season: seasonKey),
           let index = phrases.firstIndex(of: chosen) {
            return index
        }
        return min(item.selectedAcclamationIndex, phrases.count - 1)
    }

    private var selectedPhrase: String? {
        guard !item.acclamationPhrases.isEmpty else { return nil }
        return item.acclamationPhrases[phraseIndex]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.label.uppercased())
                .font(AppFont.interface(size: 12, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(palette.emphasis.color)

            if item.forms.count > 1 {
                alternativesMenu
            }

            // Acclamation is phrase + verse only. No theme, book title, or gospel incipit.
            if item.slot != "acclamation" {
                if let theme = form.theme, !theme.isEmpty {
                    Text(theme)
                        .font(AppFont.interface(size: 15))
                        .foregroundStyle(palette.mutedForeground.color)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let bookTitle = form.bookTitle, !bookTitle.isEmpty {
                    Text(bookTitle)
                        .font(AppFont.interface(size: 15, weight: .semibold))
                        .foregroundStyle(palette.foreground.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !form.reference.isEmpty {
                Text(form.reference)
                    .font(AppFont.interface(size: 17, weight: .semibold))
                    .foregroundStyle(palette.foreground.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Reference \(form.reference)")
            }

            if item.cf {
                Text("Cf.")
                    .font(AppFont.interface(size: 13, weight: .semibold))
                    .foregroundStyle(palette.mutedForeground.color)
            }

            if item.slot == "acclamation" {
                acclamationBody
            } else if item.slot == "psalm" {
                psalmBody
            } else {
                passageBody
            }

            if let note = bibleLanguageNote, !note.isEmpty {
                Text(note)
                    .font(AppFont.interface(size: 13))
                    .foregroundStyle(palette.mutedForeground.color)
            }

            if let closing = item.closing, !closing.isEmpty, item.slot != "psalm", item.slot != "acclamation" {
                Text(closing)
                    .font(AppFont.interface(size: 15, weight: .semibold))
                    .foregroundStyle(palette.foreground.color)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.card.color, in: RoundedRectangle(cornerRadius: Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg)
                .strokeBorder(palette.border.color, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var alternativesMenu: some View {
        Menu {
            ForEach(Array(item.forms.enumerated()), id: \.offset) { index, option in
                Button {
                    onSelectForm(index)
                } label: {
                    if index == formIndex {
                        Label(option.label ?? "Default form", systemImage: "checkmark")
                    } else {
                        Text(option.label ?? "Default form")
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(form.label ?? "Default form")
                    .font(AppFont.interface(size: 14, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(palette.primary.color)
            .frame(minHeight: ControlMetrics.minimumHeight, alignment: .leading)
        }
        .accessibilityLabel("Reading form")
        .accessibilityValue(form.label ?? "Default form")
    }

    @ViewBuilder
    private var passageBody: some View {
        switch form.body {
        case .passage(let verses, let fullVerseShown):
            if verses.isEmpty {
                EmptyView()
            } else {
                ReadingBlocksView(verses: verses, incipit: form.incipit)
                if fullVerseShown {
                    Text("Full verse shown.")
                        .font(AppFont.interface(size: 13))
                        .foregroundStyle(palette.mutedForeground.color)
                }
            }
        case .lectionary(let paragraphs, _):
            VStack(alignment: .leading, spacing: 8) {
                if let incipit = form.incipit, !incipit.isEmpty {
                    ReadingText(text: "\(incipit) \(paragraphs.first ?? "")", role: .prayer)
                    ForEach(Array(paragraphs.dropFirst().enumerated()), id: \.offset) { _, paragraph in
                        ReadingText(text: paragraph, role: .prayer)
                    }
                } else {
                    ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                        ReadingText(text: paragraph, role: .prayer)
                    }
                }
            }
        case .unavailable(let reason):
            Text(unavailableCopy(reason))
                .font(AppFont.interface(size: 15))
                .foregroundStyle(palette.mutedForeground.color)
        case .psalm:
            EmptyView()
        }
    }

    @ViewBuilder
    private var psalmBody: some View {
        if let refrain = form.refrain, !refrain.isEmpty {
            Text(refrain)
                .font(AppFont.interface(size: 16, weight: .semibold))
                .foregroundStyle(palette.emphasis.color)
                .fixedSize(horizontal: false, vertical: true)
        }
        if let refrainRef = form.refrainRef, !refrainRef.isEmpty {
            Text(refrainRef)
                .font(AppFont.interface(size: 13))
                .foregroundStyle(palette.mutedForeground.color)
        }
        switch form.body {
        case .psalm(let stanzas):
            ForEach(Array(stanzas.enumerated()), id: \.offset) { _, stanza in
                ReadingBlocksView(verses: stanza, incipit: nil)
                if let refrain = form.refrain, !refrain.isEmpty {
                    Text(refrain)
                        .font(AppFont.interface(size: 16, weight: .semibold))
                        .foregroundStyle(palette.emphasis.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        case .lectionary(_, let stanzas):
            ForEach(Array(stanzas.enumerated()), id: \.offset) { _, lines in
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        ReadingText(text: line, role: .prayer)
                    }
                }
                if let refrain = form.refrain, !refrain.isEmpty {
                    Text(refrain)
                        .font(AppFont.interface(size: 16, weight: .semibold))
                        .foregroundStyle(palette.emphasis.color)
                }
            }
        case .unavailable(let reason):
            Text(unavailableCopy(reason))
                .font(AppFont.interface(size: 15))
                .foregroundStyle(palette.mutedForeground.color)
        case .passage:
            EmptyView()
        }
    }

    @ViewBuilder
    private var acclamationBody: some View {
        if item.acclamationPhrases.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(item.acclamationPhrases.enumerated()), id: \.offset) { index, phrase in
                        let selected = index == phraseIndex
                        Button {
                            readings.setAcclamationPhrase(phrase, language: language, season: seasonKey)
                        } label: {
                            Text(phrase)
                                .font(AppFont.interface(size: 13, weight: .semibold))
                                .foregroundStyle(selected ? palette.primaryForeground.color : palette.foreground.color)
                                .padding(.horizontal, 12)
                                .frame(minHeight: ControlMetrics.minimumHeight)
                                .background(
                                    selected ? palette.primary.color : palette.secondary.color,
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(PressScaleButtonStyle())
                        .accessibilityLabel(phrase)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }
            .accessibilityLabel("Acclamation phrase")
        }

        if let phrase = selectedPhrase {
            Text(phrase)
                .font(AppFont.interface(size: 16, weight: .semibold))
                .foregroundStyle(palette.emphasis.color)
                .fixedSize(horizontal: false, vertical: true)
        }

        acclamationVerse

        if let phrase = selectedPhrase {
            Text(phrase)
                .font(AppFont.interface(size: 16, weight: .semibold))
                .foregroundStyle(palette.emphasis.color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Alleluia verse only: plain text, no quote rule, no gospel incipit.
    @ViewBuilder
    private var acclamationVerse: some View {
        switch form.body {
        case .passage(let verses, let fullVerseShown):
            let text = verses.flatMap(\.spans).map(\.text).joined()
            if !text.isEmpty {
                ReadingText(text: text, role: .prayer)
            }
            if fullVerseShown {
                Text("Full verse shown.")
                    .font(AppFont.interface(size: 13))
                    .foregroundStyle(palette.mutedForeground.color)
            }
        case .lectionary(let paragraphs, _):
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                ReadingText(text: paragraph, role: .prayer)
            }
        case .unavailable(let reason):
            Text(unavailableCopy(reason))
                .font(AppFont.interface(size: 15))
                .foregroundStyle(palette.mutedForeground.color)
        case .psalm:
            EmptyView()
        }
    }

    private func unavailableCopy(_ reason: ReadingBody.Reason) -> String {
        switch reason {
        case .noVersion:
            "No Bible version is available yet."
        case .notDownloaded:
            "This Bible version is not downloaded."
        case .missingVerses:
            "Text not available."
        case .noLectionary:
            "Readings not available in this calendar."
        }
    }
}
