import Foundation
import Combine

/// User-configurable settings, persisted to UserDefaults (local storage only, per the PRD).
final class AppSettings: ObservableObject {
    private enum Keys {
        static let precision = "precision"
        static let launchAtStart = "launchAtStart"
        static let locationSource = "locationSource"
        static let selectedGPSDevicePath = "selectedGPSDevicePath"
        static let gpsBaudRate = "gpsBaudRate"
        static let allCapsGrid = "allCapsGrid"
        static let coordinateFormat = "coordinateFormat"
        static let reverseLatLon = "reverseLatLon"
        static let clockSyncCompensationMs = "clockSyncCompensationMs"
    }

    private let defaults: UserDefaults

    @Published var precision: GridPrecision {
        didSet { defaults.set(precision.rawValue, forKey: Keys.precision) }
    }

    @Published var launchAtStart: Bool {
        didSet { defaults.set(launchAtStart, forKey: Keys.launchAtStart) }
    }

    @Published var locationSource: LocationSource {
        didSet { defaults.set(locationSource.rawValue, forKey: Keys.locationSource) }
    }

    @Published var selectedGPSDevicePath: String? {
        didSet { defaults.set(selectedGPSDevicePath, forKey: Keys.selectedGPSDevicePath) }
    }

    /// nil means "Auto" (baud rate auto-detection).
    @Published var gpsBaudRate: Int? {
        didSet {
            if let gpsBaudRate {
                defaults.set(gpsBaudRate, forKey: Keys.gpsBaudRate)
            } else {
                defaults.removeObject(forKey: Keys.gpsBaudRate)
            }
        }
    }

    @Published var allCapsGrid: Bool {
        didSet { defaults.set(allCapsGrid, forKey: Keys.allCapsGrid) }
    }

    @Published var coordinateFormat: CoordinateFormat {
        didSet { defaults.set(coordinateFormat.rawValue, forKey: Keys.coordinateFormat) }
    }

    @Published var reverseLatLon: Bool {
        didSet { defaults.set(reverseLatLon, forKey: Keys.reverseLatLon) }
    }

    /// A fixed, user-calibrated correction (milliseconds) subtracted from the measured
    /// clock offset before it's rounded to a whole second for "Sync System Clock to GPS".
    /// `date`'s SET syntax only accepts whole seconds, so the sub-second delay between a
    /// GPS's internal clock tick and the app finishing parsing that fix's NMEA sentence —
    /// real serial/chipset latency, not noise — otherwise lands in the same direction every
    /// sync instead of averaging out. There's no way to measure that delay in software
    /// without a ground-truth clock, so it's tuned by hand per device/baud rate.
    @Published var clockSyncCompensationMs: Double {
        didSet { defaults.set(clockSyncCompensationMs, forKey: Keys.clockSyncCompensationMs) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let stored = defaults.object(forKey: Keys.precision) as? Int,
           let precision = GridPrecision(rawValue: stored) {
            self.precision = precision
        } else {
            self.precision = .four
        }

        self.launchAtStart = defaults.bool(forKey: Keys.launchAtStart)

        if let stored = defaults.string(forKey: Keys.locationSource),
           let source = LocationSource(rawValue: stored) {
            self.locationSource = source
        } else {
            self.locationSource = .systemLocationServices
        }

        self.selectedGPSDevicePath = defaults.string(forKey: Keys.selectedGPSDevicePath)

        if defaults.object(forKey: Keys.gpsBaudRate) != nil {
            self.gpsBaudRate = defaults.integer(forKey: Keys.gpsBaudRate)
        } else {
            self.gpsBaudRate = nil
        }

        self.allCapsGrid = defaults.bool(forKey: Keys.allCapsGrid)

        if let stored = defaults.string(forKey: Keys.coordinateFormat),
           let format = CoordinateFormat(rawValue: stored) {
            self.coordinateFormat = format
        } else {
            self.coordinateFormat = .decimalDegrees
        }

        self.reverseLatLon = defaults.bool(forKey: Keys.reverseLatLon)

        if defaults.object(forKey: Keys.clockSyncCompensationMs) != nil {
            self.clockSyncCompensationMs = defaults.double(forKey: Keys.clockSyncCompensationMs)
        } else {
            self.clockSyncCompensationMs = 0
        }
    }
}
