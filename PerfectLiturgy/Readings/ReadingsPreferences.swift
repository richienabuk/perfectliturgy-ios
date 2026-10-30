import Foundation

/// Calendar, Bible, and acclamation choices. All survive a relaunch (§8.3).
@Observable
final class ReadingsPreferences {
    private let defaults: UserDefaults
    /// One-shot migration of the old single Bible preference into `bibleSelection`.
    private var legacyBibleVersion: String?

    var calendarID: String {
        didSet { defaults.set(calendarID, forKey: Key.calendar) }
    }

    /// Calendar language → Bible version id, or `lectionary` for lectionary-supplied text.
    var bibleSelection: [String: String] {
        didSet { defaults.set(bibleSelection, forKey: Key.bibleSelection) }
    }

    /// `"{language}|{season}"` → chosen acclamation phrase text.
    var acclamationChoice: [String: String] {
        didSet { defaults.set(acclamationChoice, forKey: Key.acclamation) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var stored = defaults.string(forKey: Key.calendar) ?? CalendarOption.latinRite.id
        if stored == "roman" {
            stored = CalendarOption.latinRite.id
            defaults.set(stored, forKey: Key.calendar)
        }
        calendarID = stored

        if let storedSelection = defaults.dictionary(forKey: Key.bibleSelection) as? [String: String] {
            bibleSelection = storedSelection
            legacyBibleVersion = nil
        } else if let legacy = defaults.string(forKey: Key.bible) {
            bibleSelection = [:]
            legacyBibleVersion = legacy
            defaults.removeObject(forKey: Key.bible)
        } else {
            bibleSelection = [:]
            legacyBibleVersion = nil
        }

        acclamationChoice = (defaults.dictionary(forKey: Key.acclamation) as? [String: String]) ?? [:]
    }

    /// Bible version (or `lectionary`) for a calendar language. Migrates a legacy single value once.
    func bibleVersionID(for language: String) -> String? {
        if let stored = bibleSelection[language] {
            return stored
        }
        guard let legacy = legacyBibleVersion else { return nil }
        legacyBibleVersion = nil
        var next = bibleSelection
        next[language] = legacy
        bibleSelection = next
        return legacy
    }

    func setBibleVersionID(_ id: String?, for language: String) {
        var next = bibleSelection
        if let id {
            next[language] = id
        } else {
            next.removeValue(forKey: language)
        }
        bibleSelection = next
    }

    func acclamationPhrase(language: String, season: String) -> String? {
        acclamationChoice[Self.acclamationKey(language: language, season: season)]
    }

    func setAcclamationPhrase(_ phrase: String?, language: String, season: String) {
        var next = acclamationChoice
        let key = Self.acclamationKey(language: language, season: season)
        if let phrase {
            next[key] = phrase
        } else {
            next.removeValue(forKey: key)
        }
        acclamationChoice = next
    }

    /// After a calendar pack installs: auto-select when it is the only downloaded calendar.
    func noteCalendarInstalled(_ packId: String, installedIDs: Set<String>) {
        let calendars = installedIDs.filter { $0.hasPrefix("calendar-") }
        if calendars.count == 1, calendars.contains(packId) {
            calendarID = packId
        }
    }

    /// After remove: keep another calendar if exactly one remains, otherwise Latin Rite.
    func noteCalendarRemoved(_ packId: String, remainingIDs: Set<String>) {
        guard calendarID == packId else { return }
        let remaining = remainingIDs.filter { $0.hasPrefix("calendar-") }
        if remaining.count == 1, let only = remaining.first {
            calendarID = only
        } else {
            calendarID = CalendarOption.latinRite.id
        }
    }

    static func acclamationKey(language: String, season: String) -> String {
        "\(language)|\(season)"
    }

    private enum Key {
        static let calendar = "chosenCalendar"
        static let bible = "chosenBibleVersion"
        static let bibleSelection = "chosenBibleSelection"
        static let acclamation = "chosenAcclamation"
    }
}
