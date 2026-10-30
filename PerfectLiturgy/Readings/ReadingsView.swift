import SwiftUI

struct ReadingsView: View {
    var installedCalendars: [CalendarOption] = []
    var bibleVersions: [BibleVersionChoice] = []

    @Environment(AppNavigation.self) private var navigation
    @Environment(ReadingsPreferences.self) private var readings
    @Environment(InstalledPacks.self) private var packs
    @Environment(\.palette) private var palette
    @Environment(\.isWideLayout) private var isWide

    @State private var cursor = ReadingsCursor(today: CivilDate(Date()))
    @State private var showsMonth = false
    @State private var optionsOpen = false
    @State private var draft = CivilDate(Date())
    @State private var month = MonthPage.containing(CivilDate(Date()), firstWeekday: 1)
    @State private var dayReadings: DayReadings?
    @State private var celebrationTitle = ""
    @State private var seasonKey = ""
    @State private var activeLectionary = Lectionary.empty
    @State private var cachedCalendars: [CalendarOption] = [CalendarOption.latinRite]
    @State private var versionChoices: [BibleVersionChoice] = []
    @State private var selectedSetIndex = 0
    @State private var formChoices: [Int: Int] = [:]
    @State private var loadFailed = false

    private var calendars: [CalendarOption] {
        installedCalendars.isEmpty ? cachedCalendars : CalendarCatalog.list(installed: installedCalendars)
    }

    private var calendar: CalendarOption {
        CalendarCatalog.selection(storedID: readings.calendarID, in: calendars)
    }

    private var resolvedVersions: [BibleVersionChoice] {
        bibleVersions.isEmpty ? versionChoices : bibleVersions
    }

    private var selectedBibleID: String? {
        readings.bibleVersionID(for: calendar.language)
    }

    private var versionStatus: BibleVersionStatus {
        BibleVersionStatus.resolve(resolvedVersions, selectedID: selectedBibleID)
    }

    private var spokenDate: String {
        TodayPageBuilder.spokenDate(for: cursor.date)
    }

    private var taskKey: String {
        let bible = selectedBibleID ?? ""
        return "\(cursor.date.year)-\(cursor.date.month)-\(cursor.date.day)|\(calendar.id)|\(bible)|\(packs.ids.sorted().joined(separator: ","))"
    }

    private var activeSet: ReadingSet? {
        guard let dayReadings, !dayReadings.sets.isEmpty else { return nil }
        let index = min(max(selectedSetIndex, 0), dayReadings.sets.count - 1)
        return dayReadings.sets[index]
    }

    private var bibleLanguageNote: String? {
        let pair = LectionarySession.textSource(selection: selectedBibleID, versions: resolvedVersions)
        guard let bible = pair.bible, bible.language != activeLectionary.language else { return nil }
        let name = Locale.current.localizedString(forLanguageCode: bible.language) ?? bible.language
        return "Text in \(name)."
    }

    var body: some View {
        VStack(spacing: 0) {
            PLTopBar(isTabRoot: true)
            phoneBody
        }
        .background(palette.background.color)
        .navigationTitle("Readings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            cursor.noteToday(CivilDate(Date()))
        }
        .task(id: taskKey) {
            await reload()
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
                if let dayReadings, dayReadings.sets.count > 1 {
                    massSetControl(dayReadings.sets)
                }
                content
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .frame(maxWidth: isWide ? 840 : .infinity, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var content: some View {
        if loadFailed {
            Text("Readings not available in this calendar.")
                .font(AppFont.interface(size: 15))
                .foregroundStyle(palette.mutedForeground.color)
        } else if let set = activeSet {
            if !celebrationTitle.isEmpty {
                CelebrationLine(title: celebrationTitle)
            }
            VStack(spacing: 12) {
                ForEach(set.items) { item in
                    DayReadingItemView(
                        item: item,
                        formIndex: formChoices[item.id] ?? 0,
                        onSelectForm: { formChoices[item.id] = $0 },
                        language: activeLectionary.language,
                        seasonKey: seasonKey,
                        bibleLanguageNote: bibleLanguageNote
                    )
                }
            }
        } else if dayReadings != nil {
            Text("Readings not available in this calendar.")
                .font(AppFont.interface(size: 15))
                .foregroundStyle(palette.mutedForeground.color)
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
            dayArrow("chevron.left", "Previous day", enabled: cursor.canStepBack) {
                cursor.step(by: -1)
            }
            dayArrow("chevron.right", "Next day", enabled: cursor.canStepForward) {
                cursor.step(by: 1)
            }
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

    private func massSetControl(_ sets: [ReadingSet]) -> some View {
        let titles = sets.map { $0.label ?? $0.id?.capitalized ?? "Mass" }
        return Picker("Mass", selection: $selectedSetIndex) {
            ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                Text(title).tag(index)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Mass")
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
        if resolvedVersions.isEmpty {
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
                ForEach(resolvedVersions) { version in
                    Button {
                        readings.setBibleVersionID(version.id, for: calendar.language)
                    } label: {
                        if version.id == selectedBibleID {
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
                detail: calendar.id == CalendarOption.latinRite.id ? "Latin Rite" : "Local solemnities and feasts",
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

    private func dayArrow(
        _ systemName: String,
        _ label: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(enabled ? palette.foreground.color : palette.mutedForeground.color)
                .frame(width: 36, height: ControlMetrics.minimumHeight)
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(!enabled)
        .accessibilityLabel(label)
        .accessibilityAddTraits(enabled ? [] : .isStaticText)
    }

    private func openPicker() {
        draft = ReadingsDateWindow.clamp(cursor.date, today: cursor.today)
        month = MonthPage.containing(draft, firstWeekday: 1)
        showsMonth = true
    }

    private func openDownloads() {
        navigation.path.append(AppRoute.downloads)
    }

    @MainActor
    private func reload() async {
        loadFailed = false
        formChoices = [:]
        selectedSetIndex = 0
        refreshCalendars()
        let selected = calendar
        let bundle = Bundle(for: DesignPreferences.self)
        let lectionary = await LectionarySession.lectionary(
            calendarID: selected.id,
            packs: packs,
            bundle: bundle
        )
        activeLectionary = lectionary
        let seedFallback: Lectionary? = lectionary.id == CalendarOption.latinRite.id
            ? nil
            : await LectionaryStore.shared.seed(bundle: bundle)
        if bibleVersions.isEmpty {
            versionChoices = await LectionarySession.bibleVersions()
        }
        let versions = resolvedVersions
        let pair = LectionarySession.textSource(
            selection: readings.bibleVersionID(for: selected.language),
            versions: versions
        )
        let day = LatinRiteCalendar.day(on: cursor.date, country: selected.celebrations)
        celebrationTitle = day.title
        seasonKey = day.season.formulaKey
        let resolved = await ReadingResolver.resolve(
            day: day,
            lectionary: lectionary,
            bible: pair.bible,
            source: pair.source,
            verses: BibleReader(modelContainer: BibleStore.shared),
            includeText: true,
            fallback: seedFallback
        )
        if Task.isCancelled { return }
        dayReadings = resolved
        loadFailed = resolved.sets.isEmpty
            && ReadingResolver.items(for: day, lectionary: lectionary, fallback: seedFallback).isEmpty
    }

    /// Decodes installed calendar files once per reload, not on every view body.
    private func refreshCalendars() {
        guard installedCalendars.isEmpty else {
            cachedCalendars = CalendarCatalog.list(installed: installedCalendars)
            return
        }
        let root = DevotionLibrary.applicationSupport
        let installed = CalendarCatalog.installed(
            ids: packs.ids,
            catalog: PackFiles.loadCatalog(root: root)?.packs ?? [],
            root: root
        )
        cachedCalendars = CalendarCatalog.list(installed: installed)
    }
}

/// One or two lines naming the day in the liturgical calendar. The season ribbon stays on Today.
private struct CelebrationLine: View {
    let title: String

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(palette.emphasis.color)
                .frame(width: 3)
            Text(title)
                .font(AppFont.title(size: 22))
                .foregroundStyle(palette.foreground.color)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
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

    private var weekRows: Int {
        max(month.cells.count / 7, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            monthRow
                .padding(.horizontal, 12)
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
            HStack(spacing: 12) {
                PLButton(title: "Today", kind: .outline) {
                    selected = today
                    month = MonthPage.containing(today, firstWeekday: month.firstWeekday)
                }
                PLButton(title: "Use date", kind: .primary, action: onUse)
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.background.color)
        .tint(palette.primary.color)
        .fittedBottomSheet(key: "readings.month.\(weekRows)", estimate: 220 + CGFloat(weekRows) * 50)
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

    private var canGoBackMonth: Bool {
        month.canAdvance(by: -1, today: today)
    }

    private var canGoForwardMonth: Bool {
        month.canAdvance(by: 1, today: today)
    }

    private var monthRow: some View {
        HStack(spacing: 8) {
            stepButton(
                systemName: "chevron.left",
                label: "Previous month",
                enabled: canGoBackMonth
            ) {
                guard canGoBackMonth else { return }
                month = month.advanced(by: -1)
            }
            Text(month.title)
                .font(AppFont.heading(size: 28))
                .foregroundStyle(palette.foreground.color)
                .tracking(28 * AppFont.headingTrackingFactor)
                .frame(maxWidth: .infinity)
            stepButton(
                systemName: "chevron.right",
                label: "Next month",
                enabled: canGoForwardMonth
            ) {
                guard canGoForwardMonth else { return }
                month = month.advanced(by: 1)
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ date: CivilDate?) -> some View {
        if let date {
            let isSelected = date == selected
            let isAllowed = ReadingsDateWindow.contains(date, today: today)
            Button {
                guard isAllowed else { return }
                selected = date
            } label: {
                Text("\(date.day)")
                    .font(AppFont.interface(size: 16, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(
                        isSelected
                            ? palette.primaryForeground.color
                            : (isAllowed ? palette.foreground.color : palette.mutedForeground.color)
                    )
                    .frame(width: 40, height: 36)
                    .background(isSelected ? palette.primary.color : Color.clear, in: Capsule())
                    .frame(maxWidth: .infinity, minHeight: ControlMetrics.minimumHeight)
            }
            .buttonStyle(PressScaleButtonStyle())
            .disabled(!isAllowed)
            .accessibilityLabel(TodayPageBuilder.spokenDate(for: date))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        } else {
            Color.clear
                .frame(minHeight: ControlMetrics.minimumHeight)
        }
    }

    private func stepButton(
        systemName: String,
        label: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(enabled ? palette.foreground.color : palette.mutedForeground.color)
                .frame(minWidth: ControlMetrics.minimumHeight, minHeight: ControlMetrics.minimumHeight)
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

#Preview {
    ReadingsView()
        .environment(DesignPreferences())
        .environment(AppNavigation())
        .environment(ReadingsPreferences(defaults: UserDefaults(suiteName: "readings-preview") ?? .standard))
        .environment(InstalledPacks(defaults: UserDefaults(suiteName: "readings-preview") ?? .standard))
        .resolvePalette()
}
