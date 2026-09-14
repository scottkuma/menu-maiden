import XCTest
@testable import MenuMaiden

final class MaidenheadGridTests: XCTestCase {
    func testKnownLocator4() {
        // ARRL HQ, Newington CT: 41.7147 N, 72.7273 W -> FN31pr (well-known reference point)
        let locator = MaidenheadGrid.locator(latitude: 41.7147, longitude: -72.7273, precision: .four)
        XCTAssertEqual(locator, "FN31")
    }

    func testKnownLocator6() {
        let locator = MaidenheadGrid.locator(latitude: 41.7147, longitude: -72.7273, precision: .six)
        XCTAssertEqual(locator, "FN31pr")
    }

    func testKnownLocator2() {
        let locator = MaidenheadGrid.locator(latitude: 41.7147, longitude: -72.7273, precision: .two)
        XCTAssertEqual(locator, "FN")
    }

    func testEightCharacterLengthAndPrefix() {
        let locator = MaidenheadGrid.locator(latitude: 41.7147, longitude: -72.7273, precision: .eight)
        XCTAssertEqual(locator.count, 8)
        XCTAssertTrue(locator.hasPrefix("FN31pr"))
    }

    func testSouthernHemisphereAndOrigin() {
        // Sydney, Australia: -33.8688, 151.2093 -> QF56
        let locator = MaidenheadGrid.locator(latitude: -33.8688, longitude: 151.2093, precision: .four)
        XCTAssertEqual(locator, "QF56")
    }

    func testEquatorPrimeMeridian() {
        // 0,0 sits at the boundary between fields; should not crash and should
        // land in the JJ field per the standard convention.
        let locator = MaidenheadGrid.locator(latitude: 0, longitude: 0, precision: .two)
        XCTAssertEqual(locator, "JJ")
    }

    func testPoleAndDatelineDoNotOverflow() {
        XCTAssertNoThrow(MaidenheadGrid.locator(latitude: 90, longitude: 180, precision: .eight))
        XCTAssertNoThrow(MaidenheadGrid.locator(latitude: -90, longitude: -180, precision: .eight))
    }

    func testUppercaseDefaultsToFalse() {
        let locator = MaidenheadGrid.locator(latitude: 41.7147, longitude: -72.7273, precision: .six)
        XCTAssertEqual(locator, "FN31pr")
    }

    func testUppercaseTrueUppercasesTheSubsquareLetters() {
        let locator = MaidenheadGrid.locator(latitude: 41.7147, longitude: -72.7273, precision: .six, uppercase: true)
        XCTAssertEqual(locator, "FN31PR")
    }
}

final class GridPrecisionTests: XCTestCase {
    func testCycleOrder() {
        XCTAssertEqual(GridPrecision.two.next, .four)
        XCTAssertEqual(GridPrecision.four.next, .six)
        XCTAssertEqual(GridPrecision.six.next, .eight)
        XCTAssertEqual(GridPrecision.eight.next, .two)
    }
}
