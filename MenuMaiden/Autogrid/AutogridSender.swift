import Foundation
import Network

/// Sends a "Location" message to WSJT-X/JTDX over UDP, on an already-open `NWConnection`
/// supplied by `AutogridReceiver` — see that type's doc comment for why a fresh outbound
/// connection can't be opened instead (it collides with the listener on the same local
/// port). Fire-and-forget: no response is expected or parsed, and no error is surfaced to
/// the UI, matching the existing Copy Grid Square / Copy Latitude/Longitude menu actions,
/// which also give no feedback beyond the pasteboard write.
final class AutogridSender {
    func send(gridSquare: String, clientId: String, schema: UInt32, using connection: NWConnection) {
        let payload = AutogridProtocol.locationMessage(clientId: clientId, gridSquare: gridSquare, schema: schema)
        connection.send(content: payload, completion: .contentProcessed { _ in })
    }
}
