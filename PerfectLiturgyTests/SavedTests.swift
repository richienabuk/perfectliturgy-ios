import Foundation
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import PerfectLiturgy

@Test func `appearance and both type scales survive a new launch`() throws {
    let suite = "design-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defaults.removePersistentDomain(forName: suite)
    defer { defaults.removePersistentDomain(forName: suite) }

    let first = DesignPreferences(defaults: defaults)
    #expect(first.appearance == .system)
    #expect(first.headingScale == 1)
    #expect(first.bodyScale == 1)
    #expect(first.autoSync)
    #expect(first.readingScale == ReadingScale())

    first.setAppearance(.dark)
    first.setHeadingScale(1.25)
    first.setBodyScale(0.85)
    first.setAutoSync(false)
    first.setHeadingScale(3)
    first.setBodyScale(0.1)

    let second = DesignPreferences(defaults: defaults)
    #expect(second.appearance == .dark)
    #expect(second.appearance.colorScheme == .dark)
    #expect(second.headingScale == 1.4)
    #expect(second.bodyScale == 0.8)
    #expect(second.readingScale == ReadingScale(headings: 1.4, body: 0.8))
    #expect(!second.autoSync)
}

@Test func `a bookmark is still there after the store is opened again`() throws {
    let folder = FileManager.default.temporaryDirectory
        .appending(path: "pl-bookmarks-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appending(path: "Hymns.store")

    try saveTestBookmark(at: url)

    let container = try HymnStore.make(at: url)
    let bookmarks = try container.mainContext.fetch(FetchDescriptor<HymnBookmark>())
    #expect(bookmarks.map(\.hymnId) == ["test-kept"])
    #expect(bookmarks.map(\.titleSnapshot) == ["Test hymn one"])
    #expect(bookmarks.map(\.language) == ["en"])
}

@Test func `saved rows name the catalogue and stay closed when the pack is gone`() throws {
    let container = try HymnStore.make(inMemory: true)
    let context = container.mainContext
    let hymn = try insertHymn(id: "test-en-1", language: "en", title: "Test hymn one", massParts: ["entrance", "communion"], in: context)
    try HymnImporter.toggleBookmark(hymn, in: context)
    let bookmark = try #require(try context.fetch(FetchDescriptor<HymnBookmark>()).first)

    let open = SavedRows.row(bookmark: bookmark, hymn: hymn, installed: Set(ContentPack.bundledIDs))
    #expect(open.opens)
    #expect(open.title == "Test hymn one")
    #expect(open.detail == "English Hymns · Entrance")

    hymn.title = "A later title"
    var installed = Set(ContentPack.bundledIDs)
    installed.remove(ContentPack.hymnID(for: "en"))
    let removed = SavedRows.row(bookmark: bookmark, hymn: hymn, installed: installed)
    #expect(!removed.opens)
    #expect(removed.title == "Test hymn one")
    #expect(removed.detail == "Hymn pack removed from this device")

    let gone = SavedRows.row(bookmark: bookmark, hymn: nil, installed: installed)
    #expect(!gone.opens)
    #expect(gone.title == "Test hymn one")
    #expect(gone.detail == "Hymn pack removed from this device")

    let missing = SavedRows.row(bookmark: bookmark, hymn: nil, installed: Set(ContentPack.bundledIDs))
    #expect(!missing.opens)
    #expect(missing.detail == "Not on this device")

    #expect(SavedRows.emptyNote(signedIn: false) == "Save a hymn from its page. It stays on this device and opens here.")
    #expect(SavedRows.emptyNote(signedIn: true) == "Save a hymn from its page. It syncs with your Account when you're online.")
    #expect(SavedRows.detail(language: "en", massParts: []) == "English Hymns")

    try HymnImporter.removeBookmark(hymnID: hymn.id, in: context)
    #expect(try context.fetch(FetchDescriptor<HymnBookmark>()).isEmpty)
}

@Test func `removing a hymn pack is remembered`() throws {
    let suite = "packs-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defaults.removePersistentDomain(forName: suite)
    defer { defaults.removePersistentDomain(forName: suite) }

    let first = InstalledPacks(defaults: defaults)
    #expect(first.contains("hymns-en"))
    #expect(first.contains("hymns-la"))
    first.remove("hymns-en")

    let second = InstalledPacks(defaults: defaults)
    #expect(!second.contains("hymns-en"))
    #expect(second.contains("hymns-la"))
    #expect(second.contains("prayers-en"))
}

@Test func `body scale changes hymn text`() async throws {
    AppFonts.register(bundle: Bundle(for: DesignPreferences.self))
    let block = HymnLyricBlock(id: 0, heading: "STANZA 1", content: "Test line for hymn one", card: .stanza)
    let small = HymnSectionCard(block: block)
        .environment(\.readingScale, ReadingScale(headings: 1, body: 0.8))
        .resolvePalette()
        .frame(width: 320, height: 160, alignment: .topLeading)
    let large = HymnSectionCard(block: block)
        .environment(\.readingScale, ReadingScale(headings: 1, body: 1.4))
        .resolvePalette()
        .frame(width: 320, height: 220, alignment: .topLeading)

    let smallImage = try await renderSaved(small, size: CGSize(width: 320, height: 160))
    let largeImage = try await renderSaved(large, size: CGSize(width: 320, height: 220))
    #expect(smallImage.pngData() != largeImage.pngData())
    #expect(ReadingScale(body: 0.8).size(for: .response) == 12.8)
    #expect(ReadingScale(body: 1.4).size(for: .response) == 22.4)
}

@Test func `a removed pack leaves a greyed saved row that does not open`() async throws {
    let container = try HymnStore.make(inMemory: true)
    let context = container.mainContext
    let english = try insertHymn(id: "test-en-1", language: "en", title: "Test hymn one", massParts: ["entrance"], in: context)
    let latin = try insertHymn(id: "test-la-1", language: "la", title: "Test hymn one", massParts: ["recessional"], in: context)
    try HymnImporter.toggleBookmark(english, in: context)
    try HymnImporter.toggleBookmark(latin, in: context)

    let suite = "saved-ui-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defaults.removePersistentDomain(forName: suite)
    defer { defaults.removePersistentDomain(forName: suite) }
    let packs = InstalledPacks(defaults: defaults)
    packs.remove("hymns-en")

    let rows = try context.fetch(FetchDescriptor<HymnBookmark>()).map { bookmark in
        let hymn = [english, latin].first { $0.id == bookmark.hymnId }
        return SavedRows.row(bookmark: bookmark, hymn: hymn, installed: packs.ids)
    }
    let closed = try #require(rows.first { $0.id == "test-en-1" })
    let open = try #require(rows.first { $0.id == "test-la-1" })
    #expect(!closed.opens)
    #expect(closed.title == "Test hymn one")
    #expect(closed.detail == "Hymn pack removed from this device")
    #expect(open.opens)
    #expect(open.detail == "Latin Hymns · Recessional")

    let view = SavedView()
        .modelContainer(container)
        .environment(AppNavigation())
        .environment(packs)
        .environment(AppSession(token: nil, store: MemorySessionStore()))
        .resolvePalette()
        .frame(width: 390, height: 844)
    let image = try await renderSaved(view, size: CGSize(width: 390, height: 844))
    Attachment.record(image, named: "saved-phone")
    #expect(image.size.width > 300)
    #expect(image.size.height > 700)
}

@Test func `settings shows the reading controls and the account row`() async throws {
    let suite = "settings-ui-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defaults.removePersistentDomain(forName: suite)
    defer { defaults.removePersistentDomain(forName: suite) }
    let design = DesignPreferences(defaults: defaults)
    let view = SettingsView()
        .environment(design)
        .environment(AppNavigation())
        .environment(\.readingScale, design.readingScale)
        .resolvePalette()
        .frame(width: 390, height: 1100)
    let image = try await renderSaved(view, size: CGSize(width: 390, height: 1100))
    Attachment.record(image, named: "settings-phone")
    #expect(image.size.width > 300)
    let controls = try await controlKinds(view, size: CGSize(width: 390, height: 1100))
    #expect(controls.filter { $0 == "UISlider" }.count == 2)
    #expect(controls.filter { $0 == "UISwitch" }.count == 1)
}

private func saveTestBookmark(at url: URL) throws {
    let container = try HymnStore.make(at: url)
    let context = container.mainContext
    let hymn = HymnRecord(
        id: "test-kept",
        language: "en",
        hymnNumber: 1,
        title: "Test hymn one",
        firstLine: "Test line",
        lyrics: "Test line",
        searchKey: "test hymn one"
    )
    context.insert(hymn)
    try HymnImporter.toggleBookmark(hymn, in: context)
}

@discardableResult
private func insertHymn(
    id: String,
    language: String,
    title: String,
    massParts: [String],
    in context: ModelContext
) throws -> HymnRecord {
    let hymn = HymnRecord(
        id: id,
        language: language,
        hymnNumber: 1,
        title: title,
        firstLine: "Test line",
        lyrics: "Test line",
        massParts: massParts,
        searchKey: "test"
    )
    context.insert(hymn)
    try context.save()
    return hymn
}

@MainActor
private func hostSaved<V: View>(_ view: V, size: CGSize) async throws -> UIHostingController<V> {
    let host = UIHostingController(rootView: view)
    let bounds = CGRect(origin: .zero, size: size)
    host.view.bounds = bounds
    host.view.frame = bounds
    let window = UIWindow(frame: bounds)
    window.rootViewController = host
    window.makeKeyAndVisible()
    host.view.setNeedsLayout()
    host.view.layoutIfNeeded()
    try await Task.sleep(for: .milliseconds(400))
    return host
}

@MainActor
private func controlKinds<V: View>(_ view: V, size: CGSize) async throws -> [String] {
    let host = try await hostSaved(view, size: size)
    var kinds: [String] = []
    func walk(_ view: UIView) {
        let name = String(describing: type(of: view))
        if name == "UISlider" || name == "UISwitch" {
            kinds.append(name)
        }
        for child in view.subviews {
            walk(child)
        }
    }
    walk(host.view)
    return kinds
}

@MainActor
private func renderSaved<V: View>(_ view: V, size: CGSize) async throws -> UIImage {
    let host = try await hostSaved(view, size: size)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 2
    return UIGraphicsImageRenderer(size: size, format: format).image { _ in
        host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
    }
}
