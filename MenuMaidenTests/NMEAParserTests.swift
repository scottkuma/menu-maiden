import XCTest
@testable import MenuMaiden

final class NMEAParserTests: XCTestCase {
    // A standard published sample RMC sentence (widely used as an NMEA parsing reference):
    // time 12:35:19 UTC, valid fix, 48°07.038'N 011°31.000'E, date field "230394".
    // The original 1994 reference predates two-digit-year ambiguity handling; like every
    // real-world NMEA consumer, this parser maps two-digit years to 2000-2099 (GPS itself
    // didn't exist before 1980), so the field "94" resolves to 2094 here, not 1994.
    private let sampleRMC = "$GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W*6A"

    func testParsesKnownGoodSentence() throws {
        let fix = try XCTUnwrap(NMEAParser.parse(line: sampleRMC))

        XCTAssertEqual(fix.coordinate.latitude, 48 + 7.038 / 60, accuracy: 0.0001)
        XCTAssertEqual(fix.coordinate.longitude, 11 + 31.0 / 60, accuracy: 0.0001)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fix.utcTime)
        XCTAssertEqual(components.year, 2094)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 23)
        XCTAssertEqual(components.hour, 12)
        XCTAssertEqual(components.minute, 35)
        XCTAssertEqual(components.second, 19)
    }

    func testChecksumValidityMatchesParseability() {
        XCTAssertTrue(NMEAParser.isChecksumValid(line: sampleRMC))
    }

    func testRejectsBadChecksum() {
        let corrupted = "$GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W*00"
        XCTAssertNil(NMEAParser.parse(line: corrupted))
        XCTAssertFalse(NMEAParser.isChecksumValid(line: corrupted))
    }

    func testRejectsVoidFix() {
        let voidFix = "$GPRMC,123519,V,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W*6C"
        XCTAssertNil(NMEAParser.parse(line: voidFix))
    }

    func testIgnoresNonRMCSentences() {
        // A valid-checksum GSV (satellites in view) sentence: not an error, just not handled.
        let gsv = "$GPGSV,3,1,11,03,03,111,00,04,15,270,00,06,01,010,00,13,06,292,00*74"
        XCTAssertNil(NMEAParser.parse(line: gsv))
        XCTAssertTrue(NMEAParser.isChecksumValid(line: gsv))
    }

    func testRejectsMalformedSentence() {
        XCTAssertNil(NMEAParser.parse(line: "$GPRMC,only,a,few,fields*00"))
        XCTAssertNil(NMEAParser.parse(line: "not an nmea sentence at all"))
        XCTAssertNil(NMEAParser.parse(line: ""))
    }
}

final class NMEALineSplitterTests: XCTestCase {
    // Regression test: real GPS receivers terminate NMEA sentences with "\r\n". Swift's
    // Character model treats that pair as a single grapheme cluster, so a naive
    // `character == "\n" || character == "\r"` check silently never matches it and the
    // splitter would never find a line boundary at all. `.isNewline` is required.
    func testSplitsCRLFTerminatedLines() {
        var buffer = "$GPRMC,one*00\r\n$GPGGA,two*11\r\n"
        let lines = NMEALineSplitter.extractLines(from: &buffer)

        XCTAssertEqual(lines, ["$GPRMC,one*00", "$GPGGA,two*11"])
        XCTAssertEqual(buffer, "")
    }

    func testLeavesTrailingPartialLineInBuffer() {
        var buffer = "$GPRMC,complete*00\r\n$GPGGA,incomple"
        let lines = NMEALineSplitter.extractLines(from: &buffer)

        XCTAssertEqual(lines, ["$GPRMC,complete*00"])
        XCTAssertEqual(buffer, "$GPGGA,incomple")
    }

    func testDropsEmptyLines() {
        var buffer = "\r\n\r\n$GPRMC,one*00\r\n"
        let lines = NMEALineSplitter.extractLines(from: &buffer)

        XCTAssertEqual(lines, ["$GPRMC,one*00"])
    }

    func testAlsoHandlesBareLFAndBareCR() {
        var lfBuffer = "$GPRMC,one*00\n$GPGGA,two*11\n"
        XCTAssertEqual(NMEALineSplitter.extractLines(from: &lfBuffer), ["$GPRMC,one*00", "$GPGGA,two*11"])

        var crBuffer = "$GPRMC,one*00\r$GPGGA,two*11\r"
        XCTAssertEqual(NMEALineSplitter.extractLines(from: &crBuffer), ["$GPRMC,one*00", "$GPGGA,two*11"])
    }
}
