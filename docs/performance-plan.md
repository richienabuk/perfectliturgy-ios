# Performance plan: hymns list and navigation

Symptoms:

- Changing the language filter on the Hymns screen lags.
- Scrolling the hymn list lags.
- Pushing a hymn feels slow.

Rule for every step: `body` reads stored values and does no filtering, sorting, disk reads, or database fetches. Heavy work runs once, when its input changes, and never during a scroll or transition.

Do the steps in order. Each step has a prompt to paste into an AI agent. Build and run the whole `PerfectLiturgyTests` target after each step. Do not use `-only-testing:PerfectLiturgyTests/HymnTests`: the tests are free Swift Testing functions, that filter matches none of them, and `xcodebuild` still reports success. Profile on a Release build on a device (see Step 7).

---

## Step 1. Compute the filtered list once (DONE)

**Problem.** `HymnsView.filtered` was a computed property. Inside its `catalogue.filter { … }` closure it read `filter`, which read `activeLanguage`, which read `languages`. That is a full pass over the catalogue, a `Set`, and a sort, repeated for every hymn. One evaluation cost about N² operations. `body` evaluated it about six times, and every row that scrolled in evaluated it twice more through `onAppear`.

**Fix.** `HymnListModel` (in `PerfectLiturgy/Hymns/HymnListModel.swift`) stores `catalogue`, `languages`, `activeLanguage`, and `filtered`. It recomputes them only in `refilter(_:)`. The view calls `refilter` when the language, season, Mass part, installed packs, or debounced query changes, and calls `setCatalogue` after the catalogue loads.

**Prompt (already applied).**

```text
In HymnsView, `filtered`, `filter`, `activeLanguage`, and `languages` are computed properties. `filter` is read inside the `catalogue.filter` closure, so the work is O(N²) and runs on every body pass and every row onAppear.
Create an @Observable @MainActor HymnListModel in Hymns/ that stores catalogue, languages, activeLanguage, and filtered. Add refilter(_ inputs:) that builds the HymnFilter once, outside the closure, and assigns only the values that changed. Make HymnsView own the model in @State and call it from .onChange of language, season, massPart, and packs.ids, from the debounce task, and after loadCatalogue. Keep the view's API and the existing tests passing.
```

**Done when.** Switching language and scrolling show no `HymnsView.body` or filtering spikes in Time Profiler. `HymnTests` pass.

---

## Step 2. Light rows, no manual paging (DONE)

**Problem.**

- `ForEach(visible)` pages by 80 rows. Each row's `onAppear` checks `visible.last` and `filtered.count`, and `visibleCount` changes cause extra body passes. `LazyVStack` already builds rows lazily.
- `row(_:)` is a large builder method on the parent view. `savedIDs` rebuilds a `Set` from `@Query` bookmarks once per row. `rowLine` trims strings and scans `hymnPacks` once per row, on every pass.
- A list change does not return the scroll position to the top.

**Fix.**

- Delete `visibleCount`, `visible`, and the per-row `onAppear`. Use `ForEach(model.filtered)`.
- Add `struct HymnListRow: View, Equatable`. Its inputs are plain values: `hymn`, `rowLine`, `isSaved`, `isSelected`, `splitsColumns`. It reads the palette from the environment. Apply `.equatable()` at the call site.
- Build `savedIDs` once per `body` pass, before the `ForEach`.
- Compute `rowLine` once per hymn, when `refilter` runs or when `hymnPacks` changes.
- Reset the scroll position when the filters change (`ScrollViewReader.scrollTo` or an `.id` on the `ScrollView`).

**Prompt.**

```text
Read PerfectLiturgy/Hymns/HymnsView.swift and HymnListModel.swift. Follow AGENTS.md and docs/DESIGN.md.
1. Remove the manual paging: visibleCount, visible, and the row onAppear. Render ForEach(model.filtered) in the LazyVStack.
2. Extract the row into `struct HymnListRow: View, Equatable` with plain value inputs (hymn, rowLine, isSaved, isSelected, splitsColumns) and apply .equatable(). Keep the look, accessibility labels, and the 44 pt targets unchanged.
3. Build the saved id set once per body pass, not once per row. Precompute each row's `rowLine` once, not per body pass.
4. Scroll to the top when language, season, Mass part, or the search text changes.
Do not change the filter logic. Build and run HymnTests.
```

**Done when.** A scroll trace shows no per-row work in `body`. The list returns to the top when a filter changes.

---

## Step 3. Make search cheap (DONE)

**Problem.** `HymnSearch.textMatches` calls `AccentFold.fold(hymn.sectionText)` for every hymn on every search. `searchKey` already holds the folded title, first line, and lyrics. `folding(options:locale:)` is slow, and `HymnSummary` carries the whole lyrics text twice.

**Fix.**

- Make `HymnSearch.makeKey` fold the title, first line, and every section's content, once, at import.
- Remove `sectionText` from `HymnSummary` and from the search path.
- Fold the query once per search. Keep the number and id matches as they are.
- Optional: run `refilter` for typed queries in a cancellable `Task` that checks `Task.isCancelled`.

**Prompt.**

```text
In Hymns/HymnText.swift, HymnSearch.textMatches folds hymn.sectionText for every hymn on every search, although searchKey already holds folded text.
Change HymnSearch.makeKey and HymnImporter.fill so searchKey also includes the folded content of every section. Remove sectionText from HymnSummary and from HymnSearch.textMatches. Fold the query once per search.
A catalogue already on a device was imported with the old key. Make sure it is re-imported: change the import signature in HymnImporter.importBundledIfNeeded so it includes a search-key version number.
Keep the behaviour covered by HymnTests (accent-insensitive search, number search, id search). Add a test that finds a hymn by a word that appears only in a later stanza.
```

**Done when.** Typing in the search field shows no `AccentFold.fold` frames in Time Profiler. Existing search tests and the new stanza test pass.

---

## Step 4. Load data once, off the main thread (DONE)

**Problem.**

- `HymnsView` runs `loadCatalogue()` and `reloadHymnPacks()` in `.task` and again in `.onAppear`, so they run whenever the tab appears. `loadCatalogue` fetches every `HymnRecord` on the main context and faults about 1,700 section rows. `reloadHymnPacks` reads and decodes `catalog.json` from disk on the main thread.
- `HymnDetailView` does the same pack-catalogue read on every push.

**Fix.**

- Add a `@ModelActor` (or a detached fetch) that returns `[HymnSummary]` without touching sections. With Step 3 done, summaries need no section text.
- Load the catalogue once at launch or on first appearance. Reload only on `.hymnStoreDidChange`.
- Keep the pack rows (`hymnPacks`) in one shared `@Observable` store, loaded once and updated when downloads or removals change. Views read it from the environment.
- Remove the duplicate `.onAppear` reload.

**Prompt.**

```text
HymnsView reloads the hymn catalogue and decodes catalog.json on the main thread every time it appears, and HymnDetailView decodes catalog.json on every push.
1. Add a @ModelActor that fetches HymnSummary values off the main thread, using the same store as HymnStore.shared. Do not load sections.
2. Load the catalogue once, and reload it only on .hymnStoreDidChange. Remove the .onAppear reload.
3. Add an @Observable HymnPackStore that reads PackFiles.rowsForDisplay once, refreshes when the pack catalogue changes, and is injected through the environment in PerfectLiturgyApp. Use it in HymnsView and HymnDetailView instead of reading the file in views.
Keep the model, HymnTests, and PackTests passing. Swift 6 concurrency: no data races, and HymnSummary stays Sendable.
```

**Done when.** Switching to the Hymns tab does no fetch and no disk read after the first load.

---

## Step 5. Make the push feel instant (DONE)

**Problem.**

- `HymnDetailView` starts with `page == nil`, so the first frame says "Hymn unavailable". It then loads in `.task`, reads the pack catalogue, builds `HymnPage` (sort, share text, lyric blocks), and calls `recordVisit`, which fetches all visits and runs `context.save()`, all on the main thread during the transition.
- `PLTopBar` reads `navigation.path`. Every tab has one, so a push re-evaluates all five.

**Fix.**

- Load the page in `HymnDetailView.init` (a single-row local fetch) so the first frame has content. Keep `.task(id:)` only for later reloads.
- Run `recordVisit` after the transition (for example after about 300 ms), off the critical path.
- Give `PLTopBar` a `showsBack` value from its parent, or read it in a smaller child view, so a push does not invalidate every tab.

**Prompt.**

```text
Pushing a hymn shows "Hymn unavailable" for a frame, then loads. Fix it in Hymns/HymnDetailView.swift:
1. Load HymnPage in init through HymnImporter.page so the first frame has content. Keep a reload on .hymnStoreDidChange.
2. Move HymnImporter.recordVisit out of the transition: start it from a Task that waits about 300 ms, and make it fetch only the visit it needs plus the count check.
3. In Design/Controls.swift, PLTopBar reads navigation.path in every tab. Pass showsBack in from the parent screen, or isolate the read, so pushing a route does not re-evaluate all tab top bars.
No visual change. Build and run HymnTests.
```

**Done when.** The push animates with the hymn already on screen, and the Hangs instrument shows no hitch during the push.

---

## Step 6. Sheets that do not resize after they open (DONE)

**Problem.** `FittedBottomSheet` (in `HymnFilterSheet.swift`) calls `InterfaceAnchor.window` on every `body` pass, which walks scenes and windows. It also feeds a `GeometryReader` height back into `presentationDetents`, so the sheet opens at 360 pt and then resizes.

**Fix.**

- Use fixed detents such as `.presentationDetents([.medium])`, or measure the content once.
- Remove `InterfaceAnchor.window` from `body`.
- With Step 1 done, drop the `Task.yield()` in the language `onSelect`. Dismiss and apply the choice at once, with animations off for the list update.

**Prompt.**

```text
In Hymns/HymnFilterSheet.swift, FittedBottomSheet reads InterfaceAnchor.window in body and feeds a GeometryReader height back into presentationDetents, so the sheet resizes after it appears.
Replace it with a stable height: measure the content once with onGeometryChange (iOS 17 safe fallback if needed), or use .medium. Remove the window lookup from body.
In HymnsView, remove the Task.yield() from the language onSelect and set `language` directly, inside a transaction with animation disabled. Keep the look, the drag indicator, and the 44 pt targets.
```

**Done when.** Both sheets open at their final height with no visible resize. Changing the language is instant.

---

## Step 7. Verify with Instruments (signposts and timing test DONE; the device run is yours)

Run on a device with the **Release** configuration. The Debug simulator build is much slower and hides which fixes matter.

1. **Time Profiler** while scrolling the list and changing the language. Look for `HymnsView.body`, `HymnSearch.matches`, `AccentFold.fold`, and `HymnCatalogueReader.summaries`. The signpost intervals `hymns.refilter`, `hymns.catalogue`, and `hymns.page` (subsystem `com.perfectliturgy`, category `performance`) show how long each takes.
2. **SwiftUI** instrument. Count body updates per row and per tab during a push.
3. **Hangs** while pushing a hymn and opening a sheet.

**Prompt.**

```text
Add an os_signpost around HymnListModel.refilter, HymnImporter.catalogue, and HymnImporter.page using Logger(subsystem: "com.perfectliturgy", category: "performance"), so they show up in Instruments. Add a Swift Testing test that refilters the bundled English and Latin catalogues 100 times and fails if the average takes more than 5 ms.
```

**Done when.** No main-thread frame over 16 ms during a scroll, language change, push, or sheet open.

Measured so far: refiltering the bundled English and Latin catalogues takes about 3.5 ms on average in a Debug build on the simulator (`refiltering the bundled catalogues stays fast`). The test fails above 25 ms in Debug and 5 ms in Release.
