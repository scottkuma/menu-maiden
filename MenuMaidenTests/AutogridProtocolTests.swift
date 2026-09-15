import XCTest
@testable import MenuMaiden

final class AutogridProtocolTests: XCTestCase {
    func testHeaderFields() {
        let data = AutogridProtocol.locationMessage(clientId: "MenuMaiden", gridSquare: "EM79vi")
        let bytes = [UInt8](data)

        XCTAssertEqual(bytes[0...3], [0xAD, 0xBC, 0xCB, 0xDA]) // magic
        XCTAssertEqual(bytes[4...7], [0x00, 0x00, 0x00, 0x02]) // defaultSchema = 2, confirmed against a real WSJT-X 3.0.2 instance
        XCTAssertEqual(bytes[8...11], [0x00, 0x00, 0x00, 0x0B]) // messageType 11 (Location)
    }

    // Hand-computed full byte layout for a short fixture, so this doesn't just
    // re-decode the encoder's own assumptions back at itself.
    func testExactByteLayout() {
        let data = AutogridProtocol.locationMessage(clientId: "MM", gridSquare: "EM79vi")
        let expected: [UInt8] = [
            0xAD, 0xBC, 0xCB, 0xDA, // magic
            0x00, 0x00, 0x00, 0x02, // schema (defaultSchema)
            0x00, 0x00, 0x00, 0x0B, // messageType = 11
            0x00, 0x00, 0x00, 0x02, // Id length = 2
            0x4D, 0x4D, //             "MM"
            0x00, 0x00, 0x00, 0x06, // Location length = 6
            0x45, 0x4D, 0x37, 0x39, 0x76, 0x69 // "EM79vi"
        ]
        XCTAssertEqual([UInt8](data), expected)
    }

    func testLengthMatchesUTF8ByteCounts() {
        let clientId = "MenuMaiden"
        let gridSquare = "FN31pr"
        let data = AutogridProtocol.locationMessage(clientId: clientId, gridSquare: gridSquare)
        let expectedLength = 12 + 4 + clientId.utf8.count + 4 + gridSquare.utf8.count
        XCTAssertEqual(data.count, expectedLength)
    }

    func testExplicitSchemaOverridesDefault() {
        let data = AutogridProtocol.locationMessage(clientId: "MM", gridSquare: "EM79vi", schema: 3)
        let bytes = [UInt8](data)
        XCTAssertEqual(bytes[4...7], [0x00, 0x00, 0x00, 0x03])
    }

    // MARK: - Decoding, fixtures captured directly off a real running WSJT-X 3.0.2

    private func data(fromHex hex: String) -> Data {
        var data = Data()
        var chars = Array(hex)
        while chars.count >= 2 {
            data.append(UInt8(String(chars[0...1]), radix: 16)!)
            chars.removeFirst(2)
        }
        return data
    }

    func testHeaderParsesRealHeartbeatPacket() {
        let packet = data(fromHex: "adbccbda00000002000000000000000657534a542d580000000300000005332e302e3200000006636364666166")
        let header = AutogridProtocol.header(from: packet)
        XCTAssertEqual(header?.schema, 2)
        XCTAssertEqual(header?.messageType, AutogridProtocol.heartbeatMessageType)
    }

    func testHeaderRejectsWrongMagic() {
        let packet = data(fromHex: "00000000000000020000000b")
        XCTAssertNil(AutogridProtocol.header(from: packet))
    }

    func testHeartbeatDecodesRealPacket() {
        // Captured directly off a real running WSJT-X 3.0.2 instance.
        let packet = data(fromHex: "adbccbda00000002000000000000000657534a542d580000000300000005332e302e3200000006636364666166")
        let heartbeat = AutogridProtocol.heartbeat(from: packet)
        XCTAssertEqual(heartbeat?.id, "WSJT-X")
        XCTAssertEqual(heartbeat?.version, "3.0.2")
        XCTAssertEqual(heartbeat?.revision, "ccdfaf")
    }

    func testHeartbeatReturnsNilForNonHeartbeatMessage() {
        let locationPacket = AutogridProtocol.locationMessage(clientId: "MM", gridSquare: "EM79vi")
        XCTAssertNil(AutogridProtocol.heartbeat(from: locationPacket))
    }
}
