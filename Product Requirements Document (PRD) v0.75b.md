# Product Requirements Document (PRD)

## 1. Project Title & Overview
* **Project Name**: Menu Maiden v 1.0
* **Description**: A menu bar app that displays the current Maidenhead Grid Square.
* **Problem Statement**: In the field, having your Maidenhead Grid Square is important for some ham radio activities such as *Parks on the Air* or *Summits on the Air*.

## 2. Target Audience
* Amateur Radio Operators performing field operations with their computers.

## 3. Core Features (MVP Scope)
* **Grid Square Display**: The app will use internal location services to accurately calculate and display the current gridsquare in the menu bar.
* **Configurable Precision**: The user will be able to select a 2, 4, 6, or 8 digit Maidenhead Gridsquare format.
* **Gridsquare Copy**: The user will be able to copy the current displayed gridsquare to the clipboard.
* **Launch on Start**: The user will be able to set the app to launch on system start via a check-box in the application.

## 4. User Journey & UI Elements
* **App First Launch**: Splash screen appears. Location Settings Permissions are presented to the user - this app requires Location settings to continue. Once granted, the app proceeds directly to Normal Usage, defaulting to 4 character Precision and Launch on Start unset. This first launch sequence will not take place unless the app's Location permissions have been revoked or reset.
* **Normal Usage**: The app displays a small Menu Bar item with the system's current Maidenhead Grid location as calculated from the current Latitude and Longitude. No windows are shown on a normal launch - Settings and About are reached via the right-click dropdown.
* **Right-click on Menu Bar Item**: The app displays a drop down with the following items: 
    * Copy Grid Square 
    * Divider Line
    * Settings
    * About
    * Divider Line
    * Quit Menu Maiden
*  **Left-click on Menu Bar Item**: The app cycles through precision settings, increasing from the current precision. For example, if the app is currently set to 4 character precision, left-clicking it will change to 6 characters. Left-clicking it again will change to 8 characters.  Left-clicking the menu bar when displaying 8 characters will set it to 2 characters. And left-clicking the menu bar when displaying 2 characters will change it to 4 character precision
*  **Settings Window**: 
    * An area where the program shows the current system clock compared to the time from the GPS signal (as applicable).
    * An area where the program shows current Latitude & Longitude in decimal degrees and Maidenhead locator to 8 characters calculated from the positions recieved for Location Services AND GPS (as applicable). Manage times when USB is not enabled or attached.  Display informative error messages when applicable.
    * The user is able to choose the precision for the Maidenhead calculations:
        * 2 characters (1,200 x 1,400 miles)
        * 4 characters (70 x 100 miles)
        * 6 characters (3 x 4 miles)
        * 8 characters (1,500 x 2,300 feet)
    * The user is able to choose between location services and a USB Serial NMEA GPS.
    * When USB Serial NMEA GPS is selected for use... 
        * The user is able to select the GPS device from a list of USB Serial GPS devices attached to the machine.  
        * The user is able to change appropriate parameters for the GPS, like baud rate, etc.  
            * If possible, auto-select these for the user.
        * The user is able to see messages sent by the GPS in a text window.
    * Whether the user would like to run this menu app on system start.
*  **GPS Settings**: 

## 5. Technical Stack & Constraints
* **Frontend**: Apple Swift
* **Backend/Storage**: LocalStorage Only
* **Constraints**: Menu Bar App

## 6. Future Enhancements (Out of Scope)
* Position reporting to WSJTX and other Ham Radio applications
* GPS-disciplined time service: use a GPS signal to broadcast a local NTP service that the system's own NTP sink can sync against, turning the app into a combined location + time "field toolbox." Requires a privileged helper daemon (serial GPS access, NTP responder on port 123) and moves distribution off the Mac App Store to Developer ID.
