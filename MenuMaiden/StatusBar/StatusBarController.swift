import AppKit
import SwiftUI
import Combine
import CoreLocation

/// Owns the NSStatusItem and routes left/right clicks per the PRD:
/// left-click cycles precision, right-click shows the Settings/About menu.
@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let settings: AppSettings
    private let locationProvider: LocationProvider
    private let gpsService: SerialGPSService

    private var cancellables: Set<AnyCancellable> = []
    private var currentLocator: String = "--------"

    private var settingsWindowController: NSWindowController?
    private var aboutWindowController: NSWindowController?

    init(settings: AppSettings, locationProvider: LocationProvider, gpsService: SerialGPSService) {
        self.settings = settings
        self.locationProvider = locationProvider
        self.gpsService = gpsService
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        configureButton()
        observe()
        refreshTitle()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func observe() {
        locationProvider.$currentCoordinate
            .combineLatest(gpsService.$status, settings.$precision, settings.$locationSource)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _, _, _ in
                self?.refreshTitle()
            }
            .store(in: &cancellables)
    }

    private func activeCoordinate() -> CLLocationCoordinate2D? {
        switch settings.locationSource {
        case .systemLocationServices:
            return locationProvider.currentCoordinate
        case .usbGPS:
            return gpsService.status.fix?.coordinate
        }
    }

    private func refreshTitle() {
        if let coordinate = activeCoordinate() {
            currentLocator = MaidenheadGrid.locator(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                precision: settings.precision
            )
        } else {
            currentLocator = String(repeating: "-", count: settings.precision.rawValue)
        }
        statusItem.button?.title = currentLocator
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        switch event.type {
        case .rightMouseUp:
            showMenu()
        default:
            settings.precision = settings.precision.next
            refreshTitle()
        }
    }

    private func showMenu() {
        let menu = NSMenu()

        let copyItem = NSMenuItem(title: "Copy Grid Square", action: #selector(copyGridSquare), keyEquivalent: "")
        copyItem.target = self
        menu.addItem(copyItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(title: "About", action: #selector(openAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Menu Maiden", action: #selector(quit), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func copyGridSquare() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(currentLocator, forType: .string)
    }

    @objc private func openSettings() {
        if settingsWindowController == nil {
            // Clamped against the actual screen's visible area (minus a margin) so the
            // default is never taller/wider than a smaller display can show — content that
            // still doesn't fit scrolls within the Form, which is normal, graceful behavior.
            let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
            let defaultSize = NSSize(
                width: min(720, visibleFrame.width - 40),
                height: min(640, visibleFrame.height - 40)
            )

            // The window is given its final default size at creation time, before any
            // SwiftUI content is attached, rather than resized afterward: NSHostingView
            // keeps the window fit to its SwiftUI content's natural size on every layout
            // pass, which was overriding a later setContentSize call — and, worse,
            // overriding the user manually resizing the window to stop the bottom clipping.
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: defaultSize),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Settings"
            window.contentView = NSHostingView(
                rootView: SettingsView(settings: settings, locationProvider: locationProvider, gpsService: gpsService)
            )
            window.setContentSize(defaultSize)
            window.center()

            // Remembers any size/position the user manually drags the window to, and
            // restores it automatically on the next open, silently overriding the centered
            // default above when a saved frame exists — so a resize to stop clipping (or
            // to fit a smaller display) sticks permanently instead of reverting every
            // relaunch. Must run AFTER center(): its return value reports whether the save
            // itself succeeded, not whether a prior frame was found and restored, so this
            // can't be conditioned on that — ordering is what makes a genuine saved frame
            // win over the just-applied default instead of the reverse.
            window.setFrameAutosaveName("SettingsWindow")

            settingsWindowController = NSWindowController(window: window)
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController?.showWindow(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func openAbout() {
        if aboutWindowController == nil {
            let window = NSWindow(
                contentRect: .zero,
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "About"
            window.contentView = NSHostingView(rootView: AboutView())
            window.center()
            aboutWindowController = NSWindowController(window: window)
        }
        NSApp.activate(ignoringOtherApps: true)
        aboutWindowController?.showWindow(nil)
    }
}
