import SwiftUI
import AppKit
import CoreLocation

/// Shown on first launch (or whenever location permission has been revoked/reset),
/// per the PRD's first-launch flow.
struct SplashView: View {
    @ObservedObject var locationProvider: LocationProvider
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.circle.fill")
                .resizable()
                .frame(width: 64, height: 64)
                .foregroundStyle(.tint)

            Text("Welcome to Menu Maiden")
                .font(.title2)
                .bold()

            Text("This app requires Location access to calculate your current Maidenhead Grid Square.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 320)

            statusView

            Spacer(minLength: 0)
        }
        .padding(32)
        .frame(width: 420, height: 320)
        .onChange(of: locationProvider.authorizationStatus) { newStatus in
            if newStatus == .authorizedAlways {
                onContinue()
            }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch locationProvider.authorizationStatus {
        case .notDetermined:
            Button("Grant Location Access") {
                locationProvider.requestPermission()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

        case .denied, .restricted:
            VStack(spacing: 8) {
                Text("Location access was denied. Open System Settings to enable it for Menu Maiden.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.red)
                    .frame(maxWidth: 320)
                Button("Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }

        case .authorizedAlways:
            Label("Location access granted", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)

        @unknown default:
            EmptyView()
        }
    }
}
