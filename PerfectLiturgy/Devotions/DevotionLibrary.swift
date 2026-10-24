import Foundation

/// Bundled devotion JSON, replaced by an Application Support file for that pack when one is present.
enum DevotionLibrary {
    static let supportFolder = "packs"

    static var applicationSupport: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: supportFolder, directoryHint: .isDirectory)
    }

    static func load(
        _ kind: DevotionKind,
        language: String,
        bundle: Bundle = .main,
        supportRoot: URL? = nil
    ) -> DevotionBody? {
        let root = supportRoot ?? applicationSupport
        let downloaded = root.appending(path: "\(kind.rawValue)-\(language).json")
        if FileManager.default.fileExists(atPath: downloaded.path),
           let data = try? Data(contentsOf: downloaded),
           let body = decode(kind, data: data) {
            return body
        }
        guard
            let url = bundledURL(kind, language: language, bundle: bundle),
            let data = try? Data(contentsOf: url)
        else {
            return nil
        }
        return decode(kind, data: data)
    }

    static func decode(_ kind: DevotionKind, data: Data) -> DevotionBody? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        switch kind {
        case .order:
            guard let file = try? decoder.decode(Envelope<[RawPart]>.self, from: data) else { return nil }
            let parts = ordered(file.data).map { raw in
                MassPart(
                    order: raw.order,
                    title: raw.title,
                    summary: raw.summary,
                    items: ordered(raw.items).map { item in
                        MassItem(
                            order: item.order,
                            title: item.title,
                            rubric: item.rubric,
                            text: item.text,
                            response: item.response
                        )
                    }
                )
            }
            return .order(language: file.language, parts: parts)
        case .rosary:
            guard let file = try? decoder.decode(Envelope<RawRosary>.self, from: data) else { return nil }
            let prayers = RosaryPrayers(
                sign: file.data.prayers.sign,
                creed: file.data.prayers.creed,
                ourFather: file.data.prayers.ourFather,
                hailMary: file.data.prayers.hailMary,
                gloryBe: file.data.prayers.gloryBe,
                fatima: file.data.prayers.fatima,
                hailHolyQueen: file.data.prayers.hailHolyQueen,
                closing: file.data.prayers.closing
            )
            let mysteries = ordered(file.data.mysteries).map { set in
                RosaryMysterySet(
                    order: set.order,
                    id: set.id ?? DevotionID.slug(set.title),
                    title: set.title,
                    days: set.days,
                    titles: ordered(set.titles).map(\.title)
                )
            }
            return .rosary(language: file.language, pack: RosaryPack(prayers: prayers, mysteries: mysteries))
        case .stations:
            guard let file = try? decoder.decode(Envelope<[RawStation]>.self, from: data) else { return nil }
            let stations = ordered(file.data).map { raw in
                Station(
                    order: raw.order,
                    id: raw.id ?? DevotionID.slug(raw.title),
                    title: raw.title,
                    reference: raw.reference,
                    meditation: raw.meditation,
                    prayer: raw.prayer
                )
            }
            return .stations(language: file.language, stations: stations)
        case .litanies:
            guard let file = try? decoder.decode(Envelope<[RawLitany]>.self, from: data) else { return nil }
            let litanies = ordered(file.data).map { raw in
                Litany(
                    order: raw.order,
                    id: raw.id ?? DevotionID.slug(raw.title),
                    title: raw.title,
                    summary: raw.summary,
                    category: raw.category,
                    lines: ordered(raw.lines).map { line in
                        LitanyLine(order: line.order, call: line.call, response: line.response)
                    }
                )
            }
            return .litanies(language: file.language, litanies: litanies)
        case .prayers:
            guard let file = try? decoder.decode(Envelope<[RawPrayer]>.self, from: data) else { return nil }
            let prayers = ordered(file.data).map { raw in
                SpecialPrayer(
                    order: raw.order,
                    id: raw.id ?? DevotionID.slug(raw.title),
                    title: raw.title,
                    summary: raw.summary,
                    category: raw.category,
                    text: raw.text
                )
            }
            return .prayers(language: file.language, prayers: prayers)
        }
    }

    static func bundledURL(_ kind: DevotionKind, language: String, bundle: Bundle) -> URL? {
        let names = [
            "\(kind.rawValue)_\(language)_catalogue",
            "\(kind.rawValue)_\(language)",
        ]
        let folders: [String?] = [
            nil,
            "Catalogues",
            "Devotions/Catalogues",
            "Fixtures",
            "Devotions/Fixtures",
        ]
        for name in names {
            for folder in folders {
                if let folder, let url = bundle.url(forResource: name, withExtension: "json", subdirectory: folder) {
                    return url
                }
                if folder == nil, let url = bundle.url(forResource: name, withExtension: "json") {
                    return url
                }
            }
        }
        if kind == .litanies {
            let folder = "litanies_\(language)"
            if let url = bundle.url(forResource: "litanies", withExtension: "json", subdirectory: folder) {
                return url
            }
        }
        return nil
    }

    private static func ordered<T>(_ values: [T], order: (T) -> Int) -> [T] {
        values.enumerated()
            .sorted { lhs, rhs in
                let left = order(lhs.element)
                let right = order(rhs.element)
                if left != right { return left < right }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private static func ordered<T: Orderable>(_ values: [T]) -> [T] {
        ordered(values, order: \.order)
    }
}

private protocol Orderable {
    var order: Int { get }
}

private struct Envelope<Payload: Decodable>: Decodable {
    var language: String
    var data: Payload
}

private struct RawPart: Decodable, Orderable {
    var order: Int
    var title: String
    var summary: String?
    var items: [RawItem]
}

private struct RawItem: Decodable, Orderable {
    var order: Int
    var title: String
    var rubric: String?
    var text: String?
    var response: String?
}

private struct RawRosary: Decodable {
    var prayers: RawPrayers
    var mysteries: [RawMystery]
}

private struct RawPrayers: Decodable {
    var sign: String
    var creed: String
    var ourFather: String
    var hailMary: String
    var gloryBe: String
    var fatima: String
    var hailHolyQueen: String
    var closing: String
}

private struct RawMystery: Decodable, Orderable {
    var order: Int
    var id: String?
    var title: String
    var days: String?
    var titles: [RawMysteryTitle]
}

private struct RawMysteryTitle: Decodable, Orderable {
    var order: Int
    var title: String
}

private struct RawStation: Decodable, Orderable {
    var order: Int
    var id: String?
    var title: String
    var reference: String?
    var meditation: String
    var prayer: String
}

private struct RawLitany: Decodable, Orderable {
    var order: Int
    var id: String?
    var title: String
    var summary: String?
    var category: String?
    var lines: [RawLine]
}

private struct RawLine: Decodable, Orderable {
    var order: Int
    var call: String
    var response: String?
}

private struct RawPrayer: Decodable, Orderable {
    var order: Int
    var id: String?
    var title: String
    var summary: String?
    var category: String?
    var text: String
}

@MainActor
enum DevotionReader {
    private static var cache: [String: DevotionBody] = [:]

    static func load(_ kind: DevotionKind, language: String) -> DevotionBody? {
        let key = "\(kind.rawValue)-\(language)"
        if let cached = cache[key] {
            return cached
        }
        guard let body = DevotionLibrary.load(kind, language: language), !body.isEmpty else {
            return nil
        }
        cache[key] = body
        return body
    }
}

