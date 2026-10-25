# PerfectLiturgy iOS

This file is the product spec for the iPhone app. The Xcode project already exists. Implement the calendar, the screens, and the on-device stores described here.

Colour, type, and voice are in `DESIGN.md`. Domain words are in `GLOSSARY.md`. Payload shapes for packs, sign-in, and notices are in the three API files beside this one. Those four files plus this one are the whole spec.

| Need | File |
| :--- | :--- |
| Colour, type, voice | `DESIGN.md` |
| Domain words | `GLOSSARY.md` |
| Pack bodies, sync, bookmarks | `api-mobile-packs.md` |
| Sign-in and the auth return | `api-mobile-auth.md` |
| Notices | `mobile-notifications.md` |

`API_BASE_URL` and `AUTH_BASE_URL` default to `https://api.perfectliturgy.com`. A gitignored xcconfig may point both at an ngrok origin. The app calls `{AUTH_BASE_URL}/api/auth/...` and `{API_BASE_URL}/v1/...`. The auth return is `perfectliturgy://auth`.

Bundle id `com.perfectliturgy`. Display name PerfectLiturgy. iOS 17. SwiftUI.

## Product rules

| Topic | Rule |
| :--- | :--- |
| Languages | English and Latin ship in the app. The interface uses full names. Codes stay on pack ids and records. |
| Hymn names | `English Hymns`, `Latin Hymns`, `Efik Hymns`. The name is the language, not a publisher's book. |
| Signed out | Bundled English and Latin content opens with no Account. |
| Hymn updates | A newer live hymn pack downloads only while signed in. Signed out, the app shows a banner and keeps the copy already on the device. |
| Other languages | Downloading or syncing any pack that is not the bundled English or Latin set requires an Account when `requires_sign_in` is true. An omitted flag means gated. |
| Readings | Each translation is its own pack. `display_window` is `day`, `week`, or `month`. Verse text is stored only inside that window. Outside it, the screen shows the reference. |
| Calendar | The Roman rite is calculated on the device. A country pack replaces the celebration on the dates it marks. Reading slots stay Roman. |
| Mass Times | `https://mass-times.perfectliturgy.com` in a Safari view controller. No map and no schedule inside the app. |
| Donate | `https://perfectliturgy.com/donate` in a Safari view controller. |
| Account | One Account for this app, Android, and the web. Google, Apple, and email magic link. |
| Rights | Git, seeds, and tests use fixture lines such as `Test hymn one`. Production hymn, prayer, and Bible text is copied in at store-build time. |
| Size | Keep the release archive modest. The paired budget is 15 MB including English Hymns. |
| Admin fields | Never store `import_source`, `catalogue_id`, or rights follow-up columns. `background_notes` appears on the hymn page only, as "Catalogue note", and never on a list row. |
| Licence | A hymn is listed when `is_public_domain` or `permission_granted` is true. Hide the others. |

The shell, tab bar, More sheet, design tokens, and hymn store are already in the project. Keep them. The sections below are the behaviour still to fill in: Today, Readings, Saved, the devotion readers, Downloads, Account, and sync.

---

## Memory

Four stores. Pick the one that matches the lifetime of the data.

| Store | Keeps | Survives |
| :--- | :--- | :--- |
| App bundle | Seed JSON, `lectionary.json`, station images `station-01.webp` through `station-14.webp`, fonts | Reinstall replaces it |
| SwiftData | Hymns and sections, bookmarks, Bible verses, Bible versions | Relaunch, until the user removes the pack |
| Application Support | Downloaded Order of Mass, Rosary, Litanies, Stations, Prayers, and country-calendar JSON, plus the last pack catalog | Relaunch. Remove deletes that file |
| UserDefaults | Installed pack ids, stored revisions, appearance, heading scale, body scale, auto sync, chosen Bible version, chosen calendar, last 8 hymn visits | Relaunch |
| Keychain | Session token | Relaunch and reinstall of the same bundle id, until sign-out |

Navigation path, the open filter sheet, and the hymn search field live in memory for the session.

**Installed set.** These ids start installed, with their JSON in the bundle: `hymns-en`, `hymns-la`, `order-en`, `order-la`, `rosary-en`, `rosary-la`, `stations-en`, `stations-la`, `prayers-en`, `prayers-la`. English and Latin litanies ship as `litanies_en/litanies.json` and `litanies_la/litanies.json` and do not need catalog seed rows. Readings and country calendars are not bundled.

Import bundled hymns into SwiftData once. A second launch does not insert the same language and number again.

**Hymn row.** `id` (uuid; bookmarks use it), `language`, `hymnNumber` (unique inside that language, not across languages), `title`, `firstLine`, `lyrics`, sections (`id`, `type`, `label`, `content`), `meter`, `seasons`, `topics`, `scriptureReferences`, `tuneName`, `musicalKey`, `authors`, `massParts`, `videoURLs`, `audioURLs`, `sheetMusicURLs`, `isPublicDomain`, `permissionGranted`, `backgroundNotes`, `searchKey`. Section types: `verse`, `chorus`, `refrain`, `bridge`, `other`, and `response` when a pack sends it. `lyrics` may mirror the sections and is there for search. `updated_at` and `deleted_at` drive sync and are not shown.

Search key is the accent-folded lowercase join of title, first line, and lyrics. Folding strips combining marks. Display text stays as stored.

**Bookmark.** `hymnId`, `titleSnapshot`, `createdAt`. Newest first.

**Verse.** Identity is translation, book, chapter, and verse. Store the text once. A tombstone deletes that key. Translation id is the pack id without the `readings-` prefix.

**Hymn merge.** Language plus number is the natural key. A new number is inserted. The same number is updated in place, and its bookmark moves when the id changes. `deleted_at` removes that language and number, and its bookmark. One language never overwrites another.

**Pack files.** A static download is the envelope (`language` plus `data`) stored under the pack id. Readers load the bundled file first, then the Application Support file for that language. Sort by `order`.

**Preferences.** Appearance is System, Light, or Dark. Reading scales default to 1 and stay inside 0.8 to 1.4, with separate heading and body values. Auto sync defaults to on. Chrome, chips, and eyebrows stay at scale 1. Part titles and item titles follow the heading scale. Prayer and response text follows the body scale.

**Visits.** Opening a hymn records the last 8, newest first. No screen lists them yet.

**Sign-out** clears the Keychain token and stops gated sync. Hymns, verses, devotion files, bookmarks, and preferences stay.

---

## Liturgical calendar

Calculate the General Roman Calendar on the device. No country calendar is bundled. Optional memorials are omitted, so a weekday that only has a memorial shows the seasonal week.

### Easter and the seasons

Easter is the Gregorian computus for the civil year:

```text
a = year mod 19
b = year / 100
c = year mod 100
d = b / 4
e = b mod 4
f = (b + 8) / 25
g = (b - f + 1) / 3
h = (19a + b - d - g + 15) mod 30
i = c / 4
k = c mod 4
l = (32 + 2e + 2i - h - k) mod 7
m = (a + 11h + 22l) / 451
month = (h + l - 7m + 114) / 31
day = ((h + l - 7m + 114) mod 31) + 1
```

Integer division throughout.

- The First Sunday of Advent is the Sunday on or before 3 December.
- Christmas runs from 25 December through the Baptism of the Lord. Epiphany is 6 January. When Epiphany is a Sunday, the Baptism is 7 January. Otherwise the Baptism is the Sunday after 6 January.
- Advent runs from the First Sunday of Advent through 24 December.
- Lent runs from Ash Wednesday (46 days before Easter) until Easter, not including Easter.
- Easter season runs from Easter Sunday through Pentecost (49 days after Easter).
- Every other day is Ordinary Time.
- The Ascension is Easter plus 39 days (Thursday). Corpus Christi is Easter plus 60 days (Thursday). Trinity Sunday is Easter plus 56 days. The Sacred Heart is Easter plus 68 days. Christ the King is the Sunday one week before the First Sunday of Advent.

Seasonal names:

- Advent Sunday: `1st Sunday of Advent`, id `advent-sunday-1`, and so on through the 4th. Weekdays before 17 December: `Monday of the 1st week of Advent`, id `advent-feria-1-monday`. 17–24 December: `17 December`, id `advent-december-17`.
- Lent: Ash Wednesday id `ash-wednesday`. Days before the First Sunday of Lent: `Thursday after Ash Wednesday`, id `after-ash-thursday`. Sundays: `1st Sunday of Lent`, id `lent-sunday-1`. Later weekdays: `Monday of the 1st week of Lent`, id `lent-feria-1-monday`. Palm Sunday is Easter minus 7 days: `Palm Sunday of the Passion of the Lord`, red. The weekdays of Holy Week use `Monday of Holy Week`, id `holy-week-monday`.
- Easter: `Easter Sunday` id `easter-sunday`. Octave weekdays: `Monday within the Octave of Easter`, id `easter-octave-monday`. Later Sundays: `2nd Sunday of Easter`, id `easter-sunday-2`. Weekdays: `Monday of the 2nd week of Easter`, id `easter-feria-2-monday`. Pentecost is red, id `pentecost`.
- Ordinary Time Sundays: `29th Sunday in Ordinary Time`, id `ot-sunday-29`, week mark `XXIX`. Weekdays: `Monday of the 29th week in Ordinary Time`, id `ot-feria-29-monday`. The week after Pentecost uses the next numbered week, so the Wednesday after Pentecost 2026 is the 8th week. Christ the King closes the year as week 34.

Number an Ordinary Time Sunday from the Baptism (early year) or back from Christ the King (late year). The Sunday after the Baptism is the 2nd Sunday. The days between the Baptism and that Sunday are the 1st week. After Pentecost, the week number is one less than the following Sunday's slot when the previous Sunday is Pentecost itself.

### Rank, then country

Higher rank replaces the seasonal day. An impeded solemnity moves forward to the next day it can occupy. Saint Luke (18 October, red) shows on a weekday and yields to a Sunday.

| Rank | Priority |
| :--- | ---: |
| Feria | 0 |
| Memorial | 1 |
| Seasonal weekday | 2 |
| Required memorial | 3 |
| Feast | 4 |
| Sunday | 5 |
| Feast of the Lord | 6 |
| Solemnity | 7 |
| Privileged | 8 |
| Triduum | 9 |

Fixed solemnities, white, defer if impeded: Joseph 19 March, Annunciation 25 March, Nativity of John the Baptist 24 June, Peter and Paul 29 June, Assumption 15 August, All Saints 1 November, Immaculate Conception 8 December. All Souls is 2 November, purple, and also defers.

Feasts kept by this app, and omitted when a higher rank occupies the day: Conversion of Paul 25 January; Presentation of the Lord 2 February (feast of the Lord); Chair of Peter 22 February; Mark 25 April, red; Philip and James 3 May, red; Matthias 14 May, red; Visitation 31 May; Thomas 3 July, red; Mary Magdalene 22 July; James 25 July, red; Martha, Mary and Lazarus 29 July; Transfiguration 6 August (feast of the Lord); Lawrence 10 August, red; Bartholomew 24 August, red; Nativity of Mary 8 September; Exaltation of the Holy Cross 14 September, red, feast of the Lord; Matthew 21 September, red; Michael, Gabriel and Raphael 29 September; Luke 18 October, red; Simon and Jude 28 October, red; Dedication of the Lateran Basilica 9 November (feast of the Lord); Andrew 30 November, red.

The Monday after Pentecost is Mary, Mother of the Church, white, required memorial, id `mary-mother-of-the-church`. It does not defer.

A country day replaces the title, colour, and id for the date it matches. The id becomes `country-{id}`. The season stays. The week mark clears. `fromCountryCalendar` is true. The next day is unchanged. An annual feast matches month and day. A transferred day matches a full date. Marking 17 May as the Ascension shows that title on 17 May and leaves 14 May as the Ascension as well.

### Reading key and citations

`{celebrationId}|{Sunday cycle}|{weekday cycle}`.

The liturgical year is the civil year, and the next civil year on and after the First Sunday of Advent. Sunday cycle from that year: remainder 0 is A, 1 is B, 2 is C. Weekday cycle: an even year is II, an odd year is I. 18 October 2026 is `ot-sunday-29|A|II`. 29 November 2026 ends in `|B|I`.

`lectionary.json` in the bundle holds references only. Split the key on `|`. An Ordinary Time weekday (`ot-feria`) uses the feria table keyed by id plus weekday cycle. A seasonal feria (id starting `lent-feria`, `easter-feria`, `advent-feria`, `advent-december`, `christmas-january`, `christmas-octave`, `easter-octave`, `after-ash`, or `holy-week`) uses the proper table keyed by id. Every other day uses the Sunday table keyed by id plus Sunday cycle, then the proper table keyed by id.

Slots, in order: First reading, Responsorial psalm, Second reading when the day has one, Gospel acclamation, Gospel. Sundays keep the second reading. So do Christmas, Mary Mother of God, Epiphany, the Baptism, Holy Family, Holy Thursday, Good Friday, the Ascension, Pentecost, Trinity, Corpus Christi, the Sacred Heart, Christ the King, the Presentation, the Transfiguration, the Holy Cross, the Lateran, Joseph, the Annunciation, the Nativity of John, Peter and Paul, the Assumption, All Saints, the Immaculate Conception, and Ash Wednesday. Ordinary weekdays omit it. Holy Saturday omits it.

A passage shows verse text only when every cited verse for that slot is stored for the selected translation. Otherwise show the reference. Today shows references only.

### Dates the calendar must return

| Date | Celebration |
| :--- | :--- |
| 18 Oct 2026 | 29th Sunday in Ordinary Time, green, week mark XXIX, key `ot-sunday-29\|A\|II`, five slots |
| 11 Oct 2026 | 28th Sunday in Ordinary Time, week mark XXVIII |
| 18 Oct 2025 | Saint Luke, red |
| 19 Oct 2026 | Monday of the 29th week in Ordinary Time, green, no second reading |
| 25 Dec 2025 | The Nativity of the Lord, white |
| 6 Jan 2026 | The Epiphany of the Lord |
| 4 Jan 2026 | 2nd Sunday after the Nativity of the Lord |
| 11 Jan 2026 | The Baptism of the Lord |
| 12 Jan 2026 | Monday of the 1st week in Ordinary Time |
| 18 Feb 2026 | Ash Wednesday, purple |
| 29 Mar 2026 | Palm Sunday of the Passion of the Lord, red |
| 5 Apr 2026 | Easter Sunday, white |
| 14 May 2026 | The Ascension of the Lord |
| 17 May 2026 | 7th Sunday of Easter |
| 24 May 2026 | Pentecost Sunday, red |
| 4 Jun 2026 | The Most Holy Body and Blood of Christ |
| 7 Jun 2026 | 10th Sunday in Ordinary Time |
| 25 May 2026 | The Blessed Virgin Mary, Mother of the Church |
| 27 May 2026 | Wednesday of the 8th week in Ordinary Time |
| 1 Nov 2026 | All Saints, white, no week mark |
| 22 Nov 2026 | Our Lord Jesus Christ, King of the Universe |
| 23 Nov 2026 | Monday of the 34th week in Ordinary Time |
| 29 Nov 2026 | 1st Sunday of Advent, purple, key ending `\|B\|I` |
| 8 Dec 2024 | 2nd Sunday of Advent |
| 9 Dec 2024 | The Immaculate Conception of the Blessed Virgin Mary |

A country day for 18 October titled "Test patron", red, replaces only 18 Oct 2026. Its id is `country-test-patron`. 19 Oct 2026 stays the Monday of the 29th week. A country day dated 17 May 2026 titled "The Ascension of the Lord" shows that title on 17 May and leaves 14 May as the Ascension.

---

## Screens

Wide layout is width at least 840pt and height at least 600pt. Phone pushes a secondary screen. Wide layout keeps the hymn list and detail side by side, and centres Account at 560pt. The wordmark returns to Today. Buttons are at least 44pt and scale to 0.97 while pressed. Cards are flat, radius 4, 6, or 8, with no shadow.

Stanza fill is `#f8f4eb` in light and `#1b2a22` in dark. Refrain fill is `#edf0e7` and `#253a2e`. The liturgical banner is forest `#1f4d3b` with cream text and gold `#e3b25a` in both themes. Other colours and the Voice section come from `DESIGN.md`.

### Today

Uppercase date eyebrow, `EEEE · d MMMM yyyy`. Heading "Readings and Hymns for Mass today." Support line "Readings and saved Hymns in your languages." Forest banner with the celebration and week mark. "Today's readings" lists slot label and reference. "Open readings" selects the Readings tab. "For later" shows the first bookmark and opens that hymn, or opens Hymns when nothing is saved.

### Readings

Chips: Today, Tomorrow, Sunday, Past dates. Previous and next day. A month sheet picks a date. An options block chooses the Bible version and the liturgical calendar. With no stored version, the row says none is available yet and opens Downloads. "Manage Bible versions" opens Downloads. The calendar list is the built-in Roman calendar plus each installed country calendar. Passages are label, reference, and text when the local Bible is complete for that slot.

`metadata.display_window` is `day`, `week`, or `month`. Sync stores verse text for that window around the anchor. A week is Sunday through Saturday. A month is every day of the anchor's month. Dates outside the window keep references.

### Hymns

The search field stays visible. It accepts words, a hymn number (digits only), or a pasted id. Text matches the search key and section bodies. Filters combine with AND: installed language, one season, one Mass part. Empty language means every installed hymn language. Seasons: `advent`, `christmas`, `lent`, `easter`, `ordinary_time`. Mass parts: `entrance`, `offertory`, `communion`, `recessional`. Clear all resets the three filters in one tap. Debounce text 300ms. Page size 80. Search and filter run on the device. Opening Hymns may suggest the season of today's liturgical day. The person can dismiss that chip. The choice lasts for the session.

The filter sheet is titled "Filter hymns" and shows the match count. A row is number, title, first line, and a bookmark toggle.

Detail: number in terracotta, title, catalogue line (`English Hymns` plus season, Mass part, and topic labels), first line, then tune, key, and authors when present. Verse cards are titled `STANZA 1`, `STANZA 2`, and so on. Chorus, refrain, and response use the refrain card and the heading `CHORUS / REFRAIN` or `RESPONSE`. Bridge uses `BRIDGE`. When there are at least four verses and a refrain, chorus, or response exists, repeat that refrain once at the midpoint and once at the end. The stored order does not change. With no sections, show `lyrics` as one stanza. `backgroundNotes` is "Catalogue note" when present.

Audio plays in the page. YouTube and Vimeo play embedded. Other https links open outside the app. A PDF or image can preview as sheet music. Share text is the catalogue line, number, title, sections, and tune or key. A missing hymn says "Hymn unavailable" and "This hymn could not be opened from the local catalogue."

When a signed-out person has an installed live pack whose catalog revision differs from the stored revision, and the pack requires sign-in, show a banner that opens Account.

### Saved

Heading "Saved". Support "Keep what you want close at hand." Empty and signed out: "Save a hymn from its page. It stays on this device and opens here." Empty and signed in: "Save a hymn from its page. It syncs with your Account when you're online." A row shows the title, then the catalogue and first Mass part when the hymn's language is installed. A missing hymn keeps the title snapshot, says "Not on this device" or "Hymn pack removed from this device", and does not open. The row can remove the bookmark.

### Devotions

The language control lists only the installed languages of that pack type, named by the pack list, and offers Downloads. The default is English while it is installed, else the first listed. The choice is kept per pack type, across screens and launches, so Hymns in Latin leaves Prayers in English. Only Hymns adds "All languages". A missing language says it is not on the device and opens Downloads. Reading scales apply.

**Order of Mass.** Scroll parts. Each part has a title, optional summary, and items. An item has a title, optional rubric, optional text, and optional response. Newlines stay.

**Holy Rosary.** Mystery chips show the suggested days. Steps for the selected set:

1. Sign of the Cross ("AT THE CRUCIFIX"), Apostles' Creed ("HOLDING THE CRUCIFIX"), Our Father ("FIRST LARGE BEAD"), three Hail Marys ("FOR FAITH", "FOR HOPE", "FOR CHARITY"), Glory Be, Fatima Prayer.
2. For each mystery: announce it, Our Father, ten Hail Marys, Glory Be, Fatima Prayer.
3. Hail Holy Queen, concluding prayer, Sign of the Cross.

That is 81 steps. The meditation line is "Consider {mystery}. Hold this moment in prayer as you begin the decade." Drop a leading "The ", "La ", or "El " from the title. Show the set name, the mystery index, and a bead map for the ten Hail Marys.

**Stations.** List, then one station. Orders 1–14 use the bundled illustration. Show the title, the scripture citation, the meditation, and the prayer. The meditation is a reflection, not a scripture quotation.

**Litanies.** List, then one litany. A line is call and response. A line with no response is one full-width row.

**Special Prayers.** List, then one prayer. The body keeps newlines.

### Downloads

On open, `GET /v1/packs`. After the first success, list that catalog in this order: Daily Readings, Calendars, Hymns, Order of Mass, Rosary, Litanies, Stations of the Cross, Prayers. Before that success, show the seeded English and Latin rows. A row shows the display name, the size when present, and installed, downloading, or not installed.

Every pack can be removed, including English and Latin. Removal deletes the local body and drops the id. The next sync skips it. Download stores the body and the revision. Hymns use the merge above. Readings fill the local Bible. Static packs replace the language file the reader loads.

`requires_sign_in` omitted means gated. A gated pack with no session opens a sheet that leads to Account and does not store a body. 401 or 403 does the same. 404 says the pack is not available yet. Any other failure says to check the connection and try again.

Recommend a country pack from the device locale when the catalog has one.

### Settings and Account

Settings heading "Settings". Support "Set the reading surface to suit you." Appearance, then a live reading sample, then the two sliders, then Auto sync with "Only on Wi-Fi or an unmetered plan.", then an Account row.

Signed-out Account offers Google, Apple, and email magic link. Google and magic link use `ASWebAuthenticationSession` and return through `perfectliturgy://auth` with `session_token` in the query or `token` in the fragment. Confirm with `GET /api/auth/get-session` and store the token in the Keychain. Apple uses the native Sign in with Apple button. Signed-in Account shows the name and email, sign-out, sync, and a way to Saved.

After sign-in, `PUT /v1/bookmarks` with the local rows, then `GET /v1/bookmarks`, and merge by hymn id.

### More

Mass Times opens `https://mass-times.perfectliturgy.com` in a Safari view controller. Donate opens `https://perfectliturgy.com/donate` the same way. Both stay outside the app.

| Row | Subtitle |
| :--- | :--- |
| Order of Mass | Fixed Mass texts in your downloaded languages |
| Holy Rosary | Mysteries and a step-by-step guide |
| Stations of the Cross | Fourteen stations with reflections |
| Litanies | Saints, Our Lady, the Sacred Heart, and more |
| Special Prayers | A saved collection for daily life |
| Downloads | Manage languages and content packs |
| Settings | Appearance, text size, and sync |
| Account | Sign-in and sync |

---

## Sync and notices

Manual sync runs from Account and the top bar. For each installed live pack (`hymns`, `readings`), call download when no revision is stored, otherwise `GET /v1/packs/{id}/sync?since={revision}`. Skip static packs. When signed in, also merge bookmarks.

Auto sync, when on, runs only on an unmetered path (Wi-Fi, or an unmetered cellular plan), including when the app becomes active. Off means no scheduled sync. The manual control still runs on any connection. `BGAppRefreshTask` is a best-effort extra. iOS may delay or skip it.

Ask for notification permission. Register the APNs token with `POST /v1/devices` and `platform: ios`, and again after sign-in so the Account is attached. A signed-out registration is allowed. A tap opens a sheet over the current screen with the title, the body when present, and the image when `image` is an https URL. The screen underneath stays put. The payload shape is in `docs/mobile-notifications.md`. The server includes an `aps` alert as well as the data keys so a backgrounded phone can show a banner.

---

## Phases

The project already runs. Paste one prompt at a time, with this file, `DESIGN.md`, and `GLOSSARY.md`. Add the API file only when the prompt names it. Stop when that phase's **Done when** is true. Leave later phases alone.

### Phase 1 — Liturgical calendar and Today

**Goal.** The Roman day and its reading references work on the device, with no network and no verse text.

**Follow.** Liturgical calendar. Today, in Screens.

**Done when.**

- Swift tests pass for every date in the calendar table, including both country-day cases.
- Today shows the celebration and references for the device's date, with no verse text.

**Prompt:**

```text
Phase 1 only. PerfectLiturgy iOS. Implement the local General Roman Calendar and the Today screen from "Liturgical calendar" and "Today" in docs/mobile-app-brief.md. Swift tests for every date in that table, including both country-day cases. References only, no verse text, no network. Read DESIGN.md and GLOSSARY.md. Do not build Readings chrome, Downloads, Account, or sync.
```

### Phase 2 — Readings chrome

**Goal.** The person can move through dates and see references offline.

**Follow.** Readings, in Screens. Reading slots and the lectionary lookup in Liturgical calendar.

**Done when.**

- Tomorrow, Sunday, and a past date chosen from the month sheet all show the right celebration and references with no network.
- With no Bible version stored, the version row says none is available yet and opens Downloads.

**Prompt:**

```text
Phase 2 only. Readings screen from "Readings" in docs/mobile-app-brief.md: Today, Tomorrow, Sunday, Past dates, previous and next day, month sheet, Bible version and calendar options. Offline references only. No verse text and no pack download yet. Read DESIGN.md and GLOSSARY.md.
```

### Phase 3 — Saved and Settings

**Goal.** Bookmarks and preferences survive a relaunch.

**Follow.** Memory, for bookmarks and UserDefaults. Saved, and Settings and Account, in Screens. Account can say sign-in is not available yet.

**Done when.**

- A bookmark, the appearance, and both type scales are still set after the app is killed and opened again.
- A removed hymn pack leaves a greyed Saved row that shows the stored title and does not open.
- The body scale changes hymn text.

**Prompt:**

```text
Phase 3 only. Saved and Settings from docs/mobile-app-brief.md. Persist bookmarks, appearance, heading scale, and body scale as described in Memory. Greyed row when the hymn pack is gone. Account row can open a placeholder. No network. Read DESIGN.md and GLOSSARY.md.
```

### Phase 4 — Devotion readers

**Goal.** Order of Mass, Rosary, Stations, Litanies, and Special Prayers read offline in English and Latin.

**Follow.** Devotions, in Screens. Bundled files in Memory.

**Done when.**

- Each reader opens in English and in Latin with no network.
- A five-mystery rosary has 81 steps, locked by a unit test.
- A language that is not installed offers Downloads.
- The heading and body scales change the reader text.

**Prompt:**

```text
Phase 4 only. Bundled devotion readers from "Devotions" in docs/mobile-app-brief.md: Order of Mass, Holy Rosary (81 steps), Stations with bundled art, Litanies, Special Prayers. English and Latin offline. Language control offers Downloads. No pack HTTP. Read DESIGN.md and GLOSSARY.md.
```

### Phase 5 — Downloads

**Goal.** The catalog is live, and a pack can be installed or removed.

**Follow.** Downloads, in Screens. Product rules for the sign-in gate. `api-mobile-packs.md` for `GET /v1/packs` and `GET /v1/packs/{pack_id}/download`.

**Done when.**

- Downloads lists the live catalog when the API is reachable, and the seeded English and Latin rows when it is not.
- Removing `hymns-en` hides those hymns from search. Installing it again brings them back.
- A gated pack, while signed out, opens the sign-in sheet and does not store a body.

**Prompt:**

```text
Phase 5 only. Downloads from docs/mobile-app-brief.md and the catalog and download routes in docs/api-mobile-packs.md. Install, remove, and the sign-in gate. Hymns merge by language plus number. Static packs store for the Phase 4 readers. Readings may stay unapplied until Phase 6. Read DESIGN.md and GLOSSARY.md. No Account sign-in flow yet.
```

### Phase 6 — Verse text and country calendars

**Goal.** Today's verses appear when the translation pack has them. A country pack changes that date.

**Follow.** Verse, Readings, and the country-day rules. Readings section of `api-mobile-packs.md`.

**Done when.**

- An installed translation shows verse text for today when the payload includes those verses, and references only outside the display window.
- The same verse from two days is stored once.
- A test country day changes that date's celebration and leaves the next day on the Roman calendar.

**Prompt:**

```text
Phase 6 only. Apply readings packs into the local Bible and country calendars from docs/mobile-app-brief.md. Verse text only when every cited verse is stored and the date is inside display_window. Today stays references only. Read the readings and calendar sections of docs/api-mobile-packs.md, plus DESIGN.md and GLOSSARY.md.
```

### Phase 7 — Account

**Goal.** One Account works on this iPhone and on the web.

**Follow.** Settings and Account, in Screens. Keychain and sign-out in Memory. `api-mobile-auth.md`. Bookmark routes in `api-mobile-packs.md`.

**Done when.**

- Google or magic link signs in on a dev build, `get-session` succeeds, and the session is in the Keychain.
- A bookmark made while signed out is on the account after sign-in, and still on the device after sign-out.
- A gated pack downloads only while signed in. Sign-out leaves the installed body in place and blocks the next gated download.
- Bundled English and Latin content still opens with no session.

**Prompt:**

```text
Phase 7 only. Account from docs/mobile-app-brief.md and docs/api-mobile-auth.md. Google and magic link through ASWebAuthenticationSession, session in the Keychain, bookmark merge via the bookmarks routes in docs/api-mobile-packs.md. Native Sign in with Apple when the server accepts it. Sign-out keeps local content and stops gated download. Read DESIGN.md and GLOSSARY.md. No push and no background sync yet.
```

### Phase 8 — Sync, notices, Mass Times, and Donate

**Goal.** Live packs stay current, a notice opens over the current screen, and the two web links open in Safari.

**Follow.** Sync and notices. More, in Screens. `mobile-notifications.md`.

**Done when.**

- Manual sync applies a hymn delta and a readings delta, and a second sync with the same revision changes nothing.
- With auto sync on, a metered network does not start it. The manual control still can.
- A test notice shows a banner and, on tap, a sheet with the title and body over the screen that was already open.
- Mass Times opens `mass-times.perfectliturgy.com` in Safari. Donate opens `perfectliturgy.com/donate`.

**Prompt:**

```text
Phase 8 only. Sync, notices, Mass Times, and Donate from docs/mobile-app-brief.md. Live packs sync with since= the stored revision. Auto sync on unmetered networks only, plus BGAppRefreshTask. Register the device as platform ios. Notice sheet from docs/mobile-notifications.md. Mass Times and Donate in SFSafariViewController. Read DESIGN.md and GLOSSARY.md.
```
