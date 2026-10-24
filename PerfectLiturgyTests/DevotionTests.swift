import Foundation
import Testing
@testable import PerfectLiturgy

private let samplePrayers = RosaryPrayers(
    sign: "Test sign.",
    creed: "Test creed.",
    ourFather: "Test our father.",
    hailMary: "Test hail mary.",
    gloryBe: "Test glory.",
    fatima: "Test fatima.",
    hailHolyQueen: "Test hail holy queen.",
    closing: "Test closing."
)

private let joyful = RosaryMysterySet(
    order: 1,
    id: "joyful",
    title: "Joyful",
    days: "Monday and Saturday",
    titles: [
        "The Annunciation",
        "The Visitation",
        "La Natividad",
        "El Nacimiento",
        "The Finding",
    ]
)

@Test func `a five mystery rosary has 81 steps`() {
    let steps = RosaryGuide.steps(prayers: samplePrayers, set: joyful)
    #expect(steps.count == 81)
    #expect(steps.count == RosaryGuide.stepCount)
    #expect(steps.map(\.index) == Array(0..<81))

    #expect(steps[0].title == "Sign of the Cross")
    #expect(steps[0].cue == "AT THE CRUCIFIX")
    #expect(steps[0].text == "Test sign.")
    #expect(steps[1].cue == "HOLDING THE CRUCIFIX")
    #expect(steps[2].cue == "FIRST LARGE BEAD")
    #expect(steps[3].cue == "FOR FAITH")
    #expect(steps[4].cue == "FOR HOPE")
    #expect(steps[5].cue == "FOR CHARITY")
    #expect(steps[7].cue == "OPTIONAL PRAYER AFTER THE GLORY BE")

    #expect(steps[8].isMeditation)
    #expect(steps[8].kindLabel == "MEDITATION")
    #expect(steps[8].text == "Consider the annunciation. Hold this moment in prayer as you begin the decade.")
    #expect(steps[8].beads == .waiting)
    #expect(steps[10].beads == .hailMary(1))
    #expect(steps[19].beads == .hailMary(10))
    #expect(steps[20].beads == .complete)
    #expect(steps[22].mysteryTitle == "The Visitation")
    #expect(steps[22].text.contains("the visitation"))

    let hailMarys = steps.filter { $0.cue == "ON THIS BEAD" || $0.cue == "FOR FAITH" || $0.cue == "FOR HOPE" || $0.cue == "FOR CHARITY" }
    #expect(hailMarys.count == 53)
    #expect(steps.filter { $0.beads == .hailMary(1) }.count == 5)

    #expect(steps[78].title == "Hail, Holy Queen")
    #expect(steps[79].title == "Concluding prayer")
    #expect(steps[80].title == "Sign of the Cross")
    #expect(steps[80].beads == nil)
}

@Test func `the meditation drops a leading article`() {
    #expect(RosaryGuide.meditationLine(for: "The Annunciation") == "Consider the annunciation. Hold this moment in prayer as you begin the decade.")
    #expect(RosaryGuide.meditationLine(for: "La Anunciación") == "Consider the anunciación. Hold this moment in prayer as you begin the decade.")
    #expect(RosaryGuide.meditationLine(for: "El Nacimiento") == "Consider the nacimiento. Hold this moment in prayer as you begin the decade.")
}

@Test func `today's mysteries follow the weekday`() {
    #expect(RosaryGuide.suggestedID(weekday: 1) == "glorious")
    #expect(RosaryGuide.suggestedID(weekday: 2) == "joyful")
    #expect(RosaryGuide.suggestedID(weekday: 3) == "sorrowful")
    #expect(RosaryGuide.suggestedID(weekday: 4) == "glorious")
    #expect(RosaryGuide.suggestedID(weekday: 5) == "luminous")
    #expect(RosaryGuide.suggestedID(weekday: 6) == "sorrowful")
    #expect(RosaryGuide.suggestedID(weekday: 7) == "joyful")
}

@Test func `a language that is not installed offers downloads`() {
    let missing = DevotionLanguageChoice(requested: "la", installed: ["en"])
    #expect(missing.offersDownloads)
    #expect(missing.message == "Latin is not on this device.")
    #expect(missing.active == "en")

    let unknown = DevotionLanguageChoice(requested: "efi", installed: ["en", "la"])
    #expect(unknown.offersDownloads)
    #expect(unknown.message == "This language is not on this device.")

    let ready = DevotionLanguageChoice(requested: nil, installed: ["la", "en"])
    #expect(!ready.offersDownloads)
    #expect(ready.active == "en")
    #expect(ready.buttonTitle == "English")

    let none = DevotionLanguageChoice(requested: nil, installed: [])
    #expect(none.offersDownloads)
    #expect(none.buttonTitle == "Language")
}

@Test func `english and latin devotion packs open offline`() throws {
    for kind in DevotionKind.allCases {
        for language in ["en", "la"] {
            let body = try #require(DevotionLibrary.load(kind, language: language, supportRoot: emptySupport()))
            #expect(body.language == language)
            #expect(!body.isEmpty)
        }
    }
    guard case .rosary(_, let pack) = DevotionLibrary.load(.rosary, language: "en", supportRoot: emptySupport()) else {
        Issue.record("English rosary did not load")
        return
    }
    let set = try #require(pack.mysteries.first { $0.titles.count == 5 })
    #expect(RosaryGuide.steps(prayers: pack.prayers, set: set).count == 81)
}

@Test func `parts and lines sort by order`() throws {
    let json = """
    {"language":"en","data":[{"order":2,"title":"Second","items":[{"order":2,"title":"Later","text":"Line one\\nLine two"},{"order":1,"title":"Earlier"}]},{"order":1,"title":"First","summary":"Gather.","items":[]}]}
    """
    let body = try #require(DevotionLibrary.decode(.order, data: Data(json.utf8)))
    guard case .order(_, let parts) = body else {
        Issue.record("Expected an order pack")
        return
    }
    #expect(parts.map(\.title) == ["First", "Second"])
    #expect(parts[1].items.map(\.title) == ["Earlier", "Later"])
    #expect(parts[1].items[1].text == "Line one\nLine two")
}

@Test func `an application support file replaces the bundle`() throws {
    let root = emptySupport()
    let url = root.appending(path: "rosary-en.json")
    let json = """
    {"language":"en","data":{"prayers":{"sign":"Support sign.","creed":"C","our_father":"F","hail_mary":"H","glory_be":"G","fatima":"P","hail_holy_queen":"Q","closing":"K"},"mysteries":[{"order":1,"id":"joyful","title":"Joyful","days":"Monday and Saturday","titles":[{"order":1,"title":"The Annunciation"},{"order":2,"title":"The Visitation"},{"order":3,"title":"The Nativity"},{"order":4,"title":"The Presentation"},{"order":5,"title":"The Finding"}]}]}}
    """
    try json.write(to: url, atomically: true, encoding: .utf8)
    guard case .rosary(_, let pack) = DevotionLibrary.load(.rosary, language: "en", supportRoot: root) else {
        Issue.record("Support rosary did not load")
        return
    }
    #expect(pack.prayers.sign == "Support sign.")
    #expect(RosaryGuide.steps(prayers: pack.prayers, set: pack.mysteries[0]).count == 81)
}

@Test func `reader text follows the heading and body scales`() {
    let small = ReadingScale(headings: 0.8, body: 0.8)
    let large = ReadingScale(headings: 1.4, body: 1.4)
    #expect(large.size(for: DevotionText.part) > small.size(for: DevotionText.part))
    #expect(large.size(for: DevotionText.item) > small.size(for: DevotionText.item))
    #expect(large.size(for: DevotionText.prayer) > small.size(for: DevotionText.prayer))
    #expect(large.size(for: DevotionText.response) > small.size(for: DevotionText.response))
    #expect(DevotionText.part == .partTitle)
    #expect(DevotionText.prayer == .prayer)
}

@Test func `litanies start installed with english and latin`() throws {
    let suite = "devotion-packs-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defaults.removePersistentDomain(forName: suite)
    let packs = InstalledPacks(defaults: defaults)
    #expect(packs.languages(for: .litanies) == ["en", "la"])
    #expect(packs.languages(for: .stations) == ["en", "la"])
    packs.remove("rosary-la")
    #expect(packs.languages(for: .rosary) == ["en"])
    let choice = DevotionLanguageChoice(requested: "la", installed: packs.languages(for: .rosary))
    #expect(choice.offersDownloads)
}

private func emptySupport() -> URL {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "pl-devotions-\(UUID().uuidString)", directoryHint: .isDirectory)
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}
