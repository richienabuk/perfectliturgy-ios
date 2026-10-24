# PerfectLiturgy

The Xcode project is this repository. App source is `PerfectLiturgy/`. Tests are `PerfectLiturgyTests/`. Add files in the existing groups: `App`, `Design`, `Hymns`, `Calendar`, `Readings`, `Packs`, `Devotions`, `Account`. Add `Sync` when a phase needs it.

SwiftUI, iOS 17, Swift 6, main actor by default, Swift Testing. Bundle id `com.perfectliturgy`. Display name PerfectLiturgy.

## Spec

`docs/mobile-app-brief.md` is the product spec. Read it with `docs/DESIGN.md` and `docs/GLOSSARY.md`. Open `docs/api-mobile-packs.md`, `docs/api-mobile-auth.md`, or `docs/mobile-notifications.md` only when the current phase names that payload.

1. Find the first phase whose **Done when** is still false in the app.
2. Build that phase only. Paste that phase's prompt.
3. Stop when that phase's **Done when** is true on a simulator build.

## Copy and content

Use glossary words in the interface. Show language names (`English`, `Latin`). Store codes (`en`, `la`) on pack ids and records.

Follow the Voice section in `docs/DESIGN.md`: short, plain sentences.

Commit fixture lines such as `Test hymn one`. Production hymn, prayer, and Bible text stays out of git.

The wordmark PDFs in the asset catalog are the site brand with Cinzel outlined. Phase 1 bundles the live fonts.

The `perfectliturgy` URL scheme is registered. `AuthReturn.handle` stays empty until the sign-in phase.
