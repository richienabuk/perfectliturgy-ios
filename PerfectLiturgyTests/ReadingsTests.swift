import Foundation
import SwiftUI
import Testing
import UIKit
@testable import PerfectLiturgy

@Test func `tomorrow sunday and a past date show the celebration and references`() {
    let index = Lectionary.load()
    let saturday = CivilDate(year: 2026, month: 10, day: 24)
    var cursor = ReadingsCursor(today: saturday)

    cursor.showTomorrow()
    #expect(cursor.date == CivilDate(year: 2026, month: 10, day: 25))
    #expect(cursor.showsTomorrow)
    #expect(cursor.showsSunday)
    let tomorrow = TodayPageBuilder.page(for: cursor.date, lectionary: index)
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
    let sunday = TodayPageBuilder.page(for: midweek.date, lectionary: index)
    #expect(sunday.title == tomorrow.title)
    #expect(sunday.readings.map(\.reference) == tomorrow.readings.map(\.reference))

    let month = MonthPage(year: 2026, month: 10, firstWeekday: 2)
    let pastDate = month.cells.compactMap { $0 }.first { $0.day == 18 }
    #expect(pastDate == CivilDate(year: 2026, month: 10, day: 18))
    cursor.choose(pastDate ?? CivilDate(year: 2026, month: 10, day: 18))
    #expect(cursor.showsPast)
    let past = TodayPageBuilder.page(for: cursor.date, lectionary: index)
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

@Test func `previous and next day move one civil day`() {
    var cursor = ReadingsCursor(today: CivilDate(year: 2026, month: 10, day: 31))
    cursor.step(by: 1)
    #expect(cursor.date == CivilDate(year: 2026, month: 11, day: 1))
    let page = TodayPageBuilder.page(for: cursor.date, lectionary: Lectionary.load())
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

@Test func `the calendar list is roman plus each installed country calendar`() {
    let patron = CountryCelebration(
        id: "test-patron",
        title: "Test patron",
        color: .red,
        month: 10,
        day: 18,
        year: 2026
    )
    let installed = CalendarOption(id: "calendar-test", title: "Test calendar", celebrations: [patron])
    let list = CalendarCatalog.list(installed: [installed, CalendarOption.roman])
    #expect(list.map(\.id) == ["roman", "calendar-test"])
    #expect(CalendarCatalog.installed().isEmpty)

    let roman = CalendarCatalog.selection(storedID: "missing", in: list)
    #expect(roman.id == "roman")
    let chosen = CalendarCatalog.selection(storedID: "calendar-test", in: list)
    let page = TodayPageBuilder.page(
        for: CivilDate(year: 2026, month: 10, day: 18),
        country: chosen.celebrations,
        lectionary: Lectionary.load()
    )
    #expect(page.title == "Test patron")
    #expect(page.readings.map(\.reference).contains("Matthew 22:15-21"))
}

@Test func `the chosen calendar is remembered`() throws {
    let suite = "readings-tests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defaults.removePersistentDomain(forName: suite)
    let first = ReadingsPreferences(defaults: defaults)
    #expect(first.calendarID == "roman")
    #expect(first.bibleVersionID == nil)
    first.calendarID = "calendar-test"
    let second = ReadingsPreferences(defaults: defaults)
    #expect(second.calendarID == "calendar-test")
    defaults.removePersistentDomain(forName: suite)
}

@Test func `the readings date reads as a spoken day`() {
    let date = CivilDate(year: 2026, month: 10, day: 25)
    #expect(TodayPageBuilder.spokenDate(for: date) == "Sunday, 25 October 2026")
}

@Test func `readings screen renders`() async throws {
    let suite = "readings-ui-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defaults.removePersistentDomain(forName: suite)
    let view = ReadingsView()
        .environment(AppNavigation())
        .environment(DesignPreferences())
        .environment(ReadingsPreferences(defaults: defaults))
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
