import XCTest
@testable import DoYourWorkCore

/// The snake game's rules. The Android `SnakeGameTest` checks the same cases and the same random
/// numbers, so the two games play alike.
final class SnakeTests: XCTestCase {
    typealias P = SnakeGame.Point

    func testRandomNumbersMatchAndroid() {
        var r = SnakeRandom(seed: 42)
        XCTAssertEqual((0..<6).map { _ in r.next(below: 1000) }, [334, 26, 538, 503, 294, 156])
        XCTAssertEqual(SnakeGame(seed: 7).food, P(8, 11))
    }

    func testStartsInTheMiddleWaitingForASwipe() {
        var g = SnakeGame(seed: 1)
        XCTAssertEqual(g.status, .ready)
        XCTAssertEqual(g.body, [P(7, 7), P(6, 7), P(5, 7)])
        XCTAssertEqual(g.direction, .right)
        XCTAssertNotNil(g.food)
        XCTAssertFalse(g.body.contains(g.food!), "the first dot isn't under the line")
        XCTAssertNil(g.step(), "nothing moves before the first swipe")
        XCTAssertEqual(g.head, P(7, 7))
        XCTAssertEqual(g.stepMilliseconds, 160)
    }

    func testFirstSwipeStartsAndTurns() {
        var g = SnakeGame(seed: 1)
        XCTAssertTrue(g.turn(.up))
        XCTAssertEqual(g.status, .playing)
        g.step()
        XCTAssertEqual(g.body, [P(7, 6), P(7, 7), P(6, 7)], "the tail follows the head")
    }

    func testSwipingBackwardsStillStartsButDoesntTurn() {
        var g = SnakeGame(seed: 1)
        XCTAssertFalse(g.turn(.left))
        XCTAssertEqual(g.status, .playing)
        g.step()
        XCTAssertEqual(g.head, P(8, 7))
    }

    func testReversingAndRepeatingAreIgnored() {
        var g = SnakeGame(width: 10, height: 10, body: [P(5, 5), P(4, 5), P(3, 5)], direction: .right, food: nil)
        XCTAssertFalse(g.turn(.left), "can't turn back on itself")
        XCTAssertFalse(g.turn(.right), "already going that way")
        XCTAssertTrue(g.turn(.down))
        XCTAssertFalse(g.turn(.up), "reverse of the queued turn")
        XCTAssertTrue(g.turn(.left), "a quick U-turn: down, then left")
        XCTAssertFalse(g.turn(.down), "only two turns wait at once")
        g.step(); g.step()
        XCTAssertEqual(g.body, [P(4, 6), P(5, 6), P(5, 5)])
    }

    func testEatingGrowsScoresAndSpeedsUp() {
        var g = SnakeGame(width: 10, height: 10, body: [P(5, 5), P(4, 5), P(3, 5)], direction: .right, food: P(6, 5))
        XCTAssertEqual(g.step(), .ate)
        XCTAssertEqual(g.score, 1)
        XCTAssertEqual(g.body, [P(6, 5), P(5, 5), P(4, 5), P(3, 5)])
        XCTAssertNotNil(g.food)
        XCTAssertFalse(g.body.contains(g.food!))
        XCTAssertEqual(g.stepMilliseconds, 156)
        XCTAssertEqual(g.step(), .moved)
        XCTAssertEqual(g.length, 4)
    }

    func testSpeedHasAFloor() {
        let body = [P(5, 5), P(4, 5), P(3, 5)]
        XCTAssertEqual(SnakeGame(width: 10, height: 10, body: body, direction: .right, food: nil, score: 10).stepMilliseconds, 120)
        XCTAssertEqual(SnakeGame(width: 10, height: 10, body: body, direction: .right, food: nil, score: 23).stepMilliseconds, 70)
        XCTAssertEqual(SnakeGame(width: 10, height: 10, body: body, direction: .right, food: nil, score: 80).stepMilliseconds, 70)
    }

    func testHittingAWallEndsIt() {
        var g = SnakeGame(width: 5, height: 3, body: [P(4, 1), P(3, 1), P(2, 1)], direction: .right, food: nil)
        XCTAssertEqual(g.step(), .died)
        XCTAssertEqual(g.status, .over)
        XCTAssertNil(g.step())
        XCTAssertFalse(g.turn(.up), "no steering once it's over")
    }

    func testBitingYourselfEndsIt() {
        // A hook: head at (2,2) going up runs into its own body at (2,1).
        var g = SnakeGame(width: 6, height: 6,
                          body: [P(2, 2), P(3, 2), P(3, 1), P(2, 1), P(1, 1)], direction: .left, food: nil)
        g.turn(.up)
        XCTAssertEqual(g.step(), .died)
        XCTAssertEqual(g.status, .over)
    }

    func testChasingYourTailIsFine() {
        // A ring of four: the head moves into the cell the tail is leaving.
        var g = SnakeGame(width: 4, height: 4, body: [P(1, 1), P(1, 2), P(2, 2), P(2, 1)], direction: .up, food: P(3, 3))
        g.turn(.right)
        XCTAssertEqual(g.step(), .moved)
        XCTAssertEqual(g.head, P(2, 1))
        XCTAssertEqual(g.status, .playing)
    }

    func testFillingTheBoardWins() {
        // 5 by 3 with one free cell, (4,2), and the dot on it.
        let body = [P(3, 2), P(2, 2), P(1, 2), P(0, 2), P(0, 1), P(1, 1), P(2, 1), P(3, 1), P(4, 1),
                    P(4, 0), P(3, 0), P(2, 0), P(1, 0), P(0, 0)]
        var g = SnakeGame(width: 5, height: 3, body: body, direction: .right, food: P(4, 2))
        XCTAssertEqual(g.step(), .won)
        XCTAssertEqual(g.status, .won)
        XCTAssertNil(g.food)
        XCTAssertEqual(g.length, 15)
        XCTAssertEqual(g.score, 1)
    }
}
