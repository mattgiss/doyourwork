import XCTest
@testable import DoYourWorkCore

final class FamilyGridTests: XCTestCase {
    /// An iPhone's family page, below the heading and above the tab bar.
    let phone = (w: 370.0, h: 600.0)

    func testOnePersonFillsThePage() {
        let l = FamilyGrid.layout(count: 1, width: phone.w, height: phone.h)
        XCTAssertEqual(l.columns, 1)
        XCTAssertEqual(l.rows, 1)
        XCTAssertEqual(l.tileWidth, phone.w, accuracy: 0.01)
        XCTAssertGreaterThan(l.tileHeight, phone.h * 0.8, "nearly the whole page")
        XCTAssertLessThanOrEqual(l.tileHeight, l.tileWidth * FamilyGrid.maxTallness + 0.01)
        XCTAssertFalse(l.scrolls)
    }

    func testTilesShrinkAsPeopleJoin() {
        var last = Double.infinity
        for n in 1...9 {
            let l = FamilyGrid.layout(count: n, width: phone.w, height: phone.h)
            XCTAssertLessThanOrEqual(l.avatar, last + 0.01, "\(n) people")
            XCTAssertGreaterThanOrEqual(l.columns * l.rows, n)
            // Everything fits on the page without scrolling.
            XCTAssertLessThanOrEqual(Double(l.rows) * l.tileHeight + Double(l.rows - 1) * FamilyGrid.gap, phone.h + 0.01, "\(n) people")
            last = l.avatar
        }
    }

    func testTwoStackAndFourMakeASquare() {
        XCTAssertEqual(FamilyGrid.layout(count: 2, width: phone.w, height: phone.h).columns, 1)
        let four = FamilyGrid.layout(count: 4, width: phone.w, height: phone.h)
        XCTAssertEqual(four.columns, 2)
        XCTAssertEqual(four.rows, 2)
    }

    func testABigFamilyScrolls() {
        let l = FamilyGrid.layout(count: 30, width: phone.w, height: phone.h)
        XCTAssertTrue(l.scrolls)
        XCTAssertGreaterThanOrEqual(l.columns, 3)
    }

    func testAWideScreenUsesItsWidth() {
        let l = FamilyGrid.layout(count: 3, width: 1000, height: 600)
        XCTAssertEqual(l.columns, 3)
        XCTAssertEqual(l.rows, 1)
    }
}
