import Foundation
import CoreLocation

/// A single resolved position + time reading from a GPS receiver.
struct GPSFix: Equatable {
    let coordinate: CLLocationCoordinate2D
    let utcTime: Date

    static func == (lhs: GPSFix, rhs: GPSFix) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
            && lhs.utcTime == rhs.utcTime
    }
}

/// Splits a growing buffer of raw serial bytes into complete lines. Pure and
/// side-effect free (mutates only the buffer passed to it), so it's unit testable
/// without a real serial port.
enum NMEALineSplitter {
    /// Extracts every complete line currently in `buffer`, removing them from it and
    /// leaving any trailing partial line for the next call. Empty lines are dropped.
    ///
    /// Splits on `\.isNewline` rather than comparing characters to "\n"/"\r": Swift's
    /// `Character` model treats a "\r\n" pair as a single grapheme cluster, so an
    /// equality check against either character alone silently never matches CRLF input.
    static func extractLines(from buffer: inout String) -> [String] {
        var lines: [String] = []
        while let newlineIndex = buffer.firstIndex(where: \.isNewline) {
            let line = String(buffer[buffer.startIndex..<newlineIndex])
            buffer.removeSubrange(buffer.startIndex...newlineIndex)
            if !line.isEmpty {
                lines.append(line)
            }
        }
        return lines
    }
}

/// Parses NMEA 0183 sentences from a GPS receiver. Pure and side-effect free,
/// so it can be unit tested without a real serial port.
enum NMEAParser {
    /// Checksum-only validity check, independent of sentence type. Useful for probing
    /// a serial connection (e.g. auto-baud-rate detection) before caring what the
    /// sentence actually says.
    static func isChecksumValid(line: String) -> Bool {
        checksumValidatedBody(of: line) != nil
    }

    private static func checksumValidatedBody(of line: String) -> Substring? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("$"), let starIndex = trimmed.firstIndex(of: "*") else { return nil }

        let body = trimmed[trimmed.index(after: trimmed.startIndex)..<starIndex]
        let checksumField = trimmed[trimmed.index(after: starIndex)...]
        guard checksumField.count == 2, let expectedChecksum = UInt8(checksumField, radix: 16) else { return nil }

        let actualChecksum = body.utf8.reduce(UInt8(0)) { $0 ^ $1 }
        guard actualChecksum == expectedChecksum else { return nil }

        return body
    }

    /// Parses a single NMEA line into a GPSFix, or nil if the line isn't a
    /// recognized/valid sentence (bad checksum, wrong type, void fix, malformed fields).
    static func parse(line: String) -> GPSFix? {
        guard let body = checksumValidatedBody(of: line) else { return nil }

        let fields = body.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        guard let sentenceType = fields.first, sentenceType.hasSuffix("RMC") else { return nil }

        return parseRMC(fields: fields)
    }

    /// $GPRMC/$GNRMC: 0=type 1=time 2=status(A/V) 3=lat 4=N/S 5=lon 6=E/W 7=speed 8=course 9=date ...
    private static func parseRMC(fields: [String]) -> GPSFix? {
        guard fields.count >= 10, fields[2] == "A" else { return nil }

        guard let latitude = parseCoordinate(value: fields[3], hemisphere: fields[4], degreeDigits: 2),
              let longitude = parseCoordinate(value: fields[5], hemisphere: fields[6], degreeDigits: 3),
              let utcTime = parseDateTime(timeField: fields[1], dateField: fields[9]) else {
            return nil
        }

        return GPSFix(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), utcTime: utcTime)
    }

    private static func parseCoordinate(value: String, hemisphere: String, degreeDigits: Int) -> Double? {
        guard value.contains("."), value.count > degreeDigits else { return nil }

        let degreesEnd = value.index(value.startIndex, offsetBy: degreeDigits)
        guard let degrees = Double(value[value.startIndex..<degreesEnd]),
              let minutes = Double(value[degreesEnd...]) else { return nil }

        switch hemisphere {
        case "N", "E": return degrees + minutes / 60
        case "S", "W": return -(degrees + minutes / 60)
        default: return nil
        }
    }

    private static func parseDateTime(timeField: String, dateField: String) -> Date? {
        guard timeField.count >= 6, dateField.count == 6 else { return nil }

        let time = Array(timeField.prefix(6))
        let date = Array(dateField)
        guard let hour = Int(String(time[0...1])), let minute = Int(String(time[2...3])), let second = Int(String(time[4...5])),
              let day = Int(String(date[0...1])), let month = Int(String(date[2...3])), let yearSuffix = Int(String(date[4...5])) else {
            return nil
        }

        var components = DateComponents()
        components.year = 2000 + yearSuffix
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: components)
    }
}
