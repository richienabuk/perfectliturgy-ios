import Foundation
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import PerfectLiturgy

@Test func `tomorrow sunday and a past date show the celebration and references`() async throws {
    let seed = try loadReadingsSeed()
    let saturday = CivilDate(year: 2026, month: 10, day: 24)
    var cursor = ReadingsCursor(today: saturday)

    cursor.showTomorrow()
    #expect(cursor.date == CivilDate(year: 2026, month: 10, day: 25))
    #expect(cursor.showsTomorrow)
    #expect(cursor.showsSunday)
    let tomorrow = await TodayPageBuilder.load(
        date: cursor.date,
        calendar: .latinRite,
        lectionary: seed,
        bible: nil,
        source: .bible(versionID: "test")
    )
    #expect(tomorrow.title == "30th Sunday in Ordinary Time")
    #expect(tomorrow.weekMark == "XXX")
    #expect(tomorrow.readings.map(\.reference) == [
        "Exodus 22:20-26",
        "Psalm 18:2-3a, 3b-4, 47, 51",
        "1 Thessalonians 1:5c-10",
        "John 14:23",
        "Matthew 22:34-40",
    ])

    var midweek = ReadingsCursor(today: CivilDate(year: 2026, month: 10, day: 21))
    midweek.showSunday()
    #expect(midweek.date == CivilDate(year: 2026, month: 10, day: 25))
    #expect(midweek.showsSunday)
    #expect(!midweek.showsTomorrow)
    let sunday = await TodayPageBuilder.load(
        date: midweek.date,
        calendar: .latinRite,
        lectionary: seed,
        bible: nil,
        source: .bible(versionID: "test")
    )
    #expect(sunday.title == tomorrow.title)
    #expect(sunday.readings.map(\.reference) == tomorrow.readings.map(\.reference))

    let month = MonthPage(year: 2026, month: 10, firstWeekday: 2)
    let pastDate = month.cells.compactMap { $0 }.first { $0.day == 18 }
    #expect(pastDate == CivilDate(year: 2026, month: 10, day: 18))
    cursor.choose(pastDate ?? CivilDate(year: 2026, month: 10, day: 18))
    #expect(cursor.showsPast)
    let past = await TodayPageBuilder.load(
        date: cursor.date,
        calendar: .latinRite,
        lectionary: seed,
        bible: nil,
        source: .bible(versionID: "test")
    )
    #expect(past.title == "29th Sunday in Ordinary Time")
    #expect(past.weekMark == "XXIX")
    #expect(past.readings.map(\.label) == [
        "First reading",
        "Responsorial psalm",
        "Second reading",
        "Gospel acclamation",
        "Gospel",
    ])
    #expect(past.readings.map(\.reference) == [
        "Isaiah 45:1, 4-6",
        "Psalm 96:1, 3, 4-5, 7-8, 9-10",
        "1 Thessalonians 1:1-5b",
        "Philippians 2:15d-16a",
        "Matthew 22:15-21",
    ])
}

@Test func `previous and next day move one civil day`() async throws {
    var cursor = ReadingsCursor(today: CivilDate(year: 2026, month: 10, day: 31))
    cursor.step(by: 1)
    #expect(cursor.date == CivilDate(year: 2026, month: 11, day: 1))
    let seed = try loadReadingsSeed()
    let page = await TodayPageBuilder.load(
        date: cursor.date,
        calendar: .latinRite,
        lectionary: seed,
        bible: nil,
        source: .bible(versionID: "test")
    )
    #expect(page.title == "All Saints")
    cursor.step(by: -1)
    #expect(cursor.showsToday)
}

@Test func `the month sheet can move to another month`() {
    let october = MonthPage(year: 2026, month: 10, firstWeekday: 2)
    #expect(october.title == "October 2026")
    #expect(october.cells[0] == nil)
    #expect(october.cells[3] == CivilDate(year: 2026, month: 10, day: 1))
    #expect(october.cells.count.isMultiple(of: 7))
    let november = october.advanced(by: 1)
    #expect(november.year == 2026)
    #expect(november.month == 11)
    #expect(october.advanced(by: -1).month == 9)
}

@Test func `readings dates stop at one month behind and two months ahead`() {
    let today = CivilDate(year: 2026, month: 10, day: 15)
    #expect(ReadingsDateWindow.earliest(from: today) == CivilDate(year: 2026, month: 9, day: 15))
    #expect(ReadingsDateWindow.latest(from: today) == CivilDate(year: 2026, month: 12, day: 15))
    #expect(ReadingsDateWindow.contains(CivilDate(year: 2026, month: 9, day: 15), today: today))
    #expect(!ReadingsDateWindow.contains(CivilDate(year: 2026, month: 9, day: 14), today: today))
    #expect(ReadingsDateWindow.contains(CivilDate(year: 2026, month: 12, day: 15), today: today))
    #expect(!ReadingsDateWindow.contains(CivilDate(year: 2026, month: 12, day: 16), today: today))

    var cursor = ReadingsCursor(today: today)
    cursor.choose(CivilDate(year: 2026, month: 9, day: 14))
    #expect(cursor.date == CivilDate(year: 2026, month: 9, day: 15))
    cursor.choose(CivilDate(year: 2026, month: 12, day: 16))
    #expect(cursor.date == CivilDate(year: 2026, month: 12, day: 15))
    cursor.choose(CivilDate(year: 2026, month: 9, day: 15))
    #expect(!cursor.canStepBack)
    cursor.step(by: -1)
    #expect(cursor.date == CivilDate(year: 2026, month: 9, day: 15))
    cursor.choose(CivilDate(year: 2026, month: 12, day: 15))
    #expect(!cursor.canStepForward)
    cursor.step(by: 1)
    #expect(cursor.date == CivilDate(year: 2026, month: 12, day: 15))

    let september = MonthPage(year: 2026, month: 9, firstWeekday: 1)
    let december = MonthPage(year: 2026, month: 12, firstWeekday: 1)
    let august = MonthPage(year: 2026, month: 8, firstWeekday: 1)
    let january = MonthPage(year: 2027, month: 1, firstWeekday: 1)
    #expect(september.overlapsWindow(today: today))
    #expect(december.overlapsWindow(today: today))
    #expect(!august.overlapsWindow(today: today))
    #expect(!january.overlapsWindow(today: today))
    #expect(!september.canAdvance(by: -1, today: today))
    #expect(!december.canAdvance(by: 1, today: today))
    #expect(september.canAdvance(by: 1, today: today))
    #expect(december.canAdvance(by: -1, today: today))
}

@Test func `with no bible version the row says none is available yet`() {
    let status = BibleVersionStatus.resolve([], selectedID: nil)
    #expect(status.line == "None is available yet.")
    #expect(status.opensDownloads)

    let stored = BibleVersionStatus.resolve(
        [BibleVersionChoice(id: "readings-test", title: "Test version")],
        selectedID: "readings-test"
    )
    #expect(stored.line == "Test version")
    #expect(!stored.opensDownloads)
}

@Test func `the calendar list is Latin Rite plus each installed calendar`() async throws {
    let patron = CountryCelebration(
        id: "test-patron",
        title: "Test patron",
        color: .red,
        month: 10,
        day: 18,
        year: 2026
    )
    let installed = CalendarOption(
        id: "calendar-test",
        title: "Test calendar",
        language: "en",
        celebrations: [patron]
    )
    let list = CalendarCatalog.list(installed: [installed, CalendarOption.latinRite])
    #expect(list.map(\.id) == ["latin-rite", "calendar-test"])
    #expect(CalendarCatalog.installed(ids: [], root: URL(fileURLWithPath: "/tmp/pl-no-calendars")).isEmpty)

    let seedOption = CalendarCatalog.selection(storedID: "missing", in: list)
    #expect(seedOption.id == "latin-rite")
    let chosen = CalendarCatalog.selection(storedID: "calendar-test", in: list)
    let seed = try loadReadingsSeed()
    let page = await TodayPageBuilder.load(
        date: CivilDate(year: 2026, month: 10, day: 18),
        calendar: chosen,
        lectionary: seed,
        bible: nil,
        source: .bible(versionID: "test")
    )
    #expect(page.title == "Test patron")
    #expect(page.readings.map(\.reference).contains("Matthew 22:15-21"))
}

@Test func `the chosen calendar is remembered and roman migrates to latin-rite`() throws {
    let suite = "readings-tests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defaults.removePersistentDomain(forName: suite)
    let first = ReadingsPreferences(defaults: defaults)
    #expect(first.calendarID == "latin-rite")
    #expect(first.bibleVersionID(for: "en") == nil)
    first.calendarID = "calendar-test"
    let second = ReadingsPreferences(defaults: defaults)
    #expect(second.calendarID == "calendar-test")

    defaults.set("roman", forKey: "chosenCalendar")
    defaults.set("readings-test", forKey: "chosenBibleVersion")
    let migrated = ReadingsPreferences(defaults: defaults)
    #expect(migrated.calendarID == "latin-rite")
    #expect(migrated.bibleVersionID(for: "en") == "readings-test")
    #expect(defaults.string(forKey: "chosenBibleVersion") == nil)
    #expect(defaults.string(forKey: "chosenCalendar") == "latin-rite")
    defaults.removePersistentDomain(forName: suite)
}

@Test func `the readings date reads as a spoken day`() {
    let date = CivilDate(year: 2026, month: 10, day: 25)
    #expect(TodayPageBuilder.spokenDate(for: date) == "Sunday, 25 October 2026")
}

@Test func `a multi-Mass day adds an open readings row on Today`() async {
    let lectionary = Lectionary(
        id: "test",
        language: "en",
        displayName: "Test",
        revision: "1",
        formulas: LectionaryFormulas(
            sets: ["vigil": "Test Vigil", "day": "Test Day"],
            slots: [:],
            bookTitles: [:],
            acclamation: [:]
        ),
        sunday: [
            "christmas|A": [
                LectionaryItem(
                    slot: "gospel",
                    reference: "Test vigil gospel",
                    ranges: [],
                    set: "vigil",
                    label: nil,
                    incipit: nil,
                    theme: nil,
                    refrain: nil,
                    refrainRef: nil,
                    closing: nil,
                    cf: false,
                    alternatives: [],
                    text: nil
                ),
                LectionaryItem(
                    slot: "gospel",
                    reference: "Test day gospel",
                    ranges: [],
                    set: "day",
                    label: nil,
                    incipit: nil,
                    theme: nil,
                    refrain: nil,
                    refrainRef: nil,
                    closing: nil,
                    cf: false,
                    alternatives: [],
                    text: nil
                ),
            ],
        ],
        feria: [:],
        proper: [:],
        days: []
    )
    let day = LiturgicalDay(
        id: "christmas",
        title: "The Nativity of the Lord",
        color: .white,
        season: .christmas,
        rank: .solemnity,
        weekMark: nil,
        fromCountryCalendar: false,
        readingKey: "christmas|A|II"
    )
    let resolved = await ReadingResolver.resolve(
        day: day,
        lectionary: lectionary,
        bible: nil,
        source: .bible(versionID: "test"),
        verses: EmptyVerseSource(),
        includeText: false
    )
    let page = TodayPageBuilder.page(
        for: CivilDate(year: 2025, month: 12, day: 25),
        dayReadings: resolved,
        celebrationTitle: day.title,
        weekMark: nil
    )
    #expect(page.readings.last?.opensReadings == true)
    #expect(page.readings.last?.label == "2 Masses. Open readings.")
}

@Test func `readings screen renders`() async throws {
    let suite = "readings-ui-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defaults.removePersistentDomain(forName: suite)
    let container = try HymnStore.make(inMemory: true)
    let packs = InstalledPacks(defaults: defaults)
    let view = ReadingsView()
        .environment(AppNavigation())
        .environment(DesignPreferences())
        .environment(ReadingsPreferences(defaults: defaults))
        .environment(packs)
        .modelContainer(container)
        .resolvePalette()
        .frame(width: 390, height: 1400)
    let image = try await renderReadings(view, size: CGSize(width: 390, height: 1400))
    Attachment.record(image, named: "readings-phone")
    #expect(image.size.width > 300)
    #expect(image.size.height > 1000)

    let wide = ReadingsView()
        .environment(AppNavigation())
        .environment(DesignPreferences())
        .environment(ReadingsPreferences(defaults: defaults))
        .environment(packs)
        .modelContainer(container)
        .environment(\.isWideLayout, true)
        .resolvePalette()
        .frame(width: 1100, height: 900)
    let wideImage = try await renderReadings(wide, size: CGSize(width: 1100, height: 900))
    Attachment.record(wideImage, named: "readings-wide")
    #expect(wideImage.size.width > 1000)

    let sheet = ReadingsSheetPreview()
        .environment(DesignPreferences())
        .resolvePalette()
        .frame(width: 390, height: 720)
    let sheetImage = try await renderReadings(sheet, size: CGSize(width: 390, height: 720))
    Attachment.record(sheetImage, named: "readings-sheet")
    #expect(sheetImage.size.height > 600)
    defaults.removePersistentDomain(forName: suite)
}

private func loadReadingsSeed() throws -> Lectionary {
    let bundle = Bundle(for: DesignPreferences.self)
    let url = try #require(bundle.url(forResource: "lectionary-latin-rite", withExtension: "json"))
    return try LectionaryStore.decode(Data(contentsOf: url))
}

private struct ReadingsSheetPreview: View {
    @State private var month = MonthPage(year: 2026, month: 10, firstWeekday: 1)
    @State private var selected = CivilDate(year: 2026, month: 10, day: 25)

    var body: some View {
        ReadingsMonthSheet(
            month: $month,
            selected: $selected,
            today: CivilDate(year: 2026, month: 10, day: 24),
            onUse: {}
        )
    }
}

@MainActor
private func renderReadings<V: View>(_ view: V, size: CGSize) async throws -> UIImage {
    let host = UIHostingController(rootView: view)
    let bounds = CGRect(origin: .zero, size: size)
    host.view.bounds = bounds
    host.view.frame = bounds
    let window = UIWindow(frame: bounds)
    window.rootViewController = host
    window.makeKeyAndVisible()
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()
    try await Task.sleep(for: .milliseconds(400))
    let format = UIGraphicsImageRendererFormat()
    format.scale = 2
    return UIGraphicsImageRenderer(size: bounds.size, format: format).image { _ in
        host.view.drawHierarchy(in: bounds, afterScreenUpdates: true)
    }
}
