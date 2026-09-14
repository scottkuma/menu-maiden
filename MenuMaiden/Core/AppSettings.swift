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
    }
}
