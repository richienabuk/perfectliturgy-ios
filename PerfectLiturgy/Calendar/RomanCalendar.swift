import Foundation

/// The General Roman Calendar, calculated on the device. Optional memorials are omitted.
nonisolated enum RomanCalendar {
    static func day(on date: CivilDate, country: [CountryCelebration] = []) -> LiturgicalDay {
        let roman = romanDay(on: date)
        guard let match = country.first(where: { $0.matches(date) }) else { return roman }
        var replaced = roman
        replaced.id = "country-\(match.id)"
        replaced.title = match.title
        replaced.color = match.color
        replaced.weekMark = nil
        replaced.fromCountryCalendar = true
        return replaced
    }

    static func easter(year: Int) -> CivilDate {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = mod(19 * a + b - d - g + 15, 30)
        let i = c / 4
        let k = c % 4
        let l = mod(32 + 2 * e + 2 * i - h - k, 7)
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1
        return CivilDate(year: year, month: month, day: day)
    }

    /// The liturgical year is the civil year, and the next civil year on and after the First Sunday of Advent.
    static func liturgicalYear(for date: CivilDate) -> Int {
        let advent = firstSundayOfAdvent(year: date.year)
        return date >= advent ? date.year + 1 : date.year
    }

    static func firstSundayOfAdvent(year: Int) -> CivilDate {
        CivilDate(year: year, month: 12, day: 3).sundayOnOrBefore
    }
}

nonisolated extension RomanCalendar {
    private struct Celebration: Equatable {
        var id: String
        var title: String
        var color: LiturgicalColor
        var season: LiturgicalSeason
        var rank: LiturgicalRank
        var weekMark: String?

        func replaced(by proper: ProperCelebration) -> Celebration {
            Celebration(
                id: proper.id,
                title: proper.title,
                color: proper.color,
                season: season,
                rank: proper.rank,
                weekMark: nil
            )
        }
    }

    fileprivate struct ProperCelebration: Equatable {
        var id: String
        var title: String
        var color: LiturgicalColor
        var rank: LiturgicalRank
        var defers: Bool
    }

    private static func romanDay(on date: CivilDate) -> LiturgicalDay {
        var celebration = placed(on: date)
        if let transferred = transferredSolemnity(landingOn: date) {
            celebration = Celebration(
                id: transferred.id,
                title: transferred.title,
                color: transferred.color,
                season: celebration.season,
                rank: transferred.rank,
                weekMark: nil
            )
        }
        return LiturgicalDay(
            id: celebration.id,
            title: celebration.title,
            color: celebration.color,
            season: celebration.season,
            rank: celebration.rank,
            weekMark: celebration.weekMark,
            fromCountryCalendar: false,
            readingKey: readingKey(id: celebration.id, on: date),
            slots: slots(for: celebration.id, on: date)
        )
    }

    private static func placed(on date: CivilDate) -> Celebration {
        let seasonal = seasonal(on: date)
        guard let proper = proper(on: date), proper.rank > seasonal.rank else { return seasonal }
        return seasonal.replaced(by: proper)
    }

    /// An impeded solemnity moves forward to the next day it can occupy. Feasts are omitted instead.
    private static func transferredSolemnity(landingOn date: CivilDate) -> ProperCelebration? {
        let start = date.adding(days: -40)
        var scan = start
        var pending: [(CivilDate, ProperCelebration)] = []
        while scan <= date {
            if let item = deferrable(on: scan) {
                let base = placed(on: scan)
                if base.id != item.id, base.rank >= item.rank {
                    pending.append((scan, item))
                }
            }
            scan = scan.adding(days: 1)
        }

        var occupied: [CivilDate: ProperCelebration] = [:]
        for (natural, item) in pending {
            var probe = natural.adding(days: 1)
            let limit = natural.adding(days: 40)
            while probe <= limit {
                let occupant = occupied[probe]
                let rank = occupant?.rank ?? placed(on: probe).rank
                if rank < item.rank {
                    occupied[probe] = item
                    break
                }
                probe = probe.adding(days: 1)
            }
        }
        return occupied[date]
    }

    private static func readingKey(id: String, on date: CivilDate) -> String {
        let year = liturgicalYear(for: date)
        let sunday = SundayCycle(liturgicalYear: year).rawValue
        let weekday = WeekdayCycle(liturgicalYear: year).rawValue
        return "\(id)|\(sunday)|\(weekday)"
    }

    private static func slots(for id: String, on date: CivilDate) -> [ReadingSlot] {
        var slots: [ReadingSlot] = [.first, .psalm]
        if hasSecondReading(id: id, on: date) {
            slots.append(.second)
        }
        slots.append(contentsOf: [.acclamation, .gospel])
        return slots
    }

    private static func hasSecondReading(id: String, on date: CivilDate) -> Bool {
        if id == "holy-saturday" { return false }
        if date.weekday == .sunday { return true }
        return secondReadingIDs.contains(id)
    }

    /// Days that keep a second reading even when they are not a Sunday. Ordinary weekdays omit it.
    private static let secondReadingIDs: Set<String> = [
        "nativity",
        "mary-mother-of-god",
        "epiphany",
        "baptism",
        "holy-family",
        "holy-thursday",
        "good-friday",
        "ascension",
        "pentecost",
        "trinity",
        "corpus-christi",
        "sacred-heart",
        "christ-the-king",
        "presentation",
        "transfiguration",
        "holy-cross",
        "lateran",
        "joseph",
        "annunciation",
        "nativity-of-john",
        "peter-and-paul",
        "assumption",
        "all-saints",
        "immaculate-conception",
        "ash-wednesday",
    ]
}

nonisolated extension RomanCalendar {
    private static func seasonal(on date: CivilDate) -> Celebration {
        let easter = easter(year: date.year)
        let ash = easter.adding(days: -46)
        let pentecost = easter.adding(days: 49)
        let baptism = baptism(year: date.year)
        let advent = firstSundayOfAdvent(year: date.year)

        if date.month == 12, date.day >= 25 {
            return christmasDecember(date)
        }
        if date.month == 1, date <= baptism {
            return christmasJanuary(date, baptism: baptism)
        }
        if date >= advent {
            return adventDay(date, first: advent)
        }
        if date >= ash, date < easter {
            return lent(date, easter: easter, ash: ash)
        }
        if date >= easter, date <= pentecost {
            return easterSeason(date, easter: easter, pentecost: pentecost)
        }
        return ordinary(
            date,
            baptism: baptism,
            ash: ash,
            pentecost: pentecost,
            christTheKing: advent.adding(days: -7)
        )
    }

    private static func christmasDecember(_ date: CivilDate) -> Celebration {
        if date.day == 25 {
            return make("nativity", "The Nativity of the Lord", .white, .christmas, .solemnity)
        }
        if date == holyFamily(year: date.year) {
            return make(
                "holy-family",
                "The Holy Family of Jesus, Mary and Joseph",
                .white,
                .christmas,
                .feastOfTheLord
            )
        }
        return make(
            "christmas-octave-\(date.day)",
            "\(date.day) December",
            .white,
            .christmas,
            .seasonalWeekday
        )
    }

    private static func christmasJanuary(_ date: CivilDate, baptism: CivilDate) -> Celebration {
        if date.day == 1 {
            return make(
                "mary-mother-of-god",
                "Mary, the Holy Mother of God",
                .white,
                .christmas,
                .solemnity
            )
        }
        if date == CivilDate(year: date.year, month: 1, day: 6) {
            return make("epiphany", "The Epiphany of the Lord", .white, .christmas, .solemnity)
        }
        if date == baptism {
            return make("baptism", "The Baptism of the Lord", .white, .christmas, .feastOfTheLord)
        }
        if date.weekday == .sunday, (2...5).contains(date.day) {
            return make(
                "nativity-sunday-2",
                "2nd Sunday after the Nativity of the Lord",
                .white,
                .christmas,
                .sunday
            )
        }
        let epiphany = CivilDate(year: date.year, month: 1, day: 6)
        if date > epiphany, date < baptism {
            return make(
                "after-epiphany-\(date.weekday.slug)",
                "\(date.weekday.name) after the Epiphany",
                .white,
                .christmas,
                .seasonalWeekday
            )
        }
        return make(
            "christmas-january-\(date.day)",
            "\(date.day) January",
            .white,
            .christmas,
            .seasonalWeekday
        )
    }

    private static func adventDay(_ date: CivilDate, first: CivilDate) -> Celebration {
        let sunday = date.sundayOnOrBefore
        let week = first.days(until: sunday) / 7 + 1
        if date.weekday == .sunday {
            return make(
                "advent-sunday-\(week)",
                "\(ordinal(week)) Sunday of Advent",
                .purple,
                .advent,
                .privileged
            )
        }
        if date.month == 12, date.day >= 17 {
            return make(
                "advent-december-\(date.day)",
                "\(date.day) December",
                .purple,
                .advent,
                .seasonalWeekday
            )
        }
        return make(
            "advent-feria-\(week)-\(date.weekday.slug)",
            "\(date.weekday.name) of the \(ordinal(week)) week of Advent",
            .purple,
            .advent,
            .seasonalWeekday
        )
    }

    private static func lent(_ date: CivilDate, easter: CivilDate, ash: CivilDate) -> Celebration {
        let palm = easter.adding(days: -7)
        if date == ash {
            return make("ash-wednesday", "Ash Wednesday", .purple, .lent, .privileged)
        }
        if date == palm {
            return make(
                "palm-sunday",
                "Palm Sunday of the Passion of the Lord",
                .red,
                .lent,
                .privileged
            )
        }
        if date > palm {
            return holyWeek(date, easter: easter)
        }
        let firstSunday = ash.adding(days: 4)
        if date < firstSunday {
            return make(
                "after-ash-\(date.weekday.slug)",
                "\(date.weekday.name) after Ash Wednesday",
                .purple,
                .lent,
                .seasonalWeekday
            )
        }
        let sunday = date.sundayOnOrBefore
        let week = firstSunday.days(until: sunday) / 7 + 1
        if date.weekday == .sunday {
            return make(
                "lent-sunday-\(week)",
                "\(ordinal(week)) Sunday of Lent",
                .purple,
                .lent,
                .privileged
            )
        }
        return make(
            "lent-feria-\(week)-\(date.weekday.slug)",
            "\(date.weekday.name) of the \(ordinal(week)) week of Lent",
            .purple,
            .lent,
            .seasonalWeekday
        )
    }

    private static func holyWeek(_ date: CivilDate, easter: CivilDate) -> Celebration {
        if date == easter.adding(days: -3) {
            return make("holy-thursday", "Holy Thursday", .white, .lent, .triduum)
        }
        if date == easter.adding(days: -2) {
            return make("good-friday", "Good Friday", .red, .lent, .triduum)
        }
        if date == easter.adding(days: -1) {
            return make("holy-saturday", "Holy Saturday", .purple, .lent, .triduum)
        }
        return make(
            "holy-week-\(date.weekday.slug)",
            "\(date.weekday.name) of Holy Week",
            .purple,
            .lent,
            .seasonalWeekday
        )
    }

    private static func easterSeason(_ date: CivilDate, easter: CivilDate, pentecost: CivilDate) -> Celebration {
        if date == easter {
            return make("easter-sunday", "Easter Sunday", .white, .easter, .triduum)
        }
        if date == pentecost {
            return make("pentecost", "Pentecost Sunday", .red, .easter, .privileged)
        }
        let days = easter.days(until: date)
        if days < 7 {
            return make(
                "easter-octave-\(date.weekday.slug)",
                "\(date.weekday.name) within the Octave of Easter",
                .white,
                .easter,
                .seasonalWeekday
            )
        }
        let sunday = date.sundayOnOrBefore
        let week = easter.days(until: sunday) / 7 + 1
        if date.weekday == .sunday {
            return make(
                "easter-sunday-\(week)",
                "\(ordinal(week)) Sunday of Easter",
                .white,
                .easter,
                .privileged
            )
        }
        return make(
            "easter-feria-\(week)-\(date.weekday.slug)",
            "\(date.weekday.name) of the \(ordinal(week)) week of Easter",
            .white,
            .easter,
            .seasonalWeekday
        )
    }

    private static func ordinary(
        _ date: CivilDate,
        baptism: CivilDate,
        ash: CivilDate,
        pentecost: CivilDate,
        christTheKing: CivilDate
    ) -> Celebration {
        let week = ordinaryWeek(
            date,
            baptism: baptism,
            ash: ash,
            pentecost: pentecost,
            christTheKing: christTheKing
        )
        let mark = RomanNumeral.format(week)
        if date.weekday == .sunday {
            return Celebration(
                id: "ot-sunday-\(week)",
                title: "\(ordinal(week)) Sunday in Ordinary Time",
                color: .green,
                season: .ordinary,
                rank: .sunday,
                weekMark: mark
            )
        }
        return Celebration(
            id: "ot-feria-\(week)-\(date.weekday.slug)",
            title: "\(date.weekday.name) of the \(ordinal(week)) week in Ordinary Time",
            color: .green,
            season: .ordinary,
            rank: .seasonalWeekday,
            weekMark: mark
        )
    }

    private static func ordinaryWeek(
        _ date: CivilDate,
        baptism: CivilDate,
        ash: CivilDate,
        pentecost: CivilDate,
        christTheKing: CivilDate
    ) -> Int {
        if date > pentecost {
            let previous = date.sundayOnOrBefore
            if previous == pentecost {
                return sundaySlot(pentecost.adding(days: 7), christTheKing: christTheKing) - 1
            }
            return sundaySlot(previous, christTheKing: christTheKing)
        }
        let secondSunday = sundayAfter(baptism)
        if date < secondSunday { return 1 }
        let sunday = date.sundayOnOrBefore
        return 2 + secondSunday.days(until: sunday) / 7
    }

    /// Christ the King is week 34. Earlier Sundays count back from that Sunday.
    private static func sundaySlot(_ sunday: CivilDate, christTheKing: CivilDate) -> Int {
        34 - sunday.days(until: christTheKing) / 7
    }

    private static func sundayAfter(_ date: CivilDate) -> CivilDate {
        let delta = (8 - date.weekday.rawValue) % 7
        return date.adding(days: delta == 0 ? 7 : delta)
    }
}

nonisolated extension RomanCalendar {
    private static func proper(on date: CivilDate) -> ProperCelebration? {
        let found = [movableProper(on: date), fixedProper(month: date.month, day: date.day)].compactMap { $0 }
        return found.max { $0.rank < $1.rank }
    }

    private static func deferrable(on date: CivilDate) -> ProperCelebration? {
        guard let proper = proper(on: date), proper.defers else { return nil }
        return proper
    }

    private static func movableProper(on date: CivilDate) -> ProperCelebration? {
        let easter = easter(year: date.year)
        let advent = firstSundayOfAdvent(year: date.year)
        if date == easter.adding(days: 39) {
            return ProperCelebration(
                id: "ascension",
                title: "The Ascension of the Lord",
                color: .white,
                rank: .solemnity,
                defers: false
            )
        }
        if date == easter.adding(days: 56) {
            return ProperCelebration(
                id: "trinity",
                title: "The Most Holy Trinity",
                color: .white,
                rank: .solemnity,
                defers: false
            )
        }
        if date == easter.adding(days: 60) {
            return ProperCelebration(
                id: "corpus-christi",
                title: "The Most Holy Body and Blood of Christ",
                color: .white,
                rank: .solemnity,
                defers: false
            )
        }
        if date == easter.adding(days: 68) {
            return ProperCelebration(
                id: "sacred-heart",
                title: "The Most Sacred Heart of Jesus",
                color: .white,
                rank: .solemnity,
                defers: false
            )
        }
        if date == easter.adding(days: 50) {
            return ProperCelebration(
                id: "mary-mother-of-the-church",
                title: "The Blessed Virgin Mary, Mother of the Church",
                color: .white,
                rank: .requiredMemorial,
                defers: false
            )
        }
        if date == advent.adding(days: -7) {
            return ProperCelebration(
                id: "christ-the-king",
                title: "Our Lord Jesus Christ, King of the Universe",
                color: .white,
                rank: .solemnity,
                defers: false
            )
        }
        return nil
    }

    private static func fixedProper(month: Int, day: Int) -> ProperCelebration? {
        return switch (month, day) {
        case (1, 25):
            feast("conversion-of-paul", "The Conversion of Saint Paul", .white)
        case (2, 2):
            feastOfTheLord("presentation", "The Presentation of the Lord", .white)
        case (2, 22):
            feast("chair-of-peter", "The Chair of Saint Peter", .white)
        case (3, 19):
            solemnity("joseph", "Saint Joseph, Spouse of the Blessed Virgin Mary", .white)
        case (3, 25):
            solemnity("annunciation", "The Annunciation of the Lord", .white)
        case (4, 25):
            feast("mark", "Saint Mark", .red)
        case (5, 3):
            feast("philip-and-james", "Saints Philip and James", .red)
        case (5, 14):
            feast("matthias", "Saint Matthias", .red)
        case (5, 31):
            feast("visitation", "The Visitation of the Blessed Virgin Mary", .white)
        case (6, 24):
            solemnity("nativity-of-john", "The Nativity of Saint John the Baptist", .white)
        case (6, 29):
            solemnity("peter-and-paul", "Saints Peter and Paul", .white)
        case (7, 3):
            feast("thomas", "Saint Thomas", .red)
        case (7, 22):
            feast("mary-magdalene", "Saint Mary Magdalene", .white)
        case (7, 25):
            feast("james", "Saint James", .red)
        case (7, 29):
            feast("martha-mary-lazarus", "Saints Martha, Mary and Lazarus", .white)
        case (8, 6):
            feastOfTheLord("transfiguration", "The Transfiguration of the Lord", .white)
        case (8, 10):
            feast("lawrence", "Saint Lawrence", .red)
        case (8, 15):
            solemnity("assumption", "The Assumption of the Blessed Virgin Mary", .white)
        case (8, 24):
            feast("bartholomew", "Saint Bartholomew", .red)
        case (9, 8):
            feast("nativity-of-mary", "The Nativity of the Blessed Virgin Mary", .white)
        case (9, 14):
            feastOfTheLord("holy-cross", "The Exaltation of the Holy Cross", .red)
        case (9, 21):
            feast("matthew", "Saint Matthew", .red)
        case (9, 29):
            feast("archangels", "Saints Michael, Gabriel and Raphael", .white)
        case (10, 18):
            feast("luke", "Saint Luke", .red)
        case (10, 28):
            feast("simon-and-jude", "Saints Simon and Jude", .red)
        case (11, 1):
            solemnity("all-saints", "All Saints", .white)
        case (11, 2):
            solemnity("all-souls", "All Souls", .purple)
        case (11, 9):
            feastOfTheLord("lateran", "The Dedication of the Lateran Basilica", .white)
        case (11, 30):
            feast("andrew", "Saint Andrew", .red)
        case (12, 8):
            solemnity("immaculate-conception", "The Immaculate Conception of the Blessed Virgin Mary", .white)
        default:
            nil
        }
    }

    private static func solemnity(_ id: String, _ title: String, _ color: LiturgicalColor) -> ProperCelebration {
        ProperCelebration(id: id, title: title, color: color, rank: .solemnity, defers: true)
    }

    private static func feast(_ id: String, _ title: String, _ color: LiturgicalColor) -> ProperCelebration {
        ProperCelebration(id: id, title: title, color: color, rank: .feast, defers: false)
    }

    private static func feastOfTheLord(_ id: String, _ title: String, _ color: LiturgicalColor) -> ProperCelebration {
        ProperCelebration(id: id, title: title, color: color, rank: .feastOfTheLord, defers: false)
    }

    private static func baptism(year: Int) -> CivilDate {
        let epiphany = CivilDate(year: year, month: 1, day: 6)
        if epiphany.weekday == .sunday {
            return CivilDate(year: year, month: 1, day: 7)
        }
        return sundayAfter(epiphany)
    }

    private static func holyFamily(year: Int) -> CivilDate {
        let christmas = CivilDate(year: year, month: 12, day: 25)
        if christmas.weekday == .sunday {
            return CivilDate(year: year, month: 12, day: 30)
        }
        return sundayAfter(christmas)
    }

    private static func make(
        _ id: String,
        _ title: String,
        _ color: LiturgicalColor,
        _ season: LiturgicalSeason,
        _ rank: LiturgicalRank,
        weekMark: String? = nil
    ) -> Celebration {
        Celebration(id: id, title: title, color: color, season: season, rank: rank, weekMark: weekMark)
    }

    private static func ordinal(_ value: Int) -> String {
        let mod100 = value % 100
        if (11...13).contains(mod100) { return "\(value)th" }
        switch value % 10 {
        case 1: return "\(value)st"
        case 2: return "\(value)nd"
        case 3: return "\(value)rd"
        default: return "\(value)th"
        }
    }

    private static func mod(_ value: Int, _ divisor: Int) -> Int {
        let remainder = value % divisor
        return remainder >= 0 ? remainder : remainder + divisor
    }
}

nonisolated enum RomanNumeral {
    static func format(_ value: Int) -> String {
        let pairs = [
            (1000, "M"), (900, "CM"), (500, "D"), (400, "CD"),
            (100, "C"), (90, "XC"), (50, "L"), (40, "XL"),
            (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I"),
        ]
        var remainder = value
        var result = ""
        for (amount, symbol) in pairs where remainder >= amount {
            let count = remainder / amount
            result += String(repeating: symbol, count: count)
            remainder -= amount * count
        }
        return result
    }
}
