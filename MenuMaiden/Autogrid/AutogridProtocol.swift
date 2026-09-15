import Foundation

/// A peer's self-reported identity, decoded from its Heartbeat message (type 0) — the
/// message WSJT-X/JTDX broadcasts to announce itself and its schema/version. Confirmed
/// directly against a real running WSJT-X 3.0.2 instance: Id "WSJT-X", version "3.0.2",
/// revision "ccdfaf" (a short git hash).
struct AutogridHeartbeat: Equatable {
    let id: String
    let version: String?
    let revision: String?
}

/// Encodes/decodes WSJT-X/JTDX's UDP "NetworkMessage" protocol. Pure and side-effect
/// free, so it's unit testable without a real socket.
///
/// Byte layout (all integers big-endian), verified directly against WSJT-X's own
/// protocol source (NetworkMessage.hpp) rather than assumed from memory:
///   quint32  magic       = 0xadbccbda
///   quint32  schema                      (negotiated — see `defaultSchema`)
///   quint32  messageType                 (0 = Heartbeat, 11 = Location)
///   ...message-specific fields
/// where `utf8` is a quint32 byte count followed by that many raw UTF-8 bytes — not
/// Qt's native UTF-16 QString format — and a length of 0xffffffff means a null string.
enum AutogridProtocol {
    static let magic: UInt32 = 0xadbccbda
    /// Fallback only, used until a peer's own schema is observed live. The protocol docs'
    /// "Qt_5_4 format" language suggested 3 for modern builds, but a real running WSJT-X
    /// 3.0.2 instance was observed declaring schema 2 in its own outbound Status message —
    /// the protocol's negotiation rules say not to send a higher schema than the peer
    /// uses, so `AutogridReceiver` reads the real value off received traffic and that
    /// should always be preferred over this constant once available.
    static let defaultSchema: UInt32 = 2
    static let heartbeatMessageType: UInt32 = 0
    private static let locationMessageType: UInt32 = 11

    struct Header: Equatable {
        let schema: UInt32
        let messageType: UInt32
    }

    static func locationMessage(clientId: String, gridSquare: String, schema: UInt32 = defaultSchema) -> Data {
        var data = Data()
        data.appendBigEndian(magic)
        data.appendBigEndian(schema)
        data.appendBigEndian(locationMessageType)
        data.appendUTF8String(clientId)
        data.appendUTF8String(gridSquare)
        return data
    }

    /// Parses the common 12-byte header, verifying the magic number first so unrelated
    /// UDP traffic on the same port can't be misread as this protocol.
    static func header(from data: Data) -> Header? {
        var reader = ByteReader(data: data)
        guard reader.readUInt32() == magic, let schema = reader.readUInt32(), let messageType = reader.readUInt32() else {
            return nil
        }
        return Header(schema: schema, messageType: messageType)
    }

    /// Parses a Heartbeat message's fields (Id, then a "Maximum schema number" quint32,
    /// then version and revision strings). The protocol docs say the schema-number field
    /// only appears for schema >= 3, but a real WSJT-X 3.0.2 instance included it while
    /// declaring schema 2 — read unconditionally, and version/revision are best-effort
    /// (nil, not a parse failure, if trailing bytes are short).
    static func heartbeat(from data: Data) -> AutogridHeartbeat? {
        guard let header = header(from: data), header.messageType == heartbeatMessageType else { return nil }
        var reader = ByteReader(data: data, offset: 12)
        guard let id = reader.readUTF8String() else { return nil }
        _ = reader.readUInt32() // Maximum schema number — not currently surfaced
        return AutogridHeartbeat(id: id, version: reader.readUTF8String(), revision: reader.readUTF8String())
    }
}

/// Sequential big-endian reader over raw bytes, shared by header/message parsing above.
private struct ByteReader {
    private let bytes: [UInt8]
    private var offset: Int

    init(data: Data, offset: Int = 0) {
        self.bytes = [UInt8](data)
        self.offset = offset
    }

    mutating func readUInt32() -> UInt32? {
        guard offset + 4 <= bytes.count else { return nil }
        let value = UInt32(bytes[offset]) << 24 | UInt32(bytes[offset + 1]) << 16
            | UInt32(bytes[offset + 2]) << 8 | UInt32(bytes[offset + 3])
        offset += 4
        return value
    }

    mutating func readUTF8String() -> String? {
        guard let length = readUInt32(), length != 0xffffffff else { return nil }
        guard offset + Int(length) <= bytes.count else { return nil }
        let slice = bytes[offset..<offset + Int(length)]
        offset += Int(length)
        return String(decoding: slice, as: UTF8.self)
    }
}

private extension Data {
    mutating func appendBigEndian(_ value: UInt32) {
        append(contentsOf: Swift.withUnsafeBytes(of: value.bigEndian) { Array($0) })
    }

    mutating func appendUTF8String(_ string: String) {
        let bytes = Array(string.utf8)
        appendBigEndian(UInt32(bytes.count))
        append(contentsOf: bytes)
    }
}
