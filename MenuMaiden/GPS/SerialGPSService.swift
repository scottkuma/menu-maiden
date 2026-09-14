import Foundation
import Darwin

/// Current state of the GPS connection, for driving Settings UI messaging.
enum GPSStatus: Equatable {
    case noDeviceSelected
    case deviceNotFound
    case connecting
    case detectingBaudRate
    case waitingForFix
    case fixAcquired(GPSFix)
    case error(String)

    var fix: GPSFix? {
        if case .fixAcquired(let fix) = self { return fix }
        return nil
    }

    var message: String {
        switch self {
        case .noDeviceSelected: return "No GPS device selected."
        case .deviceNotFound: return "GPS device not attached."
        case .connecting: return "Connecting…"
        case .detectingBaudRate: return "Detecting baud rate…"
        case .waitingForFix: return "Connected. Waiting for a satellite fix…"
        case .fixAcquired: return "Fix acquired."
        case .error(let message): return message
        }
    }
}

/// Reads NMEA sentences from a USB serial GPS receiver. Owns real, blocking POSIX
/// I/O on a background queue; not `@MainActor` for that reason. `@Published`
/// updates are always hopped onto the main queue for SwiftUI/Combine observers.
///
/// `@unchecked Sendable`: `fileDescriptor`, `readSource`, and `generation` are only
/// ever touched while running on `ioQueue` (including from `connect`/`disconnect`,
/// which hop onto it immediately), so access to them is serialized by construction.
final class SerialGPSService: ObservableObject, @unchecked Sendable {
    static let commonBaudRates = [4800, 9600, 19200, 38400, 57600, 115200]
    private static let messageLogCapacity = 200
    private static let baudDetectionWindow: TimeInterval = 1.5

    /// RMC sentences arrive roughly once a second; a receiver that's lost satellite lock
    /// (antenna covered, indoors, etc.) can stop producing valid fixes while the serial
    /// port itself stays open with no read error — `status` would otherwise sit frozen on
    /// the last good `.fixAcquired` forever. A few seconds of tolerance absorbs the
    /// occasional dropped/garbled sentence without falsely flagging a still-healthy GPS.
    private static let fixStalenessThreshold: TimeInterval = 5

    @Published private(set) var status: GPSStatus = .noDeviceSelected
    @Published private(set) var recentMessages: [String] = []

    /// Snapshotted once per fix, right when its sentence is read — not recomputed against
    /// a live clock. GPS fixes update roughly once a second; comparing `fix.utcTime` against
    /// `Date()` on every UI refresh made this sawtooth from ~0s up to ~1s between updates,
    /// since the system clock keeps advancing while the GPS timestamp sits still until the
    /// next sentence arrives. Holding one value steady between fixes reports actual clock
    /// skew instead of that polling artifact.
    @Published private(set) var clockOffset: TimeInterval?

    /// When the most recent valid fix was received (wall-clock receipt time, not the GPS's
    /// own reported time) — used to detect a stale/frozen fix, not to display anything.
    private var lastFixReceivedAt: Date?

    /// True only when there's a currently-connected GPS with a fix received recently enough
    /// to trust — the single source of truth for whether it's safe to act on `clockOffset`
    /// (e.g. enabling "Sync System Clock to GPS").
    var hasFreshFix: Bool {
        guard status.fix != nil, let lastFixReceivedAt else { return false }
        return Date().timeIntervalSince(lastFixReceivedAt) < Self.fixStalenessThreshold
    }

    private let ioQueue = DispatchQueue(label: "net.scottkuma.MenuMaiden.gps-serial")
    private var fileDescriptor: Int32 = -1
    private var readSource: DispatchSourceRead?
    private var generation = 0

    func connect(to devicePath: String, baudRate: Int?) {
        setStatus(.connecting)

        ioQueue.async { [weak self] in
            guard let self else { return }
            self.generation += 1
            let myGeneration = self.generation
            self.closePort()

            if let baudRate {
                self.openAndRead(path: devicePath, baudRate: baudRate, generation: myGeneration)
            } else {
                self.detectBaudRateAndRead(path: devicePath, generation: myGeneration)
            }
        }
    }

    func disconnect() {
        ioQueue.async { [weak self] in
            guard let self else { return }
            self.generation += 1
            self.closePort()
            self.setStatus(.noDeviceSelected)
        }
    }

    // MARK: - Baud detection

    private func detectBaudRateAndRead(path: String, generation: Int) {
        setStatus(.detectingBaudRate)

        for candidate in Self.commonBaudRates {
            guard generation == self.generation else { return }
            guard let fd = openPort(path: path, baudRate: candidate) else {
                logDiagnostic("[\(candidate) baud] couldn't open port: \(String(cString: strerror(errno)))")
                continue
            }

            if probeForValidSentence(fd: fd, baud: candidate, timeout: Self.baudDetectionWindow) {
                guard generation == self.generation else {
                    Darwin.close(fd)
                    return
                }
                beginReading(fd: fd, generation: generation)
                return
            }
            Darwin.close(fd)
        }

        guard generation == self.generation else { return }
        setStatus(.error("Couldn't auto-detect GPS baud rate. Try selecting one manually."))
    }

    /// Also logs whatever it sees (valid or not) to `recentMessages`, tagged with the
    /// baud rate being tried, so a failed auto-detect is diagnosable instead of opaque:
    /// silence vs. garbled bytes point at very different problems (wiring/power vs. baud).
    private func probeForValidSentence(fd: Int32, baud: Int, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        var buffer = [UInt8](repeating: 0, count: 256)
        var pending = ""
        var sawAnyBytes = false

        while Date() < deadline {
            let bytesRead = read(fd, &buffer, buffer.count)
            if bytesRead > 0 {
                sawAnyBytes = true
                pending += String(decoding: buffer[0..<bytesRead], as: UTF8.self)
                for line in NMEALineSplitter.extractLines(from: &pending) {
                    logDiagnostic("[\(baud) baud] \(line)")
                    if NMEAParser.isChecksumValid(line: line) {
                        return true
                    }
                }
            } else {
                usleep(50_000)
            }
        }
        if !sawAnyBytes {
            logDiagnostic("[\(baud) baud] (no data received)")
        }
        return false
    }

    private func logDiagnostic(_ line: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.recentMessages.append(line)
            if self.recentMessages.count > Self.messageLogCapacity {
                self.recentMessages.removeFirst(self.recentMessages.count - Self.messageLogCapacity)
            }
        }
    }

    private func openAndRead(path: String, baudRate: Int, generation: Int) {
        guard let fd = openPort(path: path, baudRate: baudRate) else {
            setStatus(.deviceNotFound)
            return
        }
        beginReading(fd: fd, generation: generation)
    }

    // MARK: - Port lifecycle

    private func openPort(path: String, baudRate: Int) -> Int32? {
        // Opened O_RDWR even though we only read: on macOS, O_RDONLY frequently fails to
        // properly assert the control lines (DTR/RTS) a USB-serial GPS needs to start
        // transmitting, leaving the port silent even though the open() call itself succeeds.
        let fd = open(path, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard fd >= 0 else { return nil }

        var options = termios()
        tcgetattr(fd, &options)
        cfmakeraw(&options)
        let speed = speed_t(baudRate)
        cfsetispeed(&options, speed)
        cfsetospeed(&options, speed)
        options.c_cflag |= tcflag_t(CS8 | CLOCAL | CREAD)
        tcsetattr(fd, TCSANOW, &options)
        tcflush(fd, TCIOFLUSH)

        // Left non-blocking: the baud-rate probe polls with a timeout, and the
        // DispatchSourceRead-driven read loop only reads when data is actually available.
        return fd
    }

    private func beginReading(fd: Int32, generation: Int) {
        fileDescriptor = fd
        setStatus(.waitingForFix)

        var pending = ""
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: ioQueue)
        source.setEventHandler { [weak self] in
            guard let self, generation == self.generation else { return }

            var buffer = [UInt8](repeating: 0, count: 1024)
            let bytesRead = read(fd, &buffer, buffer.count)

            if bytesRead < 0 {
                let currentErrno = errno
                if currentErrno == EAGAIN || currentErrno == EWOULDBLOCK {
                    return // fd is non-blocking; no data available right now
                }
                self.handleDisconnect(generation: generation)
                return
            } else if bytesRead == 0 {
                self.handleDisconnect(generation: generation)
                return
            }

            // Captured as close to the actual byte-receipt as possible (before the hop to
            // main), rather than inside handle(), so the offset reflects when the data
            // truly arrived rather than whenever the main queue happened to run.
            let receivedAt = Date()
            pending += String(decoding: buffer[0..<bytesRead], as: UTF8.self)
            for line in NMEALineSplitter.extractLines(from: &pending) {
                self.handle(line: line, generation: generation, receivedAt: receivedAt)
            }
        }
        source.setCancelHandler {
            Darwin.close(fd)
        }
        readSource = source
        source.resume()
    }

    private func handle(line: String, generation: Int, receivedAt: Date) {
        DispatchQueue.main.async { [weak self] in
            guard let self, generation == self.generation else { return }

            self.recentMessages.append(line)
            if self.recentMessages.count > Self.messageLogCapacity {
                self.recentMessages.removeFirst(self.recentMessages.count - Self.messageLogCapacity)
            }

            if let fix = NMEAParser.parse(line: line) {
                self.status = .fixAcquired(fix)
                self.clockOffset = receivedAt.timeIntervalSince(fix.utcTime)
                self.lastFixReceivedAt = receivedAt
            }
        }
    }

    private func handleDisconnect(generation: Int) {
        guard generation == self.generation else { return }
        closePort()
        setStatus(.deviceNotFound)
    }

    private func closePort() {
        readSource?.cancel()
        readSource = nil
        if fileDescriptor >= 0 {
            fileDescriptor = -1
        }
    }

    private func setStatus(_ status: GPSStatus) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.status = status
            // Any transition away from a fix (disconnect, error, reconnecting, ...) means
            // the snapshotted offset no longer reflects anything current — clear it rather
            // than leave a stale reading on screen.
            if status.fix == nil {
                self.clockOffset = nil
                self.lastFixReceivedAt = nil
            }
        }
    }
}
