import Foundation
import Network
import Combine

/// Listens on the configured Autogrid port for WSJT-X's own outbound Heartbeat/Status
/// broadcasts, purely to learn its current return address and identify what's connected.
///
/// In WSJT-X's UDP protocol, WSJT-X itself is the "client": it sends its own state to a
/// configured server address (the port configured here and in WSJT-X's own Reporting
/// settings), and only listens for replies on the ephemeral local port its own packets
/// were sent from — not on that fixed configured port. Nothing is listening there unless
/// something explicitly binds it, so a fire-and-forget send to that port goes nowhere; the
/// only way to learn WSJT-X's actual return address is to bind that port ourselves and
/// read it off live traffic. Confirmed directly: binding port 2237 and observing WSJT-X's
/// own Status messages arrive from an unrelated ephemeral source port.
///
/// Replies are sent back out on this same accepted `NWConnection`, not a freshly opened
/// one: a second socket also wanting local port 2237 fails with "Address already in use"
/// (confirmed directly — `NWConnection(to:using:)` to the learned peer just sat in
/// `.waiting` forever), and reusing the connection WSJT-X itself already opened to us is
/// both the fix and the more correct design — it's already the exact right local/remote
/// pair.
@MainActor
final class AutogridReceiver: ObservableObject {
    private var listener: NWListener?
    private var activeConnections: [ObjectIdentifier: NWConnection] = [:]
    private(set) var lastKnownConnection: NWConnection?
    /// The schema number the peer's own traffic declares, read live off its packet
    /// header — preferred over `AutogridProtocol.defaultSchema` whenever available, since
    /// the protocol's negotiation rules say not to send a higher schema than the peer uses.
    private(set) var lastKnownSchema: UInt32?
    /// The peer's self-reported identity from its most recent Heartbeat message, surfaced
    /// in Settings so the user can see Menu Maiden actually hearing WSJT-X/JTDX, not just
    /// assume it. `@Published` so the Autogrid Settings tab updates live.
    @Published private(set) var lastHeartbeat: AutogridHeartbeat?

    /// `lastKnownConnection`'s remote address, for display alongside `lastHeartbeat` —
    /// lets the user visually confirm who Menu Maiden actually considers "connected"
    /// rather than taking it on faith.
    var lastKnownPeerAddress: String? {
        guard let endpoint = lastKnownConnection?.endpoint else { return nil }
        if case .hostPort(let host, let port) = endpoint {
            return "\(host):\(port)"
        }
        return "\(endpoint)"
    }

    func start(port: Int) {
        stop()
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)),
              let newListener = try? NWListener(using: .udp, on: nwPort) else { return }

        // NWListener's handler closures are plain @Sendable, not statically MainActor-
        // isolated, even though `.start(queue: .main)` below guarantees they actually run
        // on the main queue at runtime — Task { @MainActor in ... } bridges that gap.
        newListener.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in
                self?.accept(connection)
            }
        }
        newListener.start(queue: .main)
        listener = newListener
    }

    private func accept(_ connection: NWConnection) {
        let key = ObjectIdentifier(connection)
        activeConnections[key] = connection
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .cancelled, .failed:
                Task { @MainActor in
                    self?.activeConnections.removeValue(forKey: key)
                    if self?.lastKnownConnection === connection {
                        self?.lastKnownConnection = nil
                    }
                }
            default:
                break
            }
        }
        connection.start(queue: .main)
        receive(on: connection)
    }

    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            Task { @MainActor in
                guard let self else { return }
                if let data, let header = AutogridProtocol.header(from: data) {
                    if header.messageType == AutogridProtocol.heartbeatMessageType,
                       let heartbeat = AutogridProtocol.heartbeat(from: data) {
                        // A successfully parsed Heartbeat is what establishes trust in this
                        // connection as the reply target — security-critical: this used to
                        // be set from ANY received datagram, regardless of whether it even
                        // parsed as this protocol, letting a single unauthenticated packet
                        // from anywhere on the LAN hijack "Send Autogrid"'s destination and
                        // exfiltrate the user's location. Never widen this to accept trust
                        // from any other message type, however well-formed.
                        self.lastKnownConnection = connection
                        self.lastHeartbeat = heartbeat
                        self.lastKnownSchema = header.schema
                    } else if self.lastKnownConnection === connection {
                        // Fine to refresh the schema from later traffic on a connection
                        // already trusted via a prior Heartbeat: it's the same NWConnection
                        // object, and Network.framework guarantees a UDP flow's remote
                        // endpoint can't change out from under it — so this can't be used
                        // to establish trust from an untrusted sender.
                        self.lastKnownSchema = header.schema
                    }
                }
                if error == nil {
                    self.receive(on: connection)
                }
            }
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        activeConnections.values.forEach { $0.cancel() }
        activeConnections.removeAll()
        lastKnownConnection = nil
        lastKnownSchema = nil
        lastHeartbeat = nil
    }
}
