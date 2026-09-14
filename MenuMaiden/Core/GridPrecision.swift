import Foundation

/// The number of characters shown in a Maidenhead Grid Square locator.
enum GridPrecision: Int, CaseIterable, Codable {
    case two = 2
    case four = 4
    case six = 6
    case eight = 8

    /// Cycles 4 -> 6 -> 8 -> 2 -> 4 ..., per the PRD's left-click behavior.
    var next: GridPrecision {
        switch self {
        case .two: return .four
        case .four: return .six
        case .six: return .eight
        case .eight: return .two
        }
    }

    var label: String {
        "\(rawValue) characters"
    }

    /// Approximate cell size at this precision, per the PRD's reference table.
    var distanceDescription: String {
        switch self {
        case .two: return "1,200 × 1,400 mi"
        case .four: return "70 × 100 mi"
        case .six: return "3 × 4 mi"
        case .eight: return "1,500 × 2,300 ft"
        }
    }
}
