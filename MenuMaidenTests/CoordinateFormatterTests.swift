import XCTest
@testable import MenuMaiden

final class CoordinateFormatterTests: XCTestCase {
    // Fixture straight from the PRD's own worked example.
    private let lat = 39.123456
    private let lon = -84.123456

    func testDecimalDegrees() {
        let result = CoordinateFormatter.string(latitude: lat, longitude: lon, format: .decimalDegrees, reversed: false)
        XCTAssertEqual(result, "39.123456, -84.123456")
    }

    func testDegreesMinutesSeconds() {
        let result = CoordinateFormatter.string(latitude: lat, longitude: lon, format: .degreesMinutesSeconds, reversed: false)
        XCTAssertEqual(result, "39° 7' 24.44\" N, 84° 7' 24.44\" W")
    }

    func testDegreesDecimalMinutes() {
        let result = CoordinateFormatter.string(latitude: lat, longitude: lon, format: .degreesDecimalMinutes, reversed: false)
        XCTAssertEqual(result, "39° 7.4074' N, 84° 7.4074' W")
    }

    func testReversedOrderSwapsLatAndLon() {
        let result = CoordinateFormatter.string(latitude: lat, longitude: lon, format: .decimalDegrees, reversed: true)
        XCTAssertEqual(result, "-84.123456, 39.123456")
    }

    func testSouthAndWestHemispheresForNegativeCoordinates() {
        let result = CoordinateFormatter.string(latitude: -lat, longitude: -lon, format: .degreesMinutesSeconds, reversed: false)
        XCTAssertEqual(result, "39° 7' 24.44\" S, 84° 7' 24.44\" E")
    }
}
