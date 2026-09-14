# Menu Maiden

A macOS menu bar app that displays your current [Maidenhead Grid Square](https://en.wikipedia.org/wiki/Maidenhead_Locator_System) — built for amateur radio operators doing field activities like *Parks on the Air* (POTA) or *Summits on the Air* (SOTA).

Position can come from macOS Location Services or a USB serial NMEA GPS receiver, with a built-in comparison view so you can see both side by side.

## Features

- **Grid square in the menu bar**, calculated live from your current position
- **Configurable precision** — 2, 4, 6, or 8 characters
  - 2 chars ≈ 1,200 × 1,400 mi · 4 chars ≈ 70 × 100 mi · 6 chars ≈ 3 × 4 mi · 8 chars ≈ 1,500 × 2,300 ft
- **Left-click the menu bar item** to cycle precision (4 → 6 → 8 → 2 → 4 …)
- **Right-click** for Copy Grid Square, Settings, About, and Quit
- **Position source**: macOS Location Services, or a USB serial NMEA GPS receiver — the GPS stays connected and visible in Settings regardless of which one is active
- **GPS auto-baud detection**, device picker, and a live raw NMEA message log
- **Position Comparison table** showing Location Services vs. GPS time and position side by side
- **Launch at login**

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) — the `.xcodeproj` is generated from `project.yml` and is not checked into this repo

## Building

```sh
xcodegen generate
open MenuMaiden.xcodeproj
```

Build and run the `MenuMaiden` scheme. On first launch the app will ask for Location permission; grant it to see a live grid square, or open Settings → GPS to use a USB GPS receiver instead.

### Running tests

```sh
xcodebuild -project MenuMaiden.xcodeproj -scheme MenuMaiden -destination 'platform=macOS' test
```

## Project structure

```
MenuMaiden/
  App/            App entry point and delegate (first-launch/splash flow)
  Core/           Pure logic: Maidenhead grid math, precision, settings persistence
  GPS/            NMEA parsing, serial port discovery, and the GPS service
  Location/       CoreLocation wrapper
  StatusBar/      NSStatusItem, menu, and click handling
  UI/             SwiftUI views (Settings, Splash, About)
MenuMaidenTests/  Unit tests for the grid math and NMEA parsing
```

The Maidenhead grid calculation and NMEA parsing are both pure, side-effect-free functions covered by unit tests — everything that talks to hardware (CoreLocation, the serial port) is kept separate from that logic.

## Permissions & entitlements

The app runs inside the App Sandbox with two entitlements:

- `com.apple.security.personal-information.location` — for Location Services
- `com.apple.security.device.serial` — for the USB GPS receiver

Both are declared in `project.yml` and applied to the generated `.xcodeproj` by XcodeGen.

## Roadmap

See the [PRD](Product%20Requirements%20Document%20(PRD).md) for the full spec. Not yet built:

- Position reporting to WSJT-X and other ham radio applications
- A GPS-disciplined local NTP time service (would require a privileged helper daemon and move distribution off the Mac App Store)

## License

No license has been chosen yet for this project.
