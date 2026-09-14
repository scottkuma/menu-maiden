import Foundation

/// How latitude/longitude coordinates are displayed and copied.
enum CoordinateFormat: String, CaseIterable, Codable {
    case decimalDegrees
    case degreesMinutesSeconds
    case degreesDecimalMinutes

    var label: String {
        switch self {
        case .decimalDegrees: return "Decimal Degrees (DD)"
        case .degreesMinutesSeconds: return "Degrees, Minutes, Seconds (DMS)"
        case .degreesDecimalMinutes: return "Degrees and Decimal Minutes (DDM)"
        }
    }

    var example: String {
        switch self {
        case .decimalDegrees: return "39.123456, -84.123456"
        case .degreesMinutesSeconds: return "39° 7' 24.44\" N, 84° 7' 24.44\" W"
        case .degreesDecimalMinutes: return "39° 7.4074' N, 84° 7.4074' W"
        }
    }
}
