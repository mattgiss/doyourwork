import XCTest
@testable import DoYourWorkCore

final class WidgetSnapshotTests: XCTestCase {
    func snap(day: String = "2026-11-21", week: String = "2026-11-16") -> WidgetSnapshot {
        WidgetSnapshot(day: day, weekStart: week, players: [
            .init(id: "1", name: "Riley", minutesDone: 18, minutesPlanned: 25, card: "playing", next: "Dishes", streak: 4, streakToday: true, weekPoints: 40, version: "v1.3"),
            .init(id: "2", name: "Sam", minutesDone: 25, minutesPlanned: 25, card: "sent", next: nil, streak: 3, streakToday: false, weekPoints: 90, version: "v1.1"),
        ], me: "1", linked: true, daresLeftToday: 1,
        yesterdaysDares: [.init(from: "2", target: "1", fromName: "Sam", targetName: "Riley", chore: "Dishes", landed: true)], colors: .fuego)
    }

    func testSameDayIsUnchanged() {
        XCTAssertEqual(snap().asOf(today: "2026-11-21", week: "2026-11-16", yesterday: "2026-11-20"), snap())
    }

    func testNextDayStartsAFreshCard() {
        let s = snap().asOf(today: "2026-11-22", week: "2026-11-16", yesterday: "2026-11-21")
        XCTAssertEqual(s.players.map(\.card), ["pick", "pick"])
        XCTAssertEqual(s.players.map(\.minutesDone), [0, 0])
        // Riley's yesterday counted, so the streak carries; Sam's didn't, so it broke.
        XCTAssertEqual(s.players.map(\.streak), [4, 0])
        XCTAssertEqual(s.players.map(\.weekPoints), [40, 90])
        // Yesterday's dares in the file are two days old now, and today's are still secret.
        XCTAssertTrue(s.yesterdaysDares.isEmpty)
        XCTAssertEqual(s.daresLeftToday, Engine.maxDaresPerDay)
    }

    func testTwoDaysLaterEveryStreakHasBroken() {
        let s = snap().asOf(today: "2026-11-23", week: "2026-11-23", yesterday: "2026-11-22")
        XCTAssertEqual(s.players.map(\.streak), [0, 0])
        XCTAssertEqual(s.players.map(\.weekPoints), [0, 0])
        XCTAssertEqual(s.weekStart, "2026-11-23")
    }

    func testPlaces() {
        let s = snap()
        XCTAssertEqual(s.place(of: "2"), 1)
        XCTAssertEqual(s.place(of: "1"), 2)
        XCTAssertNil(s.place(of: "9"))
    }
}
