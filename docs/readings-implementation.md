# Daily readings — implementation plan (iOS)

Status: **approved direction, ready for staged implementation on iOS.**
Scope: the full liturgical readings for a day (every Mass, every reading, alternatives, season-specific acclamations), shown in the language of the user's calendar, with Bible text read from a locally stored Bible version.
Related: [`api-mobile-packs.md`](./api-mobile-packs.md), [`GLOSSARY.md`](./GLOSSARY.md), [`DESIGN.md`](./DESIGN.md), [`mobile-app-brief.md`](./mobile-app-brief.md). The bundled lectionary file is `PerfectLiturgy/Calendar/lectionary.json`.

This is the iOS edition of the Android plan. **Both apps talk to the same server and read the same pack files, so the data contract is identical.** Only storage, code layout, UI, and stages differ.

| Section | Kind | Rule |
| :--- | :--- | :--- |
| §1 Decisions | Shared | Same decisions. Two rows are corrected for iOS |
| §2 What exists today | **iOS only** | Verified against this repo |
| §3 Bible by verse | Shared | Word for word |
| §4 Language model | Shared | Word for word |
| §5 Lectionary pack format | Shared | Word for word, plus new §5.9 (day key lookup) |
| §6 Worked example | Shared | Word for word |
| §7 Bible pack format | Shared | Word for word |
| §8 Local storage | **iOS only** | SwiftData and files instead of Room |
| §9 Render model | **iOS only** | Swift types |
| §10 API contract | Shared | Word for word, plus paging detail in §10.3 |
| §11 Implementation stages | **iOS only** | Stages I0 to I7 map to Android R0 to R7 |
| §12 Verification checklist | Shared, plus iOS checks | Same outcomes on both apps |
| §13 Decisions, §14 Open points | Both | iOS decisions and what to confirm with Android |

**Parity rule.** A change to a shared section is made in both documents on the same day, or it is not made. If the two apps disagree on a field, the server contract in §5, §7, and §10 wins.

Rules for this document and for the code it describes:

- All sample text is placeholder text (`Test …`). Real Bible, lectionary, theme, refrain, and formula text is never committed (see `AGENTS.md`).
- **The app is unpublished, so nothing here is kept for backward compatibility.** Old types, file shapes, and the window-based sync are removed, not adapted (§2).
- Licensing and rights are handled outside the app. The app only carries terms and disclaimers.
- Swift 6, main actor by default. Models, the resolver, and importers are `nonisolated` and `Sendable`. Database work runs on a `@ModelActor`, as `HymnCatalogueReader` does today.

## 1. Decisions in one page

| Question | Decision |
| :--- | :--- |
| Why is the acclamation phrase missing? | On Android the bundled `lectionary.json` had `"acclamation": ""` in 628 of 629 entries and the code skipped blank references. **On iOS the bundled file has a reference for every acclamation** (none blank), so the cause here is different: the app has no phrase model. It shows the verse reference only, with no "Alleluia" or Lent phrase. Both are fixed by `formulas.acclamation` (§5.4). |
| Lectionary data model | The ordered array of items per day from the source lectionary file (`docs/lectionary.json` in the Android repo, bundled here as `PerfectLiturgy/Calendar/lectionary.json`) becomes the model. Slots are open strings, the data decides the layout. No fixed five-slot enum. |
| Which language drives the screen? | **The calendar (lectionary) language**: headings, closing lines, acclamations, themes, incipits, reference display. The **Bible version language** drives only the passage text. |
| Closing ("The word of the Lord.") | Stored once per lectionary in a `formulas` table keyed by slot, with an optional per-item override. Never hard-coded in the app, never on every item. See §5.3. |
| Lent acclamation (and other seasons) | Phrases come from `formulas.acclamation` by season. **All phrases for the season are shown** so the user can pick which parish phrase to use. A per-item `refrain` can override the list. See §5.4. |
| Alternatives | **Kept as a structured `alternatives` list.** The English word "or" cannot be the contract in a localized pack, and alternative readings need their own incipit and theme. See §5.5. |
| `set` | Groups items into one Mass (vigil, night, dawn, day). It does not replace alternatives: a set chooses *which Mass*, alternatives choose *which form of one reading*. |
| Dot notation | **Removed everywhere.** Psalm stanzas are separate ranges (§5.6). |
| Citation parsing | **Removed from the app.** Every lectionary pack carries machine-readable `ranges` produced at the source. `reference` is a display string only. |
| Bible text vs text per day | Bible text per verse per version, with lectionary wrapper fields and optional per-item text overrides. See §3. |
| Partial verses and quotations | One optional `segments` array on the verse row carries both part letters and quote styling. See §7.3. |
| Book names | Verse rows carry a stable book id. Full name and short form are sent once per pack in `books`. |
| Bundled seed | The **Latin Rite** lectionary (citations, ranges, slot headings only). Never call it Roman Rite. Closings, acclamations, incipits, themes, and psalm/passage text arrive only with a calendar download. See §5.8. |
| Storage on iOS | Verses in a separate SwiftData `bible` store. Lectionary in JSON files with an in-memory cache. Hymns and bookmarks are not touched. See §8. |
| Parity with Android | One server contract, one pack format, one day key lookup (§5.9), one conformance fixture. Everything else is platform code. |
| Psalm text | Built from the selected Bible version until a calendar pack supplies a lectionary `text` override. |
| Default calendar | Seed is the default at first launch. After the user downloads the first calendar pack, that pack becomes the active calendar. See §8.3. |
| Lectionary delivery | Inside `calendar-{id}`, where `id` may be a language, country, or diocese. Download only. Lectionary wording is a download, not bundled. |

---

## 2. What exists today, and what is removed

Verified in this repo:

- **Verses are stored, but on the old window model.** `BibleVerseRecord` (`id = translation|book|chapter|verse`, `text`) and `BibleVersionRecord` (title, `windowRaw`, anchor date) are SwiftData models. `BibleLibrary.apply` drops every verse whose `date` is outside `display_window` (`VerseWindow`), and a full download deletes rows the payload does not mention. Book ids are English names (`isaiah`) from an alias table, not USFM ids.
- **Both models live in the `hymns` store** with `HymnRecord`, `HymnSectionRecord`, `Bookmark`, and `HymnVisit` (`HymnStore.schema`). There is no `VersionedSchema` or migration plan. If the store fails to open, `HymnStore` moves it aside and starts a new one, so **saved items on that device are lost**. That is the reason Bible data leaves this store (§8.1).
- **Citations are parsed on the device.** `ScriptureReference` parses English strings. It returns nil for a cross-chapter range and for "or", and it drops part letters. `BiblePassage.text` joins verses with a space and returns nil if any verse is missing.
- **Slots are fixed in code.** `ReadingSlot` is a five-case enum, and it is also the decoding type of `lectionary.json`, so one new slot value fails the whole file. `LiturgicalDay.slots`, `RomanCalendar.slots(for:on:)`, `hasSecondReading`, and `secondReadingIDs` decide the layout. Holy Saturday is special-cased. A day cannot hold two first readings, two Masses, or a long and short form. `LectionaryIndex.citations` keeps one reference per slot (first wins).
- **The lectionary is references only.** `Lectionary.load` reads the bundled `lectionary.json`: 750 day keys, 3,172 items, no `ranges`. All 3,172 references are non-blank, including the acclamation. The iOS app has no phrase, closing, incipit, or theme model, which is why it can only show a reference under "Gospel acclamation". 74 references contain "or", 53 contain "Cf.", 18 contain a bracket note, and 32 day keys have no acclamation item. These match the numbers in §5.5 and Stage I0, so it appears to be the same source as the Android `docs/lectionary.json`. Stage I0 confirms this with a file diff.
- **The day key lookup is correct and stays.** `LectionaryIndex.entries` and `properPrefixes` implement the Sunday, feria, and proper tables. They are written down as shared rules in §5.9.
- **Calendar packs hold celebration days only.** `CountryCalendar` decodes `days`, the file is written to Application Support, and `ReadingsView.calendars` re-reads and decodes every file each time the view body runs. `CalendarOption.roman` has id `roman`, title "Roman calendar", and the row detail says "The Roman rite".
- **Readings sync is one response.** `ContentSync.pullDelta` applies a single response and stores its `revision`. There is no paging. `PackInstaller` also writes the full readings JSON to Application Support, which nothing reads.
- **Preferences hold one value each.** `ReadingsPreferences` has one `calendarID` (default `roman`) and one `bibleVersionID`.
- **Rendering is plain text.** `ReadingText` takes one `String`. There is no quote style, no spans, no alternatives control, and no Mass set control.
- **Today builds from citations.** `TodayPageBuilder.page` returns `TodayReading(label, reference)` rows.
- **No update path for download packs.** `PackFiles.revision` is stored, but nothing compares it with the catalog `revision` for `mode: "download"` packs.

**Delete outright** (no facade, no adapter):

| Remove | Replaced by |
| :--- | :--- |
| `ScriptureReference`, `VersePoint`, `VerseWindow`, `VerseDate`, `BiblePassage` | `ranges` in the pack, `BibleReader` (§8.1) |
| `BibleLibrary` (window-based apply, full-download delete) | `BibleImporter` (§8.1, Stage I2) |
| `BibleVerseRecord`, `BibleVersionRecord` in the `hymns` store | `BibleVerse`, `BibleBook`, `BibleVersion` in the `bible` store |
| `ReadingSlot`, `ReadingCitation`, `LiturgicalDay.slots`, `RomanCalendar.slots`, `hasSecondReading`, `secondReadingIDs` | Items in the lectionary data (slot is a `String`) |
| `LectionaryIndex` (flat `{slot, reference}` reader) and `Lectionary.load` | `LectionaryStore` and `Lectionary` value types (§8.2). The key rules move to `LectionaryKey` (§5.9) |
| `CountryCalendar` (days-only decoder) | `CalendarPackReader` (days, formulas, tables) |
| `CalendarOption.roman`, id `roman`, "Roman calendar", "The Roman rite" | `latin-rite`, "Latin Rite" (§8.3). The stored id `roman` migrates once |
| `PackMetadata.displayWindow`, `VerseWindow` strings in docs | `versification`, `coverage_through`, `region` |
| `TodayReading` built from citations | Rows from `DayReadings` in reference-only mode |
| `PackInstaller`'s readings file write | Nothing. The Bible store is the only copy |
| `ContentSync.pullDelta`'s single-response readings branch | Paged delta in `ContentSync` (§10.3, Stage I6) |
| Readings parts of `BibleTests`, `ReadingsTests`, `CalendarTests`, `SyncTests`, `PackTests` | Rewritten for the new model (§11) |

**Keep:** `CivilDate`, the celebration calculation in `RomanCalendar` and the Roman `readingKey`, country-day matching, `ReadingsCursor`, `MonthPage`, the month sheet, the chips, `PackClient`, `PackID`, `PackFiles`, `InstalledPacks`, the sign-in gate, and `ReadingsPreferences` (extended).

**Rename.** The UI and pack metadata say **Latin Rite**. `RomanCalendar` becomes `LatinRiteCalendar` in Stage I0 so the type name matches the Android class. This is a compiler-checked rename and touches `CalendarTests` and `TodayView`. `mobile-app-brief.md` also says "Roman" in several places (§11, Stage I0).

**Schema change.** Dropping `BibleVerseRecord` and `BibleVersionRecord` from the `hymns` schema is an entity removal, which SwiftData migrates without a plan. It still runs through the `HymnStore` path that moves a failed store aside, so Stage I1 proves it on a file-backed store before anything else changes (§11).

---

## 3. Bible by verse, or text per day?

Rough numbers from the source lectionary file (first form of each reading, each key once):

| | Count |
| :--- | ---: |
| Readings (slot entries) | 3,172 |
| Verse references if stored per day | ~19,000 |
| Unique verses | ~9,800 |

Verse reuse is only about 2x, so deduplication is **not** the main reason. Both approaches are small (about 1 MB gzipped per version). The real reasons for verses:

| Concern | Bible per verse | Text per day |
| :--- | :--- | :--- |
| User switches version | Instant, offline | Separate full pack per version |
| Add a version | Publish verses once | Build ~3,200 reading blobs per version |
| Correct one verse | One row | Every day that cites it |
| Incremental delivery | `updated_at` delta | Needs date windows |
| Reuse (hymn scripture references, Stations) | Yes | No |
| Exact lectionary wording | **Not guaranteed** | Exact |

**Hybrid:** body text from the selected Bible version; wrapper fields (`incipit`, `theme`, `refrain`, closing, headings) from the lectionary; optional per-item `text` for passages or psalms a Bible version cannot reproduce, used when the user picks **Lectionary text** as the source.

The screen must say where the text comes from ("Text from {version}"). It must not present Bible text as the lectionary edition.

---

## 4. Language model

Two independent languages:

| | Source | Controls |
| :--- | :--- | :--- |
| **Calendar / lectionary language** | `calendar-{id}` pack, field `language` | Slot headings, closing lines, acclamation phrases, book reading titles, themes, incipits, psalm refrains, displayed reference, Mass-set names |
| **Bible language** | `readings-{version}` pack, field `language` (required) | Passage text only |

Why the calendar language wins: dioceses publish the calendar and lectionary in a local language (Igbo, Yoruba, Efik, English …), and the printed headings and closings belong to that edition. Showing an English "The word of the Lord." under an Igbo passage is wrong.

Reconciliation rules:

1. The active calendar pack declares `language`. The default Bible version is the installed version with the same `language`. The choice is remembered per calendar language.
2. Content owners guarantee that a Bible version exists for every calendar language. If none is installed, the screen shows the references and a download prompt.
3. If the user deliberately picks a Bible version in **another** language: the chrome stays in the lectionary language, the text appears in the Bible's language, and the `incipit` is **hidden** because it is lectionary-language text that would not fit the passage. A small "Text in {language}" note is shown.
4. Language codes for dialects use the same codes as the catalog (`efi`, `ig`, `yo`, `en`, `la`).

---

## 5. Lectionary pack format

One pack = one complete lectionary plus its local feast days, in one language. Packs are self-contained; there is no layering of a regional overlay on a base pack in the app. The app also ships a **Latin Rite** seed (citations and headings only, see §5.8), used until a calendar pack is downloaded.

### 5.1 Envelope

```json
{
  "pack_id": "calendar-ng-en",
  "type": "calendar",
  "language": "en",
  "revision": "2026-10-01T12:00:00.000Z",
  "metadata": { "region": "ng" },
  "data": {
    "days": [ ],
    "formulas": { },
    "sunday": { },
    "feria": { },
    "proper": { }
  }
}
```

- `days` is the existing country-day list (feast dates). It is unchanged by this document.
- `sunday`, `feria`, `proper` keep the structure of the source lectionary file: day key → ordered array of items.
- `pack_id` is free-form but stable. The `language` field, not the id, drives behavior.

### 5.2 Items

Each day key maps to an ordered array. Array order is order of proclamation. The same `slot` may repeat.

| Field | Type | Meaning |
| :--- | :--- | :--- |
| `slot` | string | `first`, `psalm`, `second`, `acclamation`, `gospel`. Open set: unknown values show their `label` or the raw slot |
| `reference` | string | Citation **as printed in this lectionary**. Display only. Never parsed by the app |
| `ranges` | array | Machine-readable form of `reference` (§5.7). Required when the item has a passage |
| `set` | string | Mass this item belongs to (`vigil`, `night`, `dawn`, `day`). Omitted for the single default Mass |
| `label` | string | Overrides the slot heading (e.g. `Reading 3` on Holy Saturday) |
| `incipit` | string | Opening phrase that is not Bible text |
| `theme` | string | The lectionary's one-line theme |
| `refrain` | string | Psalm response or acclamation phrase override |
| `refrain_ref` | string | Citation the refrain adapts, display only |
| `closing` | string | Overrides the slot's closing line from `formulas` |
| `cf` | boolean | The verse is adapted, shown as "Cf." |
| `alternatives` | array | Other forms of this reading (§5.5) |
| `text` | object | Lectionary-supplied body (§5.6) |

No field is read from the string `reference`. An item with a `reference` and no `ranges` shows the reference and "Text not available".

### 5.3 Formulas (headings, closings, titles)

Language-specific text that repeats across the lectionary is stored once:

```json
"formulas": {
  "sets": {
    "vigil": "Test Vigil Mass",
    "night": "Test Mass during the Night"
  },
  "slots": {
    "first":        { "label": "Test First Reading",  "closing": "Test closing." },
    "psalm":        { "label": "Test Responsorial Psalm" },
    "second":       { "label": "Test Second Reading", "closing": "Test closing." },
    "acclamation":  { "label": "Test Gospel Acclamation" },
    "gospel":       { "label": "Test Gospel",         "closing": "Test gospel closing." }
  },
  "book_titles": {
    "EPH": "Test: A reading from the Letter to the Ephesians",
    "MAT": "Test: A reading from the holy Gospel according to Matthew"
  },
  "acclamation": {
    "default": ["Test Alleluia"],
    "lent": ["Test Lent acclamation", "Test Lent alternative"]
  }
}
```

**Advice on where the closing lives.** It must live in the lectionary, not in app strings, because the app strings are the app's UI language and the closing is the lectionary's language. But it should **not** be repeated on each of the ~3,100 items: one correction would touch every item, and translations drift. So:

- Default: `formulas.slots.{slot}.closing`.
- Exception: the same `closing` field on an item overrides it (for unusual endings, e.g. Passion readings).
- If neither exists, **no closing line is shown**. The app never falls back to an English string.

`book_titles` is keyed by book id and lives in the lectionary, not the Bible pack, because "A reading from the Letter…" is lectionary language.

### 5.4 Acclamation by season

The acclamation phrase differs by season (an "Alleluia" form in most seasons, a different phrase in Lent, with several permitted alternatives). Parishes use those phrases interchangeably, so **every phrase for the season is offered** and the user chooses which one to display.

- The resolver takes the day's `LiturgicalSeason` (`ADVENT`, `CHRISTMAS`, `LENT`, `EASTER`, `ORDINARY_TIME`), lowercases it with underscores (`ordinary_time`), and looks up `formulas.acclamation[season]`, falling back to `default`.
- The value is an **ordered list of equal options**. The UI shows all of them (chips or a picker). The user's choice is remembered per calendar language and season, and falls back to the first list entry only until they choose.
- Layout: the selected phrase, then the verse (from `ranges`), then the same phrase again.
- An item `refrain` replaces the season list for that day (e.g. the Easter Vigil). Show that single phrase with no picker.
- Days with no acclamation in the lectionary simply omit the item. Do not synthesize one.
- Holy Week days and the Triduum take the season the calendar reports. If a lectionary wants a different phrase there, it sets `refrain`.
- Until a calendar pack with `formulas.acclamation` is installed, the seed has no phrases: show the verse reference (and Bible text if available) under the slot heading, with no surrounding phrase.

### 5.5 Alternatives

Of the 74 items in the source lectionary file that contain "or": 51 are a shorter form of the same reading (`or 4:1-7, 11-13`), 7 are the same book written out in full, and 16 are a different passage (`John 20:1-9 or Luke 24:13-35`).

Why not rely on the word "or" in `reference`:

1. "or" is an English word. A Yoruba, Igbo, or French lectionary cannot be split on it, so the app would need a language-specific parser.
2. A different passage needs its own `incipit` and `theme`. A John gospel and a Luke gospel do not open the same way. A single string has nowhere to hold them.

So the data keeps a structured list, and `reference` is for display only:

```json
{
  "slot": "gospel",
  "reference": "Test Gospel 20:1-9",
  "ranges": [{ "book": "JHN", "from": "20:1", "to": "20:9" }],
  "incipit": "Test incipit",
  "alternatives": [
    {
      "label": "Test: alternative reading",
      "reference": "Test Gospel 24:13-35",
      "ranges": [{ "book": "LUK", "from": "24:13", "to": "24:35" }],
      "incipit": "Test incipit two",
      "theme": "Test theme two"
    }
  ]
}
```

- The item itself is the default form. Each alternative is `{ reference, ranges, label?, incipit?, theme?, text? }`.
- Shorter forms use the same shape with a label like `Shorter form`. Their `incipit` and `theme` are inherited from the item when omitted.
- The UI shows a control per item that has alternatives. The choice is session state only.

### 5.6 Psalms and lectionary-supplied text

A psalm item is displayed as: refrain, stanza, refrain, stanza, …, refrain. No dot notation is used anywhere.

- Each entry in the psalm's `ranges` is **one stanza**. A stanza made of two non-adjacent ranges marks the second with `"continues": true`.

```json
{
  "slot": "psalm",
  "reference": "Test Psalm 1:1-2, 3, 4 and 6",
  "ranges": [
    { "book": "PSA", "from": "1:1", "to": "1:2" },
    { "book": "PSA", "from": "1:3", "to": "1:3" },
    { "book": "PSA", "from": "1:4", "to": "1:4" },
    { "book": "PSA", "from": "1:6", "to": "1:6", "continues": true }
  ],
  "refrain": "Test refrain line.",
  "refrain_ref": "Test Book 5:1"
}
```

- Default: stanzas are built from the selected Bible version using these ranges. Poetic line breaks come from `\n` in the verse `text`. The Latin Rite seed never ships psalm wording.
- Lectionary override: when a calendar pack supplies item `text` and the user has selected **Lectionary text** as the source, use that body instead of the Bible verses:

```json
"text": {
  "stanzas": [
    { "lines": ["Test psalm line one", "Test psalm line two"] },
    { "lines": ["Test psalm line three"] }
  ]
}
```

For non-psalm items, `text` is `{ "paragraphs": ["…", "…"] }`. The refrain is added by the UI between stanzas and is not duplicated in `stanzas`.

### 5.7 `ranges`

```json
{ "book": "EPH", "from": "4:32", "to": "5:8" }
```

- `book` is the stable id (§7.1).
- `from` and `to` are `chapter:verse` with an optional part letter (`8b`, `4a`). Inclusive. No chapter length is needed to cross a chapter.

| `from` | `to` | Meaning |
| :--- | :--- | :--- |
| `1:8b` | `1:10` | Verse 8 from part b to its end, then verses 9 and 10 |
| `1:3` | `1:4a` | Verse 3, then verse 4 up to the end of part a |
| `1:63c` | `1:63c` | Only part c |

Ranges are produced by a content script or the server, **not** by the app. A validation test (§10) rejects bad ranges before they ship.

### 5.8 What is bundled and what is downloaded

The bundled seed is the **Latin Rite** lectionary. Use that name in the UI and in pack metadata (`display_name: "Latin Rite"`). Do not call it Roman Rite.

| Content | Latin Rite seed | Downloaded `calendar-{id}` |
| :--- | :---: | :---: |
| Day keys, slots, order, sets, alternatives | yes | yes |
| `reference`, `ranges` | yes | yes |
| Slot headings (`formulas.slots.*.label`) | yes | yes |
| Closing lines | no | yes |
| Acclamation phrases (`formulas.acclamation`) | no | yes |
| `book_titles`, Mass set names | no | yes |
| `incipit`, `theme`, `refrain`, psalm/passage `text` | no | yes |
| Country days and local feasts | no | yes |

Until a calendar pack is installed, the app shows Latin Rite slot headings, references, and Bible text when a version is installed. There is no closing line, no acclamation phrase, no theme, and no incipit. Psalm stanzas come from the Bible version.

Calendar packs are `mode: "download"`. A lectionary correction is a new `revision`; the app re-downloads the pack (a few hundred KB). Download is the path for updates, so the `/sync` route is not used.

### 5.9 Day key lookup

Both apps compute the celebration and its cycles on the device, then look the day up in the **active calendar's** tables. These rules decide which items a date gets, so they are part of the shared contract.

The app builds a `readingKey` of `{celebrationId}|{sundayCycle}|{weekdayCycle}`, for example `ot-sunday-30|A|II`. Lookup, first hit wins:

1. `celebrationId` starts with `ot-feria`: `feria["{id}|{weekdayCycle}"]`.
2. `celebrationId` starts with one of `lent-feria`, `easter-feria`, `advent-feria`, `advent-december`, `christmas-january`, `christmas-octave`, `after-epiphany`, `easter-octave`, `after-ash`, `holy-week`: `proper[id]`.
3. Otherwise `sunday["{id}|{sundayCycle}"]` when it is non-empty, then `proper[id]`.

Cycles: the liturgical year is the civil year, plus one on and after the First Sunday of Advent. Sunday cycle is A when `year % 3 == 1`, B when `2`, C when `0`. Weekday cycle is I for an odd year and II for an even year.

A country day (`country-{id}`) replaces the title, colour, and id for display only. **Its reading key stays the Roman celebration's key.**

Conformance: Stage I0 produces a small fixture of `(date → readingKey, season)` pairs, including both country-day cases. Both apps' tests read the same fixture (§11).

---

## 6. Worked example: the Nigerian first reading

| Printed | Where it lives |
| :--- | :--- |
| `FIRST READING` | `formulas.slots.first.label` |
| Theme line under the heading | item `theme` |
| `A reading from the Letter of Saint Paul to the Ephesians` | `formulas.book_titles.EPH` |
| `(Ephesians 4: 32-5:8)` | item `reference` (display) and `ranges` |
| `Brethren:` | item `incipit` |
| Passage body | Bible verses `EPH 4:32` to `5:8` |
| `The word of the Lord.` | `formulas.slots.first.closing` |

```json
{
  "slot": "first",
  "reference": "Test Letter 4:32-5:8",
  "ranges": [{ "book": "EPH", "from": "4:32", "to": "5:8" }],
  "incipit": "Test incipit:",
  "theme": "Test theme line."
}
```

Rendered: heading, theme, book title, reference, then `incipit + " " + verse text …`, then the closing. If the lectionary changes the Bible wording (a pronoun replaced by a name, a dropped conjunction), that is an edit, not an incipit. Handle it with a per-item `text` override, not by guessing.

The psalm with `R/` is the §5.6 example.

---

## 7. Bible pack format

### 7.1 Book ids and `books`

Verse rows carry stable USFM-style ids (`GEN`, `PSA`, `ISA`, `MAT`, `EPH`, `1CO`, `SIR`, `WIS`, `BAR`, `1MA`, `2MA`, `ESG` for Greek Esther). Names differ by translation, so the pack sends one entry per book it contains:

```json
"books": [
  { "id": "EPH", "order": 49, "name": "Ephesians", "abbr": "Eph" }
]
```

`name` and `abbr` are in the **Bible's** language. The lectionary's displayed reference and its "A reading from…" titles come from the lectionary (§5), not from here.

### 7.2 Versification

The lectionary cites verses in one numbering. Some versions number psalms differently (psalm titles can count as verse 1 or 2; Hebrew and Vulgate psalm numbers). The server publishes verses **under the lectionary's numbering** and records it in `metadata.versification`. The client does no mapping. A version that cannot be aligned is not published as a readings pack.

### 7.3 `segments`: part letters and quotations

A verse can need two things: split points for partial citations (`4a`, `8b-10`), and formatting for quoted speech or quotations that Bibles set apart. Both are properties of stretches of text inside one verse, so one optional field carries both.

```json
{
  "book": "ISA",
  "chapter": 7,
  "verse": 14,
  "text": "Test narration. Test quoted words.",
  "segments": [
    { "t": "Test narration.", "part": "a" },
    { "t": " Test quoted words.", "part": "b", "style": "quote" }
  ],
  "updated_at": "2026-10-19T12:00:00Z",
  "deleted_at": null
}
```

| Field | Notes |
| :--- | :--- |
| `text` | Always present. The whole verse, plain. Used for search and as the fallback |
| `segments` | Optional. Ordered. `segments[].t` joined equals `text` exactly |
| `segments[].part` | Optional letter (`a`, `b`, …). If any segment has it, all do. Letters ascend. Several segments may share one part |
| `segments[].style` | Optional open string. Defined value: `quote`. Unknown values render as plain text |

Rules:

- A verse with no partial citations and no quoted text sends **no** `segments` (most rows).
- A whole verse that is quoted speech is one segment: `[{ "t": "…", "style": "quote" }]`.
- A quote spanning several verses is marked in each verse. The renderer merges consecutive quoted segments into one block.
- Nested quotation marks stay as characters in `text`. `style` is a flat marker.
- Poetic line breaks are `\n` in `text` and in segments.
- If a citation asks for part `b` and the verse has no `part` letters, the client shows the **whole verse** and marks it "full verse shown". It never invents a split.
- Why `style` and not `quote: true`: it can later carry other formatting (for example words of Christ) without a schema change.
- Why not offsets into `text`: character offsets differ between UTF-16 (Kotlin) and Unicode scalars (Swift).
- If the source text is USFM or USX, its `\qt` (quotation) and `\q` (poetry) markers map straight onto `style: "quote"` and `\n`.
- Server validation: `join(segments.t) == text`; part letters contiguous.

### 7.4 Verse row

| Field | Required | Notes |
| :--- | :---: | :--- |
| `book` | yes | Book id |
| `chapter` | yes | Integer ≥ 1 |
| `verse` | yes | Integer ≥ 1 |
| `text` | yes | Whole verse. `\n` for poetic lines |
| `segments` | no | §7.3 |
| `updated_at` | yes | UTC ISO-8601. Drives sync |
| `deleted_at` | no | Tombstone. Row removed on the device |

No `date`. A verse is not tied to a day.

---

## 8. Local storage (SwiftData and files)

Two kinds of data, two homes. Verses are many small rows read by range, so they go in SwiftData. The lectionary is one document per calendar, read whole, so it stays a file, as every other downloaded pack does on iOS.

| Data | Home | Why |
| :--- | :--- | :--- |
| Bible versions, books, verses | SwiftData, **its own `bible` store** | Range queries, upserts, tombstones. Re-downloadable, so a failed open is cheap |
| Lectionary and formulas (Latin Rite seed) | JSON file in the app bundle | Read-only, replaced by an app update. No import step |
| Lectionary and formulas (`calendar-{id}`) | JSON file in Application Support, decoded once and cached | Replace is one atomic file write. Remove is a file delete. About a few hundred KB |
| Calendar choice, Bible choice, acclamation choice | `UserDefaults` through `ReadingsPreferences` | Same as today |
| Pack revisions, installed ids | `UserDefaults` through `PackFiles` and `InstalledPacks` | Unchanged |

### 8.1 Bible store

`BibleStore.shared` is a second `ModelContainer`, file `Application Support/Bible/bible.store`, folder excluded from backup like `PackFiles.ensureFolder`. It is not part of `HymnStore`. Hymns, bookmarks, and visits are untouched by anything in this plan.

If the Bible store will not open, it is deleted and made again, and the app **clears the installed ids and stored revisions of every `readings-` pack** so Downloads shows them as not installed. A Bible store and a revision list that disagree is the one state this design must never reach. The same reconciliation runs at launch when an installed `readings-` pack has zero verses.

| Model | Unique key | Fields |
| :--- | :--- | :--- |
| `BibleVersion` | `id` (`rsvce`, from the pack id without `readings-`) | `packId`, `language`, `displayName`, `abbr`, `revision`, `versification`, `coverageThrough`, `installedAt` |
| `BibleBook` | `key` = `version\|book` | `versionID`, `bookID`, `order`, `name`, `abbr` |
| `BibleVerse` | `key` = `version\|book\|` + `pos` zero-padded to 6 digits | `versionID`, `bookID`, `pos`, `chapter`, `verse`, `text`, `segmentsJSON` (optional), `updatedAt` |

`pos = chapter * 1000 + verse`. A range read is one fetch:

```swift
#Predicate<BibleVerse> {
    $0.versionID == version && $0.bookID == book && $0.pos >= fromPos && $0.pos <= toPos
}
// sort by pos
```

Two iOS limits to respect:

- **No `#Index`.** That macro needs iOS 18 and the target is iOS 17. The only index is the `@Attribute(.unique)` key. Stage I1 measures a range read on a full-size fixture (about 35,000 placeholder rows across two versions). Budget: a whole day under 100 ms on a device. If the predicate above is too slow, query on the unique `key` instead (string range over the zero-padded key) before considering anything else.
- **Main actor.** Imports and reads run on a `@ModelActor` (`BibleImporter`, `BibleReader`) and return `Sendable` value types. A read returns `[StoredVerse]` (`chapter`, `verse`, `text`, `segments`), never a model object.

Import rules:

- **Download replaces the version, sync upserts.** A full download deletes the version's rows and inserts the payload inside one context, and saves once at the end. If decoding or insert throws, call `rollback()` so the old Bible is intact. A sync page upserts rows by `key` and deletes rows with `deleted_at`. Server tombstones make both paths end in the same place.
- Insert in chunks of about 2,000 rows and look up existing rows for a chunk with one fetch (`key IN chunk`), never one fetch per row.
- Store the pack `revision` in `PackFiles` only after the last page is applied. `BibleVersion.revision` is a copy for display.
- `segments` is stored as the JSON string from the pack. It is decoded when a verse is rendered.
- `remove` deletes the version, its books, and its verses, then clears the revision and installed id.

### 8.2 Lectionary files

Two sources, one reader.

| Source | Location | `calendar_id` |
| :--- | :--- | :--- |
| Latin Rite seed | App bundle, `lectionary-latin-rite.json` (Stage I0 output) | `latin-rite` |
| Downloaded calendar | `Application Support/<packs folder>/calendar-{id}.json` (the existing `PackFiles.file`) | the pack id |

`LectionaryStore` (an `actor`) decodes a file once into `Lectionary` (envelope, `formulas`, three item tables, `days`) and caches it by `(calendarID, revision)`. A new download invalidates its entry. The Readings view, Today, and the resolver all read the cache, so nothing decodes a file while a view body runs (`ReadingsView.calendars` does today).

- **Validate, then write.** `CalendarPackReader` decodes and checks the whole pack (§5, `ranges` shape, `from <= to`) before `PackInstaller` writes the file atomically. A pack that fails to decode leaves the old file in place. This is the "replace in one transaction" rule of the Android plan.
- Calendar packs on disk in the old days-only shape fail to decode. The calendar is then treated as not installed and its id is removed from `InstalledPacks` at launch.
- Slots are `String`. An unknown slot never fails the file.
- The seed's `language` and `display_name` must match the Android seed (§14).

### 8.3 Settings

`ReadingsPreferences`, all in `UserDefaults`:

- `calendarID`: default `latin-rite`. A stored `roman` migrates to `latin-rite` once.
  - After a calendar pack finishes installing, if it is the **only** installed calendar besides the seed, set `calendarID` to that pack.
  - If several are installed, keep the current choice and let the user switch in Reading options. Removing the active pack falls back to the remaining calendar if there is exactly one, otherwise to `latin-rite`.
  - This runs where the install result is handled (the Downloads screen), not inside `PackInstaller`, because `ReadingsPreferences` is an environment object.
- `bibleSelection`: a dictionary from calendar language to a version id or `lectionary`. It replaces the single `bibleVersionID`. A stored single value is used for the current calendar's language once, then dropped.
- `acclamationChoice`: a dictionary from `"{language}|{season}"` to the chosen phrase **text**. If the stored text is no longer in the list (a corrected pack), the first phrase is used. The UI still shows every phrase and highlights the first until the user chooses.
- Chosen reading alternative and Mass set: `@State` on the screen. Never stored.

### 8.4 Reading a day

1. `LatinRiteCalendar.day(on:country:)` returns the celebration, season, and `readingKey`. The country days come from the active calendar's `days`.
2. `LectionaryKey` (§5.9) finds the items in the active calendar. A missing key falls back to `latin-rite` **only if** the languages match. Otherwise the day is "Readings not available in this calendar".
3. Group by `set` in array order.
4. Per item: pick the form (default or an alternative). For each range, `BibleReader` returns the verses of the selected version. Psalms use Bible verses unless the item has `text` and the source is **Lectionary text**.
5. Apply `segments` (part slicing, quote spans), then `incipit` (unless §4 rule 3), then the closing and the full acclamation phrase list for the season.

The season key for `formulas.acclamation` is lowercase with underscores: `advent`, `christmas`, `lent`, `easter`, `ordinary_time`. `LiturgicalSeason.ordinary` is the Swift case, so it needs an explicit `formulaKey` property. Do not use `rawValue`, which is `ordinary`.

An option is **available** when the first and last verse of every range exist locally. The server publishes whole ranges atomically, so no gap sits between them. `coverage_through` is informational ("Readings available through …").

---

## 9. Render model

Value types, `nonisolated` and `Sendable`, built by `ReadingResolver` off the main actor. SwiftUI renders them.

```swift
nonisolated struct DayReadings: Equatable, Sendable {
    var key: String
    var sets: [ReadingSet]
}

nonisolated struct ReadingSet: Equatable, Sendable, Identifiable {
    var id: String?                 // nil for the single default Mass
    var label: String?
    var items: [ReadingItem]
}

nonisolated struct ReadingItem: Equatable, Sendable, Identifiable {
    var id: Int                     // position in the day, stable for the session
    var slot: String                // open string
    var label: String               // from formulas or item label
    var forms: [ReadingForm]        // [0] is the default form
    var refrain: String?
    var refrainRef: String?
    var acclamationPhrases: [String]  // empty unless slot is an acclamation. All shown for choice
    var selectedAcclamationIndex: Int // 0 until the user picks. Ignored when the list has 0 or 1 entries
    var closing: String?
    var cf: Bool
}

nonisolated struct ReadingForm: Equatable, Sendable {
    var label: String?              // nil for the default form
    var reference: String
    var bookTitle: String?          // from formulas.book_titles
    var theme: String?
    var incipit: String?
    var body: ReadingBody
}

nonisolated struct ReadingSpan: Equatable, Sendable {
    var text: String
    var style: String?              // "quote" or nil
}

nonisolated struct VerseText: Equatable, Sendable {
    var chapter: Int
    var verse: Int
    var spans: [ReadingSpan]
}

nonisolated enum ReadingBody: Equatable, Sendable {
    case passage(verses: [VerseText], fullVerseShown: Bool)
    case psalm(stanzas: [[VerseText]])
    case lectionary(paragraphs: [String], stanzas: [[String]])
    case unavailable(Reason)

    enum Reason: Equatable, Sendable { case noVersion, notDownloaded, missingVerses, noLectionary }
}
```

Notes for iOS:

- The Android `ReadingBody` and these cases carry the same data. `Unavailable` keeps the same four reasons.
- **Testability.** `ReadingResolver.resolve(day:lectionary:version:source:verses:)` is a pure function. `verses` is a small protocol, `VerseSource`, with `func verses(version:book:from:to:) async -> [StoredVerse]`. `BibleReader` implements it. Tests pass an in-memory fake. No test needs SwiftData except Stage I2.
- **Reference-only mode.** `resolve(…, includeText: false)` skips `verses` and returns the same structure with empty bodies. Today uses it (Stage I5).
- **Rendering quote spans.** `ReadingText` takes a `String` today and keeps doing so for every other screen. Readings adds `ReadingBlocksView`. It groups consecutive quote spans across verses into one block, and shows a quote block with a leading rule in `palette.emphasis` and the same body type as the passage. If `DESIGN.md` has no quote token, add one there first, then in `Palette`.
- `ReadingScale` (the user's body size) applies to passage, psalm, and quote text through the same `readingScale` environment value.

---

## 10. API contract

Everything keeps the conventions of [`api-mobile-packs.md`](./api-mobile-packs.md): catalog, `/download`, `requires_sign_in`, `revision`, gzip. Both apps use exactly this section.

### 10.1 Bible pack: catalog row

```json
{
  "pack_id": "readings-rsvce",
  "type": "readings",
  "language": "en",
  "display_name": "RSVCE",
  "revision": "2026-10-20T09:15:03.421Z",
  "size": 1200000,
  "requires_sign_in": false,
  "mode": "live",
  "metadata": { "versification": "lectionary", "coverage_through": "2026-12-31" }
}
```

`language` is required for readings packs. `display_window` is removed.

### 10.2 Bible pack: `GET /v1/packs/readings-{version}/download`

```json
{
  "pack_id": "readings-rsvce",
  "type": "readings",
  "language": "en",
  "revision": "2026-10-20T09:15:03.421Z",
  "metadata": { "versification": "lectionary", "coverage_through": "2026-12-31" },
  "books": [ { "id": "EPH", "order": 49, "name": "Ephesians", "abbr": "Eph" } ],
  "data": [
    { "book": "EPH", "chapter": 4, "verse": 32, "text": "Test verse text.",
      "updated_at": "2026-10-19T12:00:00Z", "deleted_at": null },
    { "book": "ISA", "chapter": 7, "verse": 14, "text": "Test narration. Test quoted words.",
      "segments": [
        { "t": "Test narration.", "part": "a" },
        { "t": " Test quoted words.", "part": "b", "style": "quote" }
      ],
      "updated_at": "2026-10-19T12:00:00Z", "deleted_at": null }
  ]
}
```

### 10.3 Bible pack: `GET /v1/packs/readings-{version}/sync?since=…`

Same envelope. `data` holds only rows with `updated_at > since`, including tombstones.

- Equal `since` and catalog `revision`: empty `data`.
- Page by a stable cursor ordered by `(updated_at, book, chapter, verse)` so equal timestamps are never lost at a page boundary.
  - Request: `GET /v1/packs/readings-{version}/sync?since=…&cursor=…`. `cursor` is omitted on the first page and is an opaque string from the previous response.
  - Response: the same envelope, plus `"next_cursor": "…"` while more rows remain and `null` (or absent) on the last page. `revision` is the same on every page of one run.
  - A `since` that equals the catalog `revision` returns empty `data` and no `next_cursor`.
  - A page holds at most a few thousand rows, so one response stays under a few MB.
- `books` is included when it changed.
- The client stores `revision` only after **every** page has been applied.

### 10.4 Calendar / lectionary pack: `GET /v1/packs/calendar-{id}/download`

Envelope and body per §5. `mode: "download"`. Catalog row:

```json
{
  "pack_id": "calendar-ng-en",
  "type": "calendar",
  "language": "en",
  "display_name": "Nigeria · English",
  "revision": "2026-10-01T12:00:00.000Z",
  "requires_sign_in": false,
  "mode": "download",
  "metadata": { "region": "ng" }
}
```

### 10.5 Server publishing rules

1. Verse rows are published in whole lectionary ranges. Never a range with a missing verse.
2. Coverage grows in liturgical order, nearest dates first. Each batch bumps `revision`.
3. `join(segments.t) == text`; part letters contiguous; versification matches the lectionary.
4. Every `ranges` entry in a calendar pack uses a book id that exists in the Bible book list, and `from <= to`.
5. Every calendar `language` has at least one Bible pack with the same `language`.
6. No admin-only fields.
7. Once coverage is complete, a new install gets everything in one request.

---

## 11. Implementation stages

Follow `AGENTS.md`: one stage at a time, verify exit criteria before moving on. Every stage ends with a simulator build and the tests for that stage:

```text
xcodebuild test -scheme PerfectLiturgy -destination 'platform=iOS Simulator,name=<an installed iPhone>'
```

These stages replace the display-window parts of Phase 6 in `mobile-app-brief.md`. Stage numbers map to the Android plan: I0 = R0, I1 = R1, and so on.

| iOS | Android | What differs |
| :--- | :--- | :--- |
| I0 | R0 | Same content output, plus a conformance fixture and spec edits |
| I1 | R1 | Separate Bible store, no Room migration, lectionary stays a file |
| I2 | R2 | `@ModelActor` importer, paged `ContentSync` |
| I3 | R3 | File-based calendar pack, `LectionaryStore` cache |
| I4 | R4 | Pure resolver over a `VerseSource` |
| I5 | R5 | SwiftUI, Today card included |
| I6 | R6 | `PackInstaller`, `ContentSync`, calendar updates |
| I7 | R7 | Same server work |

### Stage I0 — Content tooling, seed, conformance, spec edits

0. Diff `PerfectLiturgy/Calendar/lectionary.json` against the Android source file. They should be identical. Any difference is a content bug to settle before converting.
1. **Do not fork the content script.** The Android R0 script converts the shared source into the §5 format. Run that same script and take its two outputs: the **Latin Rite seed** and the **sample calendar pack** with formulas. If the script is not ready, this stage waits for it.
2. Add the seed to the app bundle as `PerfectLiturgy/Calendar/lectionary-latin-rite.json`. The old `lectionary.json` stays until Stage I5 because the current Today and Readings screens still decode it. The content fixes listed in R0 apply (Holy Saturday as separate `first` and `psalm` items, Nativity as four `set` groups, Easter and Pentecost vigils, the 32 days without an acclamation). In this repo those 32 keys include `nativity|A`, `nativity|B`, `nativity|C`, `pentecost|A` to `C`, `assumption`, `holy-cross`, `holy-week-monday` to `holy-week-wednesday`, and `advent-feria-1-tuesday`.
3. Add the sample calendar pack and a **conformance fixture** under `PerfectLiturgyTests/Fixtures/`: `(date → celebration id, season, readingKey)` pairs, including both country-day cases from the brief, and a few expected resolver outputs (item count per set, phrase list for a Lent day). Android reads the same file.
4. Rename `RomanCalendar` to `LatinRiteCalendar` and change the UI strings "Roman calendar" and "The Roman rite" to "Latin Rite" (§2).
5. Edit the specs the new model replaces, in this order:
   - `mobile-app-brief.md`: the calendar table row ("Reading slots stay Roman"), the Application Support and UserDefaults rows, "Liturgical calendar" (lectionary lookup and slots, now data-driven), "Readings" (options, `display_window` paragraph), and Phase 6.
   - `api-mobile-packs.md`: the readings catalog metadata (`display_window`), the readings sync response (`date`, `part`, `display_window`), and the calendar pack body.
   - `GLOSSARY.md`: add Lectionary, Mass set, Alternative reading, Acclamation phrase.

Exit: a test reads every seed item, checks each `ranges` entry against the book list (§7.1), `from <= to`, and no empty `reference` with `ranges`. The date fixture passes against `LatinRiteCalendar`. Seed `display_name` is `Latin Rite`. App and tests build with the old readings code still in place (nothing is deleted yet).

### Stage I1 — Models and stores, window code removed

1. Add `BibleVersion`, `BibleBook`, `BibleVerse` (§8.1) and `BibleStore.shared`.
2. Remove `BibleVerseRecord` and `BibleVersionRecord` from `HymnStore.schema`. Add the launch reconciliation that clears `readings-` installed ids and revisions when the Bible store is empty or was reset.
3. Add `Lectionary` value types (`String` slots), `LectionaryStore`, `LectionaryKey` (§5.9), and the seed reader. They sit beside the old `LectionaryIndex`, which keeps Today and Readings working until Stage I5.
4. Delete the window-based Bible code: `BibleLibrary`, `BiblePassage`, `ScriptureReference`, `VersePoint`, `VerseWindow`, `VerseDate`. `ReadingsView` shows references only until Stage I5, as it did in Phase 2. The readings branches in `PackInstaller` and `ContentSync` are skipped until Stage I2, so a readings pack cannot be installed between the two stages. Tests that cannot compile are rewritten, not commented out.
5. Measure a range read on a generated fixture of about 35,000 placeholder verses (§8.1).

Tests:

- A file-backed `hymns` store created with the **old** schema (a test-only copy of the two removed models) opens with the new schema and still returns its bookmarks, hymns, and visits.
- The seed decodes. `LectionaryKey` returns the same item counts as the old `LectionaryIndex` for the existing `CalendarTests` dates, so nothing regresses before the new model is used.
- The Bible store opens, reads a range, and a forced open failure resets it and clears the `readings-` ids and revisions.

Exit: tests pass. A device or simulator that had the old build keeps its saved items.

### Stage I2 — Bible pack import (`Readings`, `Sync`)

1. `BiblePackReader` decodes `books`, `segments`, `metadata`, `language`, and rows (snake case, as `PackClient` does).
2. `BibleImporter` (`@ModelActor`): download replaces the version in one save with rollback on failure; a page upserts and tombstones (§8.1).
3. `BibleReader` (`@ModelActor`): range reads returning `[StoredVerse]`; `isAvailable(ranges:)` checks the first and last verse of each range.
4. Cursor-paged sync loop (§10.3). `PackClient.sync` gains an optional `cursor`.

Tests: fixture with `segments`; tombstone; a later sync changes one verse; an interrupted sync keeps the old `revision` and a re-run completes; relaunch (a second container on the same file) keeps verses; a failed download leaves the previous Bible intact.

### Stage I3 — Calendar pack import

1. `CalendarPackReader` parses the §5 envelope and validates it. `CountryCalendar` stays only until its last caller moves in Stage I5.
2. `PackInstaller` writes the calendar file atomically only after validation. Nothing else is stored.
3. `CalendarOption` carries `id`, `title`, `language`, and `celebrations`. The list is the seed plus each installed calendar. `ReadingsPreferences` migrates `roman` to `latin-rite`, and gets the per-language Bible choice and the acclamation choice (§8.3).
4. Auto-select the first downloaded calendar when it is the only one besides the seed.

Tests: valid pack installs and replaces; invalid pack leaves the old file; the old days-only shape is rejected and its id is removed; auto-select and fallback after remove; `roman` migrates.

### Stage I4 — Resolver (`Readings`)

1. `ReadingResolver` builds `DayReadings` from date, calendar, Bible choice, and source.
2. Season phrase list (`LiturgicalSeason.formulaKey`), closing lookup, incipit rules (§4), psalm stanzas from the Bible with the lectionary `text` override, `segments` slicing and quote spans, full-verse fallback.

Tests: the same list as Android R4, run on `VerseSource` fakes: one Holy Saturday day with seven first readings and seven psalms in order; Christmas with four sets; a Lent day returns every Lent phrase and an Ordinary Time day returns every default phrase; a seed-only day has an empty phrase list; first reading with incipit, theme, book title, and closing; psalm with a `continues` range; gospel with a different-passage alternative; partial verse with and without `part` letters; quoted spans merging across verses; language mismatch hides the incipit; missing verse returns `unavailable`; missing closing formula shows no closing. Plus the conformance fixture's resolver expectations.

### Stage I5 — UI (`Readings`, `Calendar`, `Design`)

1. `ReadingsView` loads a `DayReadings` with `.task(id:)` keyed on date, calendar, Bible choice, and source, and cancels on change. Show every set and item in order. A segmented control for Mass sets when there is more than one.
2. Alternatives control per item (a `Menu`, labelled with the form's `label`).
3. Reading layout: heading, theme, book title, reference, incipit and text, closing. Psalm: refrain and stanzas from the Bible, or lectionary `text` when selected. Acclamation: chips for the phrase list when it has more than one entry, then the selected phrase, the verse, and the phrase again.
4. Quote styling per `DESIGN.md` through `ReadingBlocksView` (§9).
5. States: no Bible version, version not downloaded, missing verses, "full verse shown", "Text in {language}", seed-only (no closing, no acclamation phrase), "Readings not available in this calendar".
6. Reading options block: the Bible version menu gains **Lectionary text** when the active calendar has item `text`. The calendar menu lists Latin Rite plus installed calendars. Row details say "Latin Rite" and "Local solemnities and feasts".
7. Today: `TodayPageBuilder` uses the resolver in reference-only mode. It shows the first set. When a day has several Masses, a last row reads "{n} Masses. Open readings." and selects the Readings tab.
8. Accessibility: labels on the reference, the Mass set control, the alternatives menu, and the phrase chips. Layouts follow Dynamic Type and the user's body scale. No fixed heights on text.
9. Delete what the new screens replace, including the old bundled `lectionary.json`: `ReadingSlot`, `ReadingCitation`, `LiturgicalDay.slots`, `RomanCalendar.slots`, `hasSecondReading`, `secondReadingIDs`, `LectionaryIndex`, `Lectionary.load`, `TodayReading`, `CountryCalendar`, and the old readings and calendar tests.

Exit: simulator build; manual check of Holy Saturday, a Sunday, a Lent weekday, and Christmas on a phone width and a wide layout.

### Stage I6 — Downloads and sync wiring

1. `PackInstaller` applies `readings` through `BibleImporter` and `calendar` through `CalendarPackReader`. It no longer writes the readings JSON file. `remove` deletes the version rows and the calendar file, clears revisions and installed ids.
2. `ContentSync.pullDelta` loops pages until the cursor ends, stores `revision` only after the last page, and maps `401/403` to sign-in as it does now.
3. **Calendar updates.** Sync, and the Wi-Fi job that reuses it, also re-download an installed `mode: "download"` calendar whose catalog `revision` differs from the stored one. Today nothing does this. Order: live packs first, then calendars.
4. `PackMetadata` loses `displayWindow` and gains `versification`, `coverageThrough`, and `region`. Downloads shows "Readings available through …" from `coverageThrough`.
5. `SyncCopy` already says "hymns and readings". Calendar updates fold into the same copy.

Tests: updated `SyncTests` and `PackTests` for the paged flow, a calendar update by revision, a gated pack without a token, and the `readings-` reconciliation.

### Stage I7 — Server (outside this repo)

Implement §10, including §10.5 and the paging contract in §10.3. The Android stage R7 is the same work. It is done once for both apps.

---

## 12. Verification checklist

Items 1 to 13 are the same outcomes on both apps. Run them on each.

1. The bundled seed is labeled **Latin Rite** (never Roman Rite), in the UI, in pack metadata, and in the type name.
2. With the seed only: headings, references, and Bible text appear; no closing, no acclamation phrase, no theme, no incipit. Psalms use Bible verses.
3. After the first calendar download, that calendar becomes the active one automatically.
4. The gospel acclamation offers every phrase for the season; the user can switch among them. Lent shows the Lent list, other seasons show the default list.
5. Holy Saturday shows every Vigil reading in order, each followed by its psalm.
6. Christmas shows four Masses.
7. A reading with a shorter form or an alternative passage shows a control; the alternative's own incipit and theme appear.
8. The closing line is in the calendar's language. With no formula it is absent, never English.
9. Changing the Bible version changes the text instantly, offline.
10. A part citation (`4a`, `8b`) shows the right segment, or the whole verse with the indicator.
11. Quoted verses render with the quote style and merge across consecutive verses.
12. With the seed only and no Bible installed, the app shows headings, references, and a download prompt.
13. No copyrighted text in tests, fixtures, or assets.

iOS-only:

14. The date fixture and the resolver expectations from Stage I0 pass in this app and in Android for the same file.
15. Hymns, bookmarks, and visits survive the upgrade from a build with the old Bible models.
16. Resetting the Bible store shows every readings pack as not installed, never as installed with no text.
17. Interrupting a Bible sync (airplane mode mid-pack) keeps the old text and the old revision; the next sync finishes.
18. A calendar pack with a newer catalog `revision` is replaced by Sync without a manual remove and install.
19. Readings render at the largest body size and at the largest Dynamic Type size without clipping. VoiceOver reads reference, Mass set, alternative, and phrase controls.
20. The Bible store and calendar files are excluded from device backup.

---

## 13. Decisions

Resolved (shared):

1. New lectionary fields, `segments`, and `books`: approved.
2. Country and language lectionaries ship inside `calendar-{id}`: approved, with `language` as the driver.
3. Licensing is handled outside the app.
4. Lectionary wording is a user download, not bundled.
5. Bundled seed is the **Latin Rite** lectionary (citations, ranges, slot headings only). Closings, acclamations, incipits, themes, and psalm/passage text arrive only with a calendar download. Psalms use Bible verses until a calendar supplies `text`.
6. The first downloaded calendar becomes the default when it is the only installed calendar besides the seed.
7. All season acclamation phrases are shown for the user to choose; the choice is remembered per calendar language and season.

Resolved (iOS, proposed in this document):

8. Bible data gets its own SwiftData store, separate from hymns and bookmarks, because the hymn store moves itself aside when it fails to open.
9. The lectionary is a file with an in-memory cache, not SwiftData. Downloaded calendars use the existing pack folder.
10. A full Bible download replaces the version; a sync page upserts. Both rely on server tombstones for deletes.
11. The acclamation choice is stored as the phrase text, with a fallback to the first phrase.
12. `RomanCalendar` is renamed `LatinRiteCalendar`.
13. Today shows the first Mass and a line for the others.
14. Sync also refreshes installed calendar packs by revision.

---

## 14. Open points to confirm

Confirm these once, then record the answer in both documents.

1. **Seed language.** The seed's headings are English. Both apps should declare the same `language` (`en` is assumed) and `display_name` `Latin Rite`, because §8.4 falls back to the seed only when languages match.
2. **Paging parameter names.** §10.3 names the cursor parameter `cursor` and the response field `next_cursor`. The Android plan says "a stable cursor" without names. The server needs one answer.
3. **Android day key lookup.** Check that Android's resolver follows §5.9 exactly, including the seasonal prefix list and the rule that a country day keeps the Roman key.
4. **Conformance fixture location.** One file, copied into both repos or hosted next to the server. Pick one.
5. **Type rename.** If you prefer to keep the Swift name `RomanCalendar`, drop step 4 of Stage I0. The UI strings still change.
