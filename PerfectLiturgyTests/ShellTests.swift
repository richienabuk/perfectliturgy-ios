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
    "perfectliturgy://auth",
    "perfectliturgy://auth?session_token=abc",
    "perfectliturgy://auth#token=abc",
])
func `auth return is accepted and ignored`(_ raw: String) throws {
    let url = try #require(URL(string: raw))
    #expect(AuthReturn.accepts(url))
    AuthReturn.handle(url)
}

@Test func `other schemes are not the auth return`() throws {
    let url = try #require(URL(string: "https://perfectliturgy.com/donate"))
    #expect(!AuthReturn.accepts(url))
}
