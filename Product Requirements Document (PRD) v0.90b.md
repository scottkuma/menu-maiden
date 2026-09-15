# Product Requirements Document (PRD)

## 1. Project Title & Overview
* **Project Name**: Menu Maiden v0.90b
* **Description**: A menu bar app that displays the current Maidenhead Grid Square.
* **Problem Statement**: In the field, having your Maidenhead Grid Square is important for some ham radio activities such as *Parks on the Air* or *Summits on the Air*.

## 2. Target Audience
* Amateur Radio Operators performing field operations with their computers.

## 3. Core Features (MVP Scope)
* **Grid Square Display**: The app will use internal location services to accurately calculate and display the current gridsquare in the menu bar.
* **Configurable Precision**: The user will be able to select a 2, 4, 6, or 8 digit Maidenhead Gridsquare format.
* **Gridsquare Copy**: The user will be able to copy the current displayed gridsquare to the clipboard.
* **Launch on Start**: The user will be able to set the app to launch on system start via a check-box in the application.
* **WSJT-X / JTDX Autogrid**: The user will be able to have the app report current location to WSJT-X and JTDX's autogrid feature. 

## 4. User Journey & UI Elements
* **App First Launch**: Splash screen appears. Location Settings Permissions are presented to the user - this app requires Location settings to continue. Once granted, the app proceeds directly to Normal Usage, defaulting to 4 character Precision and Launch on Start unset. This first launch sequence will not take place unless the app's Location permissions have been revoked or reset.
* **Normal Usage**: The app displays a small Menu Bar item with the system's current Maidenhead Grid location as calculated from the current Latitude and Longitude. No windows are shown on a normal launch - Settings and About are reached via the right-click dropdown.
* **Right-click on Menu Bar Item**: The app displays a drop down with the following items: 
    * About Menu Maiden
    * Divider Line
    * Settings
    * Divider Line
    * Copy Grid Square [^1]
    * Copy Latitude/Longitude [^2]
    * Divider Line
    * Send Autogrid [^3]
    * Divider Line
    * Sync System Clock to GPS [^4]
    * Divider Line
    * Quit Menu Maiden

[^1]: When the user click on "Copy Grid Square", the grid square will be copied in the format displayed in the menu bar/selected in the settings tab.
[^2]: When the user clicks on Copy Latitude/Longitude, it will use the SOURCE (Location Services or external GPS) and FORMAT options as chosen in the settings tab.
[^3]: This option is only available when 1) the "Autogrid" feature is enabled in the settings pane, 2) there is a position match from the currently selected Position Source (Location Services or external GPS, per the General tab's Position Source setting — which source is active does not matter), AND 3) Menu Maiden has detected WSJT-X/JTDX's own traffic (see "Status" in the Autogrid Settings tab, below). When any condition is not met, the option will be grayed out/disabled. The position sent is always calculated to 6-character Maidenhead precision, regardless of the precision currently displayed in the menu bar, since WSJT-X/JTDX's protocol only accepts 4- or 6-digit locators.
    Condition 3 exists because of how WSJT-X/JTDX's own UDP protocol actually works: WSJT-X is the protocol "client" — it sends its own state to a configured address, and only accepts replies on the ephemeral local port that traffic came from, not on its configured port itself. There is no fixed address to send an update to ahead of time; Menu Maiden has to listen on the configured port, wait for WSJT-X/JTDX to identify itself, and reply on that same connection. This was discovered empirically during implementation (an initial fire-and-forget design silently went nowhere) and confirmed directly against a real running WSJT-X 3.0.2 instance.
[^4]: This option is only available when there is an externally-attached GPS that has a good time sync. When there is no GPS attached, or when it does NOT have a good time sync, the option will be grayed out/disabled.  Clock sync should take place as close to the received GPS clock pulse as possible, to minimize any gap.

*  **Left-click on Menu Bar Item**: The app cycles through precision settings, increasing from the current precision. For example, if the app is currently set to 4 character precision, left-clicking it will change to 6 characters. Left-clicking it again will change to 8 characters.  Left-clicking the menu bar when displaying 8 characters will set it to 2 characters. And left-clicking the menu bar when displaying 2 characters will change it to 4 character precision
*  **Settings Window**: 
    * A "Position Comparison" area where the program will always show:
        * the current system clock compared to the time from the GPS signal (as applicable).
        * current Latitude & Longitude in decimal degrees and Maidenhead locator to 8 characters calculated from the positions recieved for Location Services AND GPS (as applicable). Manage times when USB is not enabled or attached.  Display informative error messages when applicable.
    * "General" settings tab:
        * Whether the user would like to run this menu app on system start.
        * The user is able to choose the precision for the Maidenhead calculations:
            * 2 characters (1,200 x 1,400 miles)
            * 4 characters (70 x 100 miles)
            * 6 characters (3 x 4 miles)
            * 8 characters (1,500 x 2,300 feet)
        * ALL CAPS Maidenhead format (EM79VI instead of the normal EM79vi) [DEFAULT: OFF]
        * The user is able to choose between location services and a USB Serial NMEA GPS as the location being used by the app for other functions.
    * "GPS" tab: 
        * The user is able to select the GPS device from a list of USB Serial GPS devices attached to the machine.  
        * The user is able to change appropriate parameters for the GPS, like baud rate, etc.  
            * If possible, auto-select these for the user.
        * The user is able to see messages sent by the GPS in a text window.
    * "Coordinate Formats" tab: 
        * The user has the ability to select how Latitude & Longitude coordinates are displayed and copied:
            * Decimal Degrees (DD) (39.123456, -84.123456) [DEFAULT FORMAT]
            * Degrees, Minutes, Seconds (DMS) (39° 7' 24.44" N, 84° 7' 24.44" W.)
            * Degrees and Decimal Minutes (DDM) (39° 7.4074' N, 84° 7.4074' W)
            * The ability to reverse latitude & longitude in the output [DEFAULT: OFF]
    * "Autogrid Settings" tab:
        * The user has the ability to activate autogrid capability via an "enable" checkbox.
        * The user has the ability to set the following parameters:
            * Client ID string sent with each message (default to "MenuMaiden") — required by the WSJT-X/JTDX protocol but not validated against anything by the receiving program, so any value works.
            * Port that Menu Maiden listens on for WSJT-X/JTDX's own traffic (default to 2237, matching WSJT-X's own default "UDP Server" port — JTDX's default differs, so check that program's own Reporting settings if using it instead). There is no IP address setting: Menu Maiden listens for a connection rather than sending to a fixed destination — see footnote 3, above, for why.
        * A "Status" indicator (only shown while Autogrid is enabled) shows whether Menu Maiden has detected WSJT-X/JTDX: "Waiting for WSJT-X/JTDX…" (nothing heard yet), "Receiving traffic, waiting for identification…" (traffic seen but not yet identified), or "Connected to \<program\> \<version\>" once its Heartbeat message has been decoded (e.g. "Connected to WSJT-X 3.0.2").


## 5. Technical Stack & Constraints
* **Frontend**: Apple Swift
* **Backend/Storage**: LocalStorage Only
* **Constraints**: Menu Bar App

## 6. Future Enhancements (Out of Scope)
* GPS-disciplined time service: use a GPS signal to broadcast a local NTP service that the system's own NTP sink can sync against, turning the app into a combined location + time "field toolbox." Requires a privileged helper daemon (serial GPS access, NTP responder on port 123) and moves distribution off the Mac App Store to Developer ID.
