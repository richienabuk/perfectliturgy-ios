import Foundation
import UserNotifications

struct ParishNotice: Identifiable, Equatable, Sendable {
    var title: String
    var body: String?
    var imageURL: URL?

    var id: String { "\(title)\u{1f}\(body ?? "")\u{1f}\(imageURL?.absoluteString ?? "")" }
}

enum NoticePayload {
    static func notice(from userInfo: [AnyHashable: Any]) -> ParishNotice? {
        let title = text(userInfo["title"]) ?? alertTitle(userInfo)
        guard let title, !title.isEmpty else { return nil }
        let body = nonempty(text(userInfo["body"]) ?? alertBody(userInfo))
        return ParishNotice(title: title, body: body, imageURL: imageURL(from: text(userInfo["image"])))
    }

    static func imageURL(from raw: String?) -> URL? {
        guard let raw, let url = URL(string: raw), url.scheme?.lowercased() == "https" else { return nil }
        let path = url.path.lowercased()
        guard path.hasSuffix(".jpg") || path.hasSuffix(".jpeg") || path.hasSuffix(".png") else { return nil }
        return url
    }

    private static func text(_ value: Any?) -> String? {
        guard let value else { return nil }
        if let text = value as? String { return text }
        return nil
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func alert(_ userInfo: [AnyHashable: Any]) -> [AnyHashable: Any]? {
        let aps = userInfo["aps"] as? [AnyHashable: Any]
        if let alert = aps?["alert"] as? [AnyHashable: Any] { return alert }
        return nil
    }

    private static func alertTitle(_ userInfo: [AnyHashable: Any]) -> String? {
        if let alert = userInfo["aps"] as? [AnyHashable: Any], let text = alert["alert"] as? String {
            return nonempty(text)
        }
        return nonempty(text(alert(userInfo)?["title"]))
    }

    private static func alertBody(_ userInfo: [AnyHashable: Any]) -> String? {
        nonempty(text(alert(userInfo)?["body"]))
    }
}

enum NoticeBanner {
    static func content(for notice: ParishNotice) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = notice.title
        content.body = notice.body ?? ""
        var info: [String: String] = ["title": notice.title]
        if let body = notice.body { info["body"] = body }
        if let image = notice.imageURL?.absoluteString { info["image"] = image }
        content.userInfo = info
        return content
    }
}
