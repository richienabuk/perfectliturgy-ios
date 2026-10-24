# PerfectLiturgy

The Xcode project is this repository. App source is `PerfectLiturgy/`. Tests are `PerfectLiturgyTests/`. The brief's `ios/` path is stale. Add files in the existing groups: `App`, `Design`, `Hymns`, `Calendar`, `Readings`, `Packs`, `Devotions`, `Account`. Add `Sync` when a phase needs it.

SwiftUI, iOS 17, Swift 6, main actor by default, Swift Testing. Bundle id `com.perfectliturgy`. Display name PerfectLiturgy.

## One phase

Before a phase, read `tmp/mobile-app-brief-v2.md`, `tmp/DESIGN.md`, and `tmp/GLOSSARY.md`.

1. Find the first phase whose **Done when** is still false in the app.
2. Build that phase only. Later phases stay unread as work.
3. Stop when that phase's **Done when** is true on a simulator build.

Open a contract only when the phase names it:

| Need | File |
| :--- | :--- |
| Packs, downloads, sync, bookmarks | `tmp/api-mobile-packs.md` |
| Sign-in and the auth return | `tmp/api-mobile-auth.md` |
| Notices | `tmp/mobile-notifications.md` |

`tmp/mobile-app-brief.md` is the Android stage log. It does not describe this screen map.

## Copy and content

Use glossary words in the interface. Show language names (`English`, `Latin`). Store codes (`en`, `la`) on pack ids and records.

Follow the Voice section in `tmp/DESIGN.md`: short, plain sentences.

Commit fixture lines such as `Test hymn one`. Production hymn, prayer, and Bible text stays out of git.

The wordmark PDFs in the asset catalog are the site brand with Cinzel outlined. Phase 1 bundles the live fonts.

The `perfectliturgy` URL scheme is registered. `AuthReturn.handle` stays empty until the sign-in phase.
