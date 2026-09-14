import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings()
    private let locationProvider = LocationProvider()
    private let gpsService = SerialGPSService()
    private var statusBarController: StatusBarController?

    private var splashWindowController: NSWindowController?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController(settings: settings, locationProvider: locationProvider, gpsService: gpsService)

        if let devicePath = settings.selectedGPSDevicePath {
            gpsService.connect(to: devicePath, baudRate: settings.gpsBaudRate)
        }

        if locationProvider.isAuthorized {
            locationProvider.startUpdating()
        } else {
            presentSplash()
        }
    }

    private func presentSplash() {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome"
        window.contentView = NSHostingView(
            rootView: SplashView(locationProvider: locationProvider) { [weak self] in
                self?.splashWindowController?.close()
                self?.splashWindowController = nil
                self?.locationProvider.startUpdating()
            }
        )
        window.center()
        let controller = NSWindowController(window: window)
        splashWindowController = controller

        NSApp.activate(ignoringOtherApps: true)
        controller.showWindow(nil)
    }
}
