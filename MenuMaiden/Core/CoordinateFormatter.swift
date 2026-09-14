import Foundation

/// Formats latitude/longitude pairs for display and clipboard copy. Pure and
/// side-effect free, so it can be unit tested without any location/GPS source.
enum CoordinateFormatter {
    static func string(latitude: Double, longitude: Double, format: CoordinateFormat, reversed: Bool) -> String {
        let latString: String
        let lonString: String

        switch format {
        case .decimalDegrees:
            latString = String(format: "%.6f", latitude)
            lonString = String(format: "%.6f", longitude)
        case .degreesMinutesSeconds:
            latString = dms(latitude, positive: "N", negative: "S")
            lonString = dms(longitude, positive: "E", negative: "W")
        case .degreesDecimalMinutes:
            latString = ddm(latitude, positive: "N", negative: "S")
            lonString = ddm(longitude, positive: "E", negative: "W")
        }

        return reversed ? "\(lonString), \(latString)" : "\(latString), \(lonString)"
    }

    private static func dms(_ value: Double, positive: String, negative: String) -> String {
        let hemisphere = value >= 0 ? positive : negative
        let absolute = abs(value)
        let degrees = Int(absolute)
        let minutesFull = (absolute - Double(degrees)) * 60
        let minutes = Int(minutesFull)
        let seconds = (minutesFull - Double(minutes)) * 60
        return String(format: "%d° %d' %.2f\" %@", degrees, minutes, seconds, hemisphere)
    }

    private static func ddm(_ value: Double, positive: String, negative: String) -> String {
        let hemisphere = value >= 0 ? positive : negative
        let absolute = abs(value)
        let degrees = Int(absolute)
        let minutes = (absolute - Double(degrees)) * 60
        return String(format: "%d° %.4f' %@", degrees, minutes, hemisphere)
    }
}
