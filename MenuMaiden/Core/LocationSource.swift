import Foundation

/// Where the app should get its current position from.
enum LocationSource: String, CaseIterable, Codable {
    case systemLocationServices
    case usbGPS

    var label: String {
        switch self {
        case .systemLocationServices: return "Location Services"
        case .usbGPS: return "USB Serial NMEA GPS"
        }
    }
}
