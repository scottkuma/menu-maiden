import SwiftUI

struct AboutView: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.751"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "location.circle.fill")
                .resizable()
                .frame(width: 48, height: 48)
                .foregroundStyle(.tint)

            Text("Menu Maiden")
                .font(.title3)
                .bold()

            Text("Version \(version) Beta (\(build))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Displays your current Maidenhead Grid Square in the menu bar for amateur radio field operations.")
                .multilineTextAlignment(.center)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 260)
        }
        .padding(24)
        .frame(width: 300)
    }
}
