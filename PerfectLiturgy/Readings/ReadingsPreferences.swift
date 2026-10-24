import Foundation

/// The calendar and Bible version chosen on Readings. Both survive a relaunch.
@Observable
final class ReadingsPreferences {
    private let defaults: UserDefaults

    var calendarID: String {
        didSet { defaults.set(calendarID, forKey: Key.calendar) }
    }

    var bibleVersionID: String? {
        didSet {
            if let bibleVersionID {
                defaults.set(bibleVersionID, forKey: Key.bible)
            } else {
                defaults.removeObject(forKey: Key.bible)
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        calendarID = defaults.string(forKey: Key.calendar) ?? CalendarOption.roman.id
        bibleVersionID = defaults.string(forKey: Key.bible)
    }

    private enum Key {
        static let calendar = "chosenCalendar"
        static let bible = "chosenBibleVersion"
    }
}
