import SwiftUI
import Combine
import CoreLocation
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var locationProvider: LocationProvider
    @ObservedObject var gpsService: SerialGPSService

    @State private var launchAtStartError: String?
    @State private var availableDevices: [SerialDevice] = []
    @State private var now = Date()

    private let clockTimer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()
    private let deviceRefreshTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Position Comparison", systemImage: "map")
                    .font(.headline)
                positionTable
            }

            // Split into tabs (rather than one long scrolling Form) so each pane's content
            // is short enough to fit comfortably on smaller-screen Macs without clipping or
            // needing a taller default window — General holds the frequently-used settings,
            // GPS holds the device/log controls that make a single pane tall.
            TabView {
                generalTab
                    .tabItem { Label("General", systemImage: "gearshape") }

                gpsTab
                    .tabItem { Label("GPS", systemImage: "dot.radiowaves.left.and.right") }

                coordinateFormatsTab
                    .tabItem { Label("Coordinate Formats", systemImage: "globe.americas") }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(24)
        .frame(minWidth: 480, idealWidth: 720, minHeight: 460, idealHeight: 620)
        .onAppear { refreshDevices() }
        .onReceive(clockTimer) { now = $0 }
        .onReceive(deviceRefreshTimer) { _ in refreshDevices() }
    }

    private var generalTab: some View {
        Form {
            Section {
                startupToggle
            } header: {
                Label("Startup", systemImage: "power")
            }

            Section {
                positionSourcePicker
            } header: {
                Label("Position Source", systemImage: "location.fill")
            }

            Section {
                precisionPicker
            } header: {
                Label("Grid Precision", systemImage: "ruler")
            }
        }
        .formStyle(.grouped)
    }

    private var gpsTab: some View {
        Form {
            Section {
                gpsDeviceControls
            } header: {
                Label("GPS Settings", systemImage: "dot.radiowaves.left.and.right")
            }
        }
        .formStyle(.grouped)
    }

    private var coordinateFormatsTab: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Format", selection: $settings.coordinateFormat) {
                        ForEach(CoordinateFormat.allCases, id: \.self) { format in
                            Text(format.label).tag(format)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()

                    Text("Example: \(settings.coordinateFormat.example)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Label("Coordinate Format", systemImage: "globe.americas")
            }

            Section {
                Toggle("Reverse Latitude/Longitude Order", isOn: $settings.reverseLatLon)
            } header: {
                Label("Output Order", systemImage: "arrow.left.arrow.right")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Position Comparison table

    private struct PositionRow: Identifiable {
        let id: String
        let source: String
        let time: String
        let position: String
        let grid: String
        let hasFix: Bool
    }

    private var positionTableRows: [PositionRow] {
        [
            PositionRow(
                id: "location",
                source: "Location Services",
                time: now.formatted(date: .omitted, time: .standard),
                position: locationPositionText,
                grid: locationGridText,
                hasFix: locationProvider.currentCoordinate != nil
            ),
            PositionRow(
                id: "gps",
                source: "USB GPS",
                time: gpsTimeText,
                position: gpsPositionText,
                grid: gpsGridText,
                hasFix: gpsService.status.fix != nil
            )
        ]
    }

    private var positionTable: some View {
        Table(positionTableRows) {
            TableColumn("Source") { row in
                Text(row.source).fontWeight(.medium)
            }
            .width(min: 110, ideal: 120)

            TableColumn("Time") { row in
                Text(row.time)
            }
            .width(min: 110, ideal: 140)

            TableColumn("Position") { row in
                Text(row.position)
                    .foregroundStyle(row.hasFix ? .primary : .secondary)
            }
            .width(min: 130, ideal: 220)

            TableColumn("Grid Square") { row in
                Text(row.grid)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(row.hasFix ? .primary : .secondary)
            }
            .width(min: 100, ideal: 120)
        }
        .frame(height: 100)
    }

    private var locationServicesStatusText: String {
        switch locationProvider.authorizationStatus {
        case .authorizedAlways: return "Waiting for a fix…"
        case .denied, .restricted: return "Location access denied."
        case .notDetermined: return "Location access not yet granted."
        @unknown default: return "Unavailable."
        }
    }

    private var locationPositionText: String {
        guard let coordinate = locationProvider.currentCoordinate else { return locationServicesStatusText }
        return formattedPosition(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    private var locationGridText: String {
        guard let coordinate = locationProvider.currentCoordinate else { return "—" }
        return MaidenheadGrid.locator(
            latitude: coordinate.latitude, longitude: coordinate.longitude, precision: .eight, uppercase: settings.allCapsGrid
        )
    }

    private var gpsPositionText: String {
        guard let fix = gpsService.status.fix else { return gpsService.status.message }
        return formattedPosition(latitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude)
    }

    private var gpsGridText: String {
        guard let fix = gpsService.status.fix else { return "—" }
        return MaidenheadGrid.locator(
            latitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude, precision: .eight, uppercase: settings.allCapsGrid
        )
    }

    private func formattedPosition(latitude: Double, longitude: Double) -> String {
        CoordinateFormatter.string(
            latitude: latitude, longitude: longitude, format: settings.coordinateFormat, reversed: settings.reverseLatLon
        )
    }

    private var gpsTimeText: String {
        guard let fix = gpsService.status.fix else { return "—" }
        let time = fix.utcTime.formatted(date: .omitted, time: .standard)
        guard let offset = gpsService.clockOffset else { return "\(time) UTC" }
        return "\(time) UTC (\(String(format: "%+.1f", offset))s)"
    }

    // MARK: - Grid Precision

    private var precisionPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Precision", selection: $settings.precision) {
                ForEach(GridPrecision.allCases, id: \.self) { precision in
                    Text("\(precision.label) (\(precision.distanceDescription))").tag(precision)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()

            Toggle("ALL CAPS Grid Square (EM79VI instead of EM79vi)", isOn: $settings.allCapsGrid)
                .padding(.top, 12)
        }
    }

    // MARK: - Position Source

    private var positionSourcePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Source", selection: $settings.locationSource) {
                ForEach(LocationSource.allCases, id: \.self) { source in
                    Text(source.label).tag(source)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()

            Text("The GPS receiver stays connected and visible in the GPS tab regardless of which source is selected here.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - GPS Device

    private var gpsDeviceControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("Device", selection: deviceBinding) {
                    Text("None").tag(String?.none)
                    ForEach(availableDevices) { device in
                        Text(device.displayName).tag(String?.some(device.path))
                    }
                }
                Button("Refresh") { refreshDevices() }
            }

            Picker("Baud Rate", selection: baudRateBinding) {
                Text("Auto").tag(Int?.none)
                ForEach(SerialGPSService.commonBaudRates, id: \.self) { rate in
                    Text("\(rate)").tag(Int?.some(rate))
                }
            }

            Label(gpsService.status.message, systemImage: statusIcon)
                .font(.caption)
                .foregroundStyle(statusColor)

            VStack(alignment: .leading, spacing: 4) {
                Text("Messages").font(.caption).foregroundStyle(.secondary)
                ScrollView {
                    Text(gpsService.recentMessages.joined(separator: "\n"))
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(6)
                }
                .frame(height: 140)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
            }
        }
    }

    private var statusColor: Color {
        switch gpsService.status {
        case .fixAcquired: return .green
        case .error, .deviceNotFound: return .red
        default: return .secondary
        }
    }

    private var statusIcon: String {
        switch gpsService.status {
        case .fixAcquired: return "checkmark.circle.fill"
        case .error, .deviceNotFound: return "exclamationmark.triangle.fill"
        default: return "clock"
        }
    }

    private var deviceBinding: Binding<String?> {
        Binding(
            get: { settings.selectedGPSDevicePath },
            set: { newValue in
                settings.selectedGPSDevicePath = newValue
                if let newValue {
                    gpsService.connect(to: newValue, baudRate: settings.gpsBaudRate)
                } else {
                    gpsService.disconnect()
                }
            }
        )
    }

    private var baudRateBinding: Binding<Int?> {
        Binding(
            get: { settings.gpsBaudRate },
            set: { newValue in
                settings.gpsBaudRate = newValue
                if let devicePath = settings.selectedGPSDevicePath {
                    gpsService.connect(to: devicePath, baudRate: newValue)
                }
            }
        )
    }

    private func refreshDevices() {
        availableDevices = SerialPortDiscovery.availableDevices()
    }

    // MARK: - Startup

    private var startupToggle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Launch on Start", isOn: launchAtStartBinding)
            if let launchAtStartError {
                Text(launchAtStartError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var launchAtStartBinding: Binding<Bool> {
        Binding(
            get: { settings.launchAtStart },
            set: { newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                    settings.launchAtStart = newValue
                    launchAtStartError = nil
                } catch {
                    launchAtStartError = "Couldn't update Launch on Start: \(error.localizedDescription)"
                }
            }
        )
    }
}
