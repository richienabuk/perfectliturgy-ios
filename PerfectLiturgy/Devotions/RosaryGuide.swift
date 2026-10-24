import Foundation

nonisolated enum RosaryBeadFocus: Equatable, Sendable {
    /// Announce, or the Our Father that opens the decade. No Hail Mary is current.
    case waiting
    /// The Hail Mary on this bead, from 1 to 10.
    case hailMary(Int)
    /// Glory Be and the Fatima prayer. All ten beads are complete.
    case complete
}

nonisolated struct RosaryStep: Equatable, Sendable, Identifiable {
    var index: Int
    var title: String
    var text: String
    var cue: String
    var isMeditation: Bool
    /// Zero-based decade, when this step belongs to one.
    var decade: Int?
    var mysteryTitle: String?
    var beads: RosaryBeadFocus?
    /// Label in the bead map, such as `HAIL MARY 2 OF 10`.
    var beadLabel: String?

    var id: Int { index }

    var kindLabel: String {
        isMeditation ? "MEDITATION" : "PRAYER"
    }
}

nonisolated enum RosaryGuide {
    static let stepCount = 81

    static func steps(prayers: RosaryPrayers, set: RosaryMysterySet) -> [RosaryStep] {
        var steps: [RosaryStep] = []
        func add(
            title: String,
            text: String,
            cue: String,
            meditation: Bool = false,
            decade: Int? = nil,
            mysteryTitle: String? = nil,
            beads: RosaryBeadFocus? = nil,
            beadLabel: String? = nil
        ) {
            steps.append(RosaryStep(
                index: steps.count,
                title: title,
                text: text,
                cue: cue,
                isMeditation: meditation,
                decade: decade,
                mysteryTitle: mysteryTitle,
                beads: beads,
                beadLabel: beadLabel
            ))
        }

        add(title: "Sign of the Cross", text: prayers.sign, cue: "AT THE CRUCIFIX")
        add(title: "Apostles' Creed", text: prayers.creed, cue: "HOLDING THE CRUCIFIX")
        add(title: "Our Father", text: prayers.ourFather, cue: "FIRST LARGE BEAD")
        add(title: "Hail Mary", text: prayers.hailMary, cue: "FOR FAITH")
        add(title: "Hail Mary", text: prayers.hailMary, cue: "FOR HOPE")
        add(title: "Hail Mary", text: prayers.hailMary, cue: "FOR CHARITY")
        add(title: "Glory Be", text: prayers.gloryBe, cue: "GLORY TO THE TRINITY")
        add(title: "Fatima Prayer", text: prayers.fatima, cue: "OPTIONAL PRAYER AFTER THE GLORY BE")

        for (offset, title) in set.titles.enumerated() {
            let number = offset + 1
            add(
                title: "Mystery \(number) · \(title)",
                text: meditationLine(for: title),
                cue: "ANNOUNCE THE MYSTERY AND TAKE A MOMENT TO REFLECT",
                meditation: true,
                decade: offset,
                mysteryTitle: title,
                beads: .waiting,
                beadLabel: "ANNOUNCE THE MYSTERY"
            )
            add(
                title: "Our Father",
                text: prayers.ourFather,
                cue: "BEGIN THIS DECADE",
                decade: offset,
                mysteryTitle: title,
                beads: .waiting,
                beadLabel: "OUR FATHER"
            )
            for bead in 1...10 {
                add(
                    title: "Hail Mary · \(bead) of 10",
                    text: prayers.hailMary,
                    cue: "ON THIS BEAD",
                    decade: offset,
                    mysteryTitle: title,
                    beads: .hailMary(bead),
                    beadLabel: "HAIL MARY \(bead) OF 10"
                )
            }
            add(
                title: "Glory Be",
                text: prayers.gloryBe,
                cue: "AFTER THE TENTH HAIL MARY",
                decade: offset,
                mysteryTitle: title,
                beads: .complete,
                beadLabel: "DECADE COMPLETE"
            )
            add(
                title: "Fatima Prayer",
                text: prayers.fatima,
                cue: "OPTIONAL PRAYER AFTER THE GLORY BE",
                decade: offset,
                mysteryTitle: title,
                beads: .complete,
                beadLabel: "DECADE COMPLETE"
            )
        }

        add(title: "Hail, Holy Queen", text: prayers.hailHolyQueen, cue: "CONCLUDING PRAYERS")
        add(title: "Concluding prayer", text: prayers.closing, cue: "CONCLUDING PRAYERS")
        add(title: "Sign of the Cross", text: prayers.sign, cue: "AT THE CRUCIFIX")
        return steps
    }

    /// `Consider the annunciation. Hold this moment in prayer as you begin the decade.`
    static func meditationLine(for title: String) -> String {
        "Consider \(spokenMystery(title)). Hold this moment in prayer as you begin the decade."
    }

    /// Drops a leading "The ", "La ", or "El ", then speaks the name after "the".
    static func spokenMystery(_ title: String) -> String {
        var name = title
        for prefix in ["The ", "La ", "El "] where name.hasPrefix(prefix) {
            name = String(name.dropFirst(prefix.count))
            break
        }
        guard let first = name.first else { return "the \(name)" }
        let lowered = first.lowercased() + name.dropFirst()
        return "the \(lowered)"
    }

    /// Joyful on Monday and Saturday, Sorrowful on Tuesday and Friday, Glorious on Wednesday and Sunday, Luminous on Thursday.
    static func suggestedID(weekday: Int) -> String {
        switch weekday {
        case 1, 4: "glorious"
        case 2, 7: "joyful"
        case 3, 6: "sorrowful"
        default: "luminous"
        }
    }

    static func suggestedID(on date: Date = .now, calendar: Calendar = .current) -> String {
        suggestedID(weekday: calendar.component(.weekday, from: date))
    }
}
