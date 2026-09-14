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
            .combineLatest(settings.$allCapsGrid)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
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
                precision: settings.precision,
                uppercase: settings.allCapsGrid
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

        let copyGridItem = NSMenuItem(title: "Copy Grid Square", action: #selector(copyGridSquare), keyEquivalent: "")
        copyGridItem.target = self
        menu.addItem(copyGridItem)

        let copyLatLonItem = NSMenuItem(title: "Copy Latitude/Longitude", action: #selector(copyLatLon), keyEquivalent: "")
        copyLatLonItem.target = self
        menu.addItem(copyLatLonItem)

        menu.addItem(.separator())

        let syncClockItem = NSMenuItem(title: "Sync System Clock to GPS", action: #selector(syncSystemClockToGPS), keyEquivalent: "")
        syncClockItem.target = self
        syncClockItem.isEnabled = gpsService.status.fix != nil
        menu.addItem(syncClockItem)

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

    @objc private func copyLatLon() {
        guard let coordinate = activeCoordinate() else { return }
        let text = CoordinateFormatter.string(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            format: settings.coordinateFormat,
            reversed: settings.reverseLatLon
        )
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Sets the system clock to match the GPS's time. Deliberately doesn't precompute a
    /// fixed target timestamp before the admin-auth prompt runs — however long the user
    /// takes to authenticate would go straight into the applied time, undermining the PRD's
    /// "as close to the received GPS clock pulse as possible" requirement. Instead a
    /// *relative* whole-second correction is baked into a shell one-liner that computes
    /// "now" and applies the correction back-to-back, inside the privileged shell, only
    /// after authentication succeeds.
    @objc private func syncSystemClockToGPS() {
        guard gpsService.status.fix != nil, let offset = gpsService.clockOffset else { return }

        let correctionSeconds = -Int(offset.rounded())
        let adjustment = correctionSeconds >= 0 ? "+\(correctionSeconds)" : "\(correctionSeconds)"

        // BSD date's set syntax is MMDDhhmm[[CC]YY][.ss] — month/day/hour/minute first,
        // then the year, then seconds last — not year-first. Confirmed by testing the
        // command directly, unprivileged: %Y%m%d%H%M.%S reliably produced "illegal time
        // format" on its own, with nothing to do with AppleScript or privilege escalation
        // (both of which turned out to be working correctly the whole time).
        let script = """
        do shell script "/bin/date -u $(/bin/date -u -v\(adjustment)S +%m%d%H%M%Y.%S)" with administrator privileges with prompt "Menu Maiden wants to set the system clock to match the GPS time."
        """

        guard let appleScript = NSAppleScript(source: script) else { return }
        var errorInfo: NSDictionary?
        appleScript.executeAndReturnError(&errorInfo)
        if let errorInfo {
            presentSyncError(errorInfo)
        }
    }

    private func presentSyncError(_ errorInfo: NSDictionary) {
        let message = errorInfo[NSAppleScript.errorMessage] as? String ?? "Unknown error."
        let alert = NSAlert()
        alert.messageText = "Couldn't Sync System Clock"
        alert.informativeText = message
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
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
