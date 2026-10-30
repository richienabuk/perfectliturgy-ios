import Foundation

/// One segment inside a verse: part letter and optional quote style (§7.3).
nonisolated struct BibleSegment: Codable, Equatable, Sendable {
    var t: String
    var part: String?
    var style: String?
}

/// A book row from a readings pack.
nonisolated struct BibleBookPayload: Equatable, Sendable {
    var id: String
    var order: Int
    var name: String
    var abbr: String
}

/// A verse row from a readings pack, including tombstones.
nonisolated struct BibleVersePayload: Equatable, Sendable {
    var book: String
    var chapter: Int
    var verse: Int
    var text: String
    var segments: [BibleSegment]?
    var segmentsJSON: String?
    var updatedAt: Date
    var deletedAt: Date?
}

/// Decoded readings download or sync page.
nonisolated struct BiblePackPayload: Equatable, Sendable {
    var packId: String
    var language: String
    var revision: String
    var versification: String
    var coverageThrough: String?
    var books: [BibleBookPayload]
    var verses: [BibleVersePayload]
    var nextCursor: String?
}

enum BiblePackReader {
    nonisolated static func decode(_ data: Data) throws -> BiblePackPayload {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom(Self.decodeDate)
        let envelope = try decoder.decode(Envelope.self, from: data)
        return envelope.payload
    }

    nonisolated static func versionID(for packId: String) -> String {
        if packId.hasPrefix("readings-") {
            return String(packId.dropFirst("readings-".count))
        }
        return packId
    }

    nonisolated private static func decodeDate(_ decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if let date = fractional.date(from: raw) { return date }
        if let date = plain.date(from: raw) { return date }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Bad date \(raw)"
        )
    }

    nonisolated(unsafe) private static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    nonisolated(unsafe) private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

// MARK: - Decoding

private nonisolated struct Envelope: Decodable {
    var packId: String
    var language: String
    var revision: String
    var metadata: MetadataDTO?
    var books: [BookDTO]?
    var data: [VerseDTO]
    var nextCursor: String?

    var payload: BiblePackPayload {
        BiblePackPayload(
            packId: packId,
            language: language,
            revision: revision,
            versification: metadata?.versification ?? "lectionary",
            coverageThrough: metadata?.coverageThrough,
            books: (books ?? []).map {
                BibleBookPayload(id: $0.id, order: $0.order, name: $0.name, abbr: $0.abbr)
            },
            verses: data.map(\.payload),
            nextCursor: nextCursor
        )
    }
}

private nonisolated struct MetadataDTO: Decodable {
    var versification: String?
    var coverageThrough: String?
}

private nonisolated struct BookDTO: Decodable {
    var id: String
    var order: Int
    var name: String
    var abbr: String
}

private nonisolated struct VerseDTO: Decodable {
    var book: String
    var chapter: Int
    var verse: Int
    var text: String
    var segments: [BibleSegment]?
    var updatedAt: Date
    var deletedAt: Date?

    var payload: BibleVersePayload {
        var json: String?
        if let segments {
            json = try? String(data: JSONEncoder().encode(segments), encoding: .utf8)
        }
        return BibleVersePayload(
            book: book,
            chapter: chapter,
            verse: verse,
            text: text,
            segments: segments,
            segmentsJSON: json,
            updatedAt: updatedAt,
            deletedAt: deletedAt
        )
    }
}
