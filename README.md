# Menu Maiden

A macOS menu bar app that displays your current [Maidenhead Grid Square](https://en.wikipedia.org/wiki/Maidenhead_Locator_System) — built for amateur radio operators doing field activities like *Parks on the Air* (POTA) or *Summits on the Air* (SOTA).

Position can come from macOS Location Services or a USB serial NMEA GPS receiver, with a built-in comparison view so you can see both side by side.

## Features

- **Grid square in the menu bar**, calculated live from your current position
- **Configurable precision** — 2, 4, 6, or 8 characters
  - 2 chars ≈ 1,200 × 1,400 mi · 4 chars ≈ 70 × 100 mi · 6 chars ≈ 3 × 4 mi · 8 chars ≈ 1,500 × 2,300 ft
  - Optional **ALL CAPS** display (`EM79VI` instead of `EM79vi`)
- **Left-click the menu bar item** to cycle precision (4 → 6 → 8 → 2 → 4 …)
- **Right-click** for Copy Grid Square, Copy Latitude/Longitude, Sync System Clock to GPS, Settings, About, and Quit
- **Position source**: macOS Location Services, or a USB serial NMEA GPS receiver — the GPS stays connected and visible in Settings regardless of which one is active
- **GPS auto-baud detection**, device picker, and a live raw NMEA message log
- **Position Comparison table** showing Location Services vs. GPS time and position side by side
- **Configurable coordinate formats** — Decimal Degrees, Degrees/Minutes/Seconds, or Degrees/Decimal Minutes, with an option to reverse Latitude/Longitude order — applied to both the display and Copy Latitude/Longitude
- **Sync System Clock to GPS**, with a calibratable latency compensation setting to tighten accuracy — see [GPS clock sync accuracy](#gps-clock-sync-accuracy) below
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

Menu Maiden does **not** run inside the App Sandbox. It requests:

- **Location Services access** (`NSLocationWhenInUseUsageDescription` in `project.yml`) — for the Location Services position source
- **Serial port access** — no entitlement needed outside the sandbox; the GPS device just needs to be readable at its `/dev/cu.*` path
- **Admin authentication**, on demand, only when you use **Sync System Clock to GPS** — triggers the standard macOS Touch ID/password prompt via a privileged `do shell script`

The sandbox was dropped deliberately in v0.80 because setting the system clock requires a privileged shell command that the sandbox blocks. Since Menu Maiden is distributed via Developer ID rather than the Mac App Store, sandboxing brought no benefit here — only ambiguity about whether the clock-sync feature would work.

## GPS clock sync accuracy

The right-click menu's **Sync System Clock to GPS** sets the Mac's system clock to match the connected GPS receiver's time (admin authentication required). Getting this accurate runs into one hard limit and one tunable one:

- **Whole-second granularity.** macOS's `date` command can only *set* the clock to a whole second — there's no way to set fractional seconds from the command line. Menu Maiden works around this by computing the correction and applying it inside the privileged shell right after authentication succeeds (rather than before), so an admin prompt that takes a few seconds to answer doesn't get baked into the applied time.
- **NMEA sentence latency.** There's a real, physical delay between the GPS's internal clock tick and Menu Maiden finishing parsing that fix's NMEA sentence — chipset processing time plus serial transmission time. This delay is roughly constant for a given GPS device and baud rate, so it shows up as a consistent bias in the same direction on every sync rather than random noise that averages out.

Settings → GPS → **Clock Sync** has a **Latency Compensation** stepper (in milliseconds) to cancel that bias out. It's subtracted from the measured offset before the sync rounds to a whole second, so once it's calibrated correctly, the rounding lands close to the true second instead of being skewed by it. There's no way to measure the right value automatically (it depends on your specific GPS hardware and baud rate), so it has to be calibrated by hand:

1. Set compensation to 0, artificially offset the system clock (e.g. `sudo date` set a few minutes off), sync, and check the residual offset shown in the Position Comparison table right after.
2. If the residual reads **negative**, **increase** compensation (100–300ms is a typical starting point for NMEA GPS receivers).
3. If it reads **positive**, decrease it.
4. Repeat until the post-sync residual is near zero. It should converge in a couple of tries, and stays good until you switch GPS devices or baud rates.

Even calibrated, don't expect better than roughly ±100–200ms: that's bounded by the GPS module's own timing jitter. Sub-100ms accuracy would require a PPS (pulse-per-second) hardware line, which most USB NMEA GPS receivers don't expose over plain serial.

## Roadmap

See the [v0.80b PRD](Product%20Requirements%20Document%20(PRD)%20v0.80b.md) for the full spec. Not yet built:

- Position reporting to WSJT-X and other ham radio applications
- A GPS-disciplined local NTP time service (would require a privileged helper daemon and move distribution off the Mac App Store)

## License

No license has been chosen yet for this project.
