import SwiftUI

struct ReadingsView: View {
    var installedCalendars: [CalendarOption] = CalendarCatalog.installed()
    var bibleVersions: [BibleVersionChoice] = []

    @Environment(AppNavigation.self) private var navigation
    @Environment(ReadingsPreferences.self) private var readings
    @Environment(\.palette) private var palette
    @Environment(\.isWideLayout) private var isWide

    @State private var cursor = ReadingsCursor(today: CivilDate(Date()))
    @State private var showsMonth = false
    @State private var optionsOpen = false
    @State private var draft = CivilDate(Date())
    @State private var month = MonthPage.containing(CivilDate(Date()), firstWeekday: 1)

    private var calendars: [CalendarOption] {
        CalendarCatalog.list(installed: installedCalendars)
    }

    private var calendar: CalendarOption {
        CalendarCatalog.selection(storedID: readings.calendarID, in: calendars)
    }

    private var versionStatus: BibleVersionStatus {
        BibleVersionStatus.resolve(bibleVersions, selectedID: readings.bibleVersionID)
    }

    private var page: TodayPage {
        TodayPageBuilder.page(
            for: cursor.date,
            country: calendar.celebrations,
            lectionary: ReadingsLibrary.lectionary
        )
    }

    private var spokenDate: String {
        TodayPageBuilder.spokenDate(for: cursor.date)
    }

    /// Verse text for a slot, once a Bible version on the device covers every cited verse.
    private func verses(for reading: TodayReading) -> String? {
        guard bibleVersions.contains(where: { $0.id == readings.bibleVersionID }), !reading.reference.isEmpty else {
            return nil
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            PLTopBar()
            phoneBody
        }
        .background(palette.background.color)
        .navigationTitle("Readings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            cursor.noteToday(CivilDate(Date()))
        }
        .sheet(isPresented: $showsMonth) {
            ReadingsMonthSheet(month: $month, selected: $draft, today: cursor.today) {
                cursor.choose(draft)
                showsMonth = false
            }
        }
    }

    private var phoneBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                heading
                dateCard
                chips
                options
                VStack(spacing: 12) {
                    ForEach(page.readings) { reading in
                        passageCard(reading)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .frame(maxWidth: isWide ? 840 : .infinity, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var heading: some View {
        Text("Daily readings")
            .font(AppFont.heading(size: 36))
            .foregroundStyle(palette.foreground.color)
            .tracking(36 * AppFont.headingTrackingFactor)
            .accessibilityAddTraits(.isHeader)
    }

    private var dateCard: some View {
        HStack(spacing: 8) {
            Button(action: openPicker) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "calendar")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(palette.emphasis.color)
                        .frame(width: 28, height: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(spokenDate)
                            .font(AppFont.interface(size: 16, weight: .semibold))
                            .foregroundStyle(palette.foreground.color)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text("Open the liturgical calendar")
                            .font(AppFont.interface(size: 13))
                            .foregroundStyle(palette.mutedForeground.color)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 8)
                }
                .frame(maxWidth: .infinity, minHeight: ControlMetrics.minimumHeight, alignment: .leading)
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel("\(spokenDate). Open the liturgical calendar")
            dayArrow("chevron.left", "Previous day") { cursor.step(by: -1) }
            dayArrow("chevron.right", "Next day") { cursor.step(by: 1) }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(palette.card.color, in: RoundedRectangle(cornerRadius: Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg)
                .strokeBorder(palette.border.color, lineWidth: 1)
        }
    }

    private var chips: some View {
        HStack(spacing: 8) {
            ReadingsChip(title: "Today", isSelected: cursor.showsToday) {
                cursor.showToday()
            }
            ReadingsChip(title: "Tomorrow", isSelected: cursor.showsTomorrow) {
                cursor.showTomorrow()
            }
            ReadingsChip(title: "Sunday", isSelected: cursor.showsSunday) {
                cursor.showSunday()
            }
            ReadingsChip(title: "Past dates", isSelected: cursor.showsPast) {
                openPicker()
            }
        }
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                optionsOpen.toggle()
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(palette.emphasis.color)
                        .frame(width: 24, height: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reading options")
                            .font(AppFont.interface(size: 16, weight: .semibold))
                            .foregroundStyle(palette.foreground.color)
                        Text(optionsSummary)
                            .font(AppFont.interface(size: 13))
                            .foregroundStyle(palette.mutedForeground.color)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: optionsOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.mutedForeground.color)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: ControlMetrics.minimumHeight, alignment: .leading)
                .background(palette.secondary.color, in: RoundedRectangle(cornerRadius: Radius.lg))
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel("Reading options")
            .accessibilityValue(optionsSummary)
            if optionsOpen {
                bibleRow
                calendarRow
                Button(action: openDownloads) {
                    Text("Manage Bible versions")
                        .font(AppFont.interface(size: 15, weight: .semibold))
                        .foregroundStyle(palette.primary.color)
                        .frame(maxWidth: .infinity, minHeight: ControlMetrics.minimumHeight, alignment: .leading)
                }
                .buttonStyle(PressScaleButtonStyle())
            }
        }
    }

    private var optionsSummary: String {
        if versionStatus.opensDownloads {
            return "None is available yet."
        }
        return "\(versionStatus.line) · \(calendar.title)"
    }

    @ViewBuilder
    private var bibleRow: some View {
        if versionStatus.opensDownloads {
            Button(action: openDownloads) {
                optionCard(
                    symbol: "book.closed",
                    title: "Bible version",
                    detail: versionStatus.line,
                    trailing: "chevron.right"
                )
            }
            .buttonStyle(PressScaleButtonStyle())
        } else {
            Menu {
                ForEach(bibleVersions) { version in
                    Button {
                        readings.bibleVersionID = version.id
                    } label: {
                        if version.id == readings.bibleVersionID {
                            Label(version.title, systemImage: "checkmark")
                        } else {
                            Text(version.title)
                        }
                    }
                }
            } label: {
                optionCard(
                    symbol: "book.closed",
                    title: "Bible version · \(versionStatus.line)",
                    detail: versionStatus.line,
                    trailing: "chevron.down"
                )
            }
        }
    }

    private var calendarRow: some View {
        Menu {
            ForEach(calendars) { option in
                Button {
                    readings.calendarID = option.id
                } label: {
                    if option.id == calendar.id {
                        Label(option.title, systemImage: "checkmark")
                    } else {
                        Text(option.title)
                    }
                }
            }
        } label: {
            optionCard(
                symbol: "calendar",
                title: "Liturgical calendar · \(calendar.title)",
                detail: calendar.id == CalendarOption.roman.id ? "The Roman rite" : "Local solemnities and feasts",
                trailing: "chevron.down"
            )
        }
    }

    private func optionCard(symbol: String, title: String, detail: String, trailing: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.emphasis.color)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.interface(size: 15, weight: .semibold))
                    .foregroundStyle(palette.foreground.color)
                    .multilineTextAlignment(.leading)
                Text(detail)
                    .font(AppFont.interface(size: 13))
                    .foregroundStyle(palette.mutedForeground.color)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 8)
            Image(systemName: trailing)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.mutedForeground.color)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: ControlMetrics.minimumHeight, alignment: .leading)
        .background(palette.card.color, in: RoundedRectangle(cornerRadius: Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg)
                .strokeBorder(palette.border.color, lineWidth: 1)
        }
    }

    private func passageCard(_ reading: TodayReading) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(reading.label.uppercased())
                .font(AppFont.interface(size: 12, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(palette.emphasis.color)
            if !reading.reference.isEmpty {
                Text(reading.reference)
                    .font(AppFont.interface(size: 17, weight: .semibold))
                    .foregroundStyle(palette.foreground.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let text = verses(for: reading), !text.isEmpty {
                ReadingText(text: text, role: .prayer)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.card.color, in: RoundedRectangle(cornerRadius: Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg)
                .strokeBorder(palette.border.color, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func dayArrow(_ systemName: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.foreground.color)
                .frame(width: 36, height: ControlMetrics.minimumHeight)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(label)
    }

    private func openPicker() {
        draft = cursor.date
        month = MonthPage.containing(cursor.date, firstWeekday: 1)
        showsMonth = true
    }

    private func openDownloads() {
        navigation.path.append(AppRoute.downloads)
    }
}

private enum ReadingsLibrary {
    static let lectionary = Lectionary.load()
}

private struct ReadingsChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.interface(size: 14, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(isSelected ? palette.primaryForeground.color : palette.foreground.color)
                .frame(maxWidth: .infinity)
                .frame(minHeight: ControlMetrics.minimumHeight)
                .padding(.horizontal, 4)
                .background(
                    isSelected ? palette.primary.color : palette.card.color,
                    in: RoundedRectangle(cornerRadius: Radius.lg)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .strokeBorder(isSelected ? palette.primary.color : palette.border.color, lineWidth: 1)
                }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct ReadingsMonthSheet: View {
    @Binding var month: MonthPage
    @Binding var selected: CivilDate
    var today: CivilDate
    var onUse: () -> Void

    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            monthRow
                .padding(.horizontal, 12)
            ScrollView {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(Array(letters.enumerated()), id: \.offset) { _, letter in
                        Text(letter)
                            .font(AppFont.interface(size: 13, weight: .semibold))
                            .foregroundStyle(palette.mutedForeground.color)
                            .frame(maxWidth: .infinity, minHeight: 28)
                    }
                    ForEach(Array(month.cells.enumerated()), id: \.offset) { _, date in
                        dayCell(date)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            HStack(spacing: 12) {
                PLButton(title: "Today", kind: .outline) {
                    selected = today
                    month = MonthPage.containing(today, firstWeekday: month.firstWeekday)
                }
                PLButton(title: "Use date", kind: .primary, action: onUse)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(palette.background.color)
        .tint(palette.primary.color)
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
        .presentationCornerRadius(Radius.sheet)
        .presentationBackground(palette.background.color)
    }

    private var letters: [String] {
        month.weekdayLabels.map { String($0.prefix(1)).uppercased() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Choose a date")
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

    private var monthRow: some View {
        HStack(spacing: 8) {
            stepButton(systemName: "chevron.left", label: "Previous month") {
                month = month.advanced(by: -1)
            }
            Text(month.title)
                .font(AppFont.heading(size: 28))
                .foregroundStyle(palette.foreground.color)
                .tracking(28 * AppFont.headingTrackingFactor)
                .frame(maxWidth: .infinity)
            stepButton(systemName: "chevron.right", label: "Next month") {
                month = month.advanced(by: 1)
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ date: CivilDate?) -> some View {
        if let date {
            let isSelected = date == selected
            Button {
                selected = date
            } label: {
                Text("\(date.day)")
                    .font(AppFont.interface(size: 16, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? palette.primaryForeground.color : palette.foreground.color)
                    .frame(width: 40, height: 36)
                    .background(isSelected ? palette.primary.color : Color.clear, in: Capsule())
                    .frame(maxWidth: .infinity, minHeight: ControlMetrics.minimumHeight)
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel(TodayPageBuilder.spokenDate(for: date))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        } else {
            Color.clear
                .frame(minHeight: ControlMetrics.minimumHeight)
        }
    }

    private func stepButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.foreground.color)
                .frame(minWidth: ControlMetrics.minimumHeight, minHeight: ControlMetrics.minimumHeight)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(label)
    }
}

#Preview {
    ReadingsView()
        .environment(DesignPreferences())
        .environment(AppNavigation())
        .environment(ReadingsPreferences(defaults: UserDefaults(suiteName: "readings-preview") ?? .standard))
        .resolvePalette()
}
