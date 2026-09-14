import Foundation
import IOKit
import IOKit.serial

/// A USB/serial device the user can pick as a GPS source.
struct SerialDevice: Identifiable, Hashable {
    let path: String
    let displayName: String

    var id: String { path }
}

/// Enumerates serial devices (e.g. USB-to-serial GPS receivers) via IOKit.
enum SerialPortDiscovery {
    static func availableDevices() -> [SerialDevice] {
        guard let matchingDict = IOServiceMatching(kIOSerialBSDServiceValue) else { return [] }
        let mutableMatchingDict = matchingDict as NSMutableDictionary
        mutableMatchingDict[kIOSerialBSDTypeKey as String] = kIOSerialBSDAllTypes as CFString

        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, mutableMatchingDict, &iterator) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }

        var devices: [SerialDevice] = []
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            guard let pathProperty = IORegistryEntryCreateCFProperty(
                service, kIOCalloutDeviceKey as CFString, kCFAllocatorDefault, 0
            )?.takeRetainedValue() as? String else { continue }

            devices.append(SerialDevice(path: pathProperty, displayName: friendlyName(for: service, fallback: pathProperty)))
        }

        return devices
    }

    /// Walks up the registry tree looking for a USB product name; falls back to the device path.
    /// `service` itself is owned by the caller and is never released here — only the
    /// parent entries this function fetches along the way are.
    private static func friendlyName(for service: io_object_t, fallback: String) -> String {
        var current = service
        var ownsCurrent = false
        let fallbackName = (fallback as NSString).lastPathComponent

        for _ in 0..<6 {
            if let name = IORegistryEntryCreateCFProperty(
                current, kUSBProductString as CFString, kCFAllocatorDefault, 0
            )?.takeRetainedValue() as? String, !name.isEmpty {
                if ownsCurrent { IOObjectRelease(current) }
                return name
            }

            var parent: io_registry_entry_t = 0
            let result = IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent)
            if ownsCurrent { IOObjectRelease(current) }
            guard result == KERN_SUCCESS, parent != 0 else { return fallbackName }
            current = parent
            ownsCurrent = true
        }

        if ownsCurrent { IOObjectRelease(current) }
        return fallbackName
    }
}

private let kUSBProductString = "USB Product Name"
