import XCTest
@testable import DoYourWorkCore

final class BorderTests: XCTestCase {
    /// A tiny but real JPEG header, as base64: enough for `ProfilePhoto.clean`.
    let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10]).base64EncodedString()

    func testCatalogue() {
        let ids = Borders.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "ids are unique")
        XCTAssertEqual(ids.first, "none")
        XCTAssertEqual(Borders.all.map(\.unlockXp), Borders.all.map(\.unlockXp).sorted(), "listed in the order they unlock")
        XCTAssertTrue(Borders.all.contains { $0.unlockXp == 0 && !$0.layers.isEmpty }, "one to wear from the start")
        // Every drawing parses with the same reader the characters use, inside the square.
        for b in Borders.all { for l in b.layers {
            let steps = Characters.steps(l.path)
            XCTAssertFalse(steps.isEmpty, b.id)
        } }
    }

    func testUnlocking() {
        let bunny = Borders.named("bunny")!
        XCTAssertFalse(Borders.isUnlocked(bunny, xp: bunny.unlockXp - 1))
        XCTAssertTrue(Borders.isUnlocked(bunny, xp: bunny.unlockXp))
        let puppy = Borders.named("puppy")!
        XCTAssertEqual(Borders.next(xp: 0)?.border.id, "puppy")
        XCTAssertEqual(Borders.next(xp: 0)?.pointsToGo, puppy.unlockXp)
        XCTAssertEqual(Borders.next(xp: puppy.unlockXp)?.border.id, "bunny")
        XCTAssertEqual(Borders.next(xp: bunny.unlockXp)?.border.id, "panda")
        XCTAssertNil(Borders.next(xp: 1_000_000))
        XCTAssertNil(Borders.named("from-a-newer-version"))
        XCTAssertNil(Borders.shown(Player(id: "1", name: "a", border: "none")))
        XCTAssertEqual(Borders.shown(Player(id: "1", name: "a", border: "halo"))?.id, "halo")
    }

    func testPhotoCleaning() {
        XCTAssertEqual(ProfilePhoto.clean(jpeg), jpeg)
        XCTAssertNil(ProfilePhoto.clean(""))
        XCTAssertNil(ProfilePhoto.clean("not base64!"))
        XCTAssertNil(ProfilePhoto.clean(Data([0x89, 0x50, 0x4E, 0x47]).base64EncodedString()), "only JPEGs")
        XCTAssertNil(ProfilePhoto.clean(String(repeating: "A", count: ProfilePhoto.maxBase64 + 4)), "too big to sync")
    }

    func testPhotoAndBorderSync() {
        let family = FamilyState.Family(
            members: [Player(id: "1", name: "mom", isAdmin: true, photo: jpeg, border: "hearts"),
                      Player(id: "2", name: "kid")],
            removed: ["3"])
        let state = FamilyState.encode(family)
        XCTAssertEqual(state["photo|1"], [jpeg])
        XCTAssertEqual(state["border|1"], ["hearts"])
        // Written as empty, so taking a photo off reaches the other phones too.
        XCTAssertEqual(state["photo|2"], [])
        XCTAssertEqual(state["border|2"], [])
        XCTAssertEqual(state["photo|3"], [])
        let back = FamilyState.decode(state)
        XCTAssertEqual(back.members, family.members)
        // A phone that wrote something that isn't a photo: shown as no photo.
        var bad = state; bad["photo|1"] = ["garbage"]
        XCTAssertNil(FamilyState.decode(bad).members.first?.photo)
    }

    func testBackupKeepsPhotoAndBorder() throws {
        let p = Player(id: "1", name: "mom", isAdmin: true, photo: jpeg, border: "crown")
        let b = Backup(members: [p], codes: [:], chores: [], choreAdded: [:], memberJoined: [:], nextPlayerId: 2, logs: [],
                       dares: [], puzzleLevels: [:], source: "ios-public", appVersion: "test")
        let back = try Backup.read(b.data())
        XCTAssertEqual(back.players.first?.photo, jpeg)
        XCTAssertEqual(back.players.first?.border, "crown")
    }
}
