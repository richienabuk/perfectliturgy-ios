import Foundation
import Testing
@testable import PerfectLiturgy

@Test func `more lists every row in the app map`() {
    let titles = MoreMenu.sections.flatMap(\.rows).map(\.title)
    #expect(titles == [
        "Order of Mass",
        "Holy Rosary",
        "Stations of the Cross",
        "Litanies",
        "Special Prayers",
        "Downloads",
        "Settings",
        "Account",
        "Mass Times",
        "Donate",
    ])
}

@Test func `more sections follow the app map`() {
    #expect(MoreMenu.sections.map(\.title) == [
        "Order of Mass",
        "Prayer & devotions",
        "App",
        "Discover & support",
    ])
}

@Test func `detail routes keep their titles`() {
    #expect(AppRoute.hymn(id: "sample").title == "Hymn")
    #expect(AppRoute.litany(id: "sample").title == "Litany")
    #expect(AppRoute.prayer(id: "sample").title == "Prayer")
    #expect(AppRoute.station(order: 1).title == "Station")
}

@Test(arguments: [
    ("perfectliturgy://auth?session_token=abc", "abc"),
    ("perfectliturgy://auth?sessionToken=abc", "abc"),
    ("perfectliturgy://auth?token=abc", "abc"),
    ("perfectliturgy://auth?better-auth.session_token=abc", "abc"),
    ("perfectliturgy://auth#token=abc", "abc"),
])
func `auth return reads the session token`(raw: String, expected: String) throws {
    let url = try #require(URL(string: raw))
    #expect(AuthReturn.accepts(url))
    #expect(AuthReturn.callback(from: url) == .session(token: expected))
}

@Test func `auth return prefers a one-time code over a session token`() throws {
    let url = try #require(URL(string: "perfectliturgy://auth?code=one-time&state=s1&session_token=ignored"))
    #expect(AuthReturn.callback(from: url) == .code(code: "one-time", state: "s1"))
}

@Test func `an auth return without a token is still the auth link`() throws {
    let url = try #require(URL(string: "perfectliturgy://auth"))
    #expect(AuthReturn.accepts(url))
    #expect(AuthReturn.callback(from: url) == nil)
    let failed = try #require(URL(string: "perfectliturgy://auth?error=access_denied"))
    #expect(AuthReturn.callback(from: failed) == .failure)
}

@Test func `other schemes are not the auth return`() throws {
    let url = try #require(URL(string: "https://perfectliturgy.com/donate"))
    #expect(!AuthReturn.accepts(url))
}
