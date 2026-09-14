import Foundation

/// Converts latitude/longitude coordinates into a Maidenhead Grid Square locator.
enum MaidenheadGrid {
    /// Returns the Maidenhead locator string for the given coordinates at the requested precision.
    ///
    /// - Parameters:
    ///   - latitude: Latitude in degrees, -90...90.
    ///   - longitude: Longitude in degrees, -180...180.
    ///   - precision: Number of characters to return (2, 4, 6, or 8).
    ///   - uppercase: When true, the normally-lowercase subsquare letters are uppercased too.
    static func locator(latitude: Double, longitude: Double, precision: GridPrecision, uppercase: Bool = false) -> String {
        let result = rawLocator(latitude: latitude, longitude: longitude, precision: precision)
        return uppercase ? result.uppercased() : result
    }

    private static func rawLocator(latitude: Double, longitude: Double, precision: GridPrecision) -> String {
        let asciiA = Int(UnicodeScalar("A").value)

        // Normalize into 0..<360 (lon) and 0..<180 (lat), clamping the poles/dateline
        // so a coordinate exactly at +180/+90 doesn't overflow into an 18th field.
        var lon = min(max(longitude + 180, 0), 359.999_999)
        var lat = min(max(latitude + 90, 0), 179.999_999)

        var result = ""

        // Field: 20 degrees of longitude x 10 degrees of latitude, letters A-R.
        let lonField = Int(lon / 20)
        let latField = Int(lat / 10)
        result.append(Character(UnicodeScalar(asciiA + lonField)!))
        result.append(Character(UnicodeScalar(asciiA + latField)!))

        guard precision.rawValue >= 4 else { return result }

        lon -= Double(lonField) * 20
        lat -= Double(latField) * 10

        // Square: 2 degrees of longitude x 1 degree of latitude, digits 0-9.
        let lonSquare = Int(lon / 2)
        let latSquare = Int(lat / 1)
        result.append(String(lonSquare))
        result.append(String(latSquare))

        guard precision.rawValue >= 6 else { return result }

        lon -= Double(lonSquare) * 2
        lat -= Double(latSquare) * 1

        // Subsquare: splits each square into a 24x24 grid, lowercase letters a-x.
        let lonSubDegrees = 2.0 / 24.0
        let latSubDegrees = 1.0 / 24.0
        let lonSub = Int(lon / lonSubDegrees)
        let latSub = Int(lat / latSubDegrees)
        result.append(Character(UnicodeScalar(asciiA + lonSub)!).lowercased())
        result.append(Character(UnicodeScalar(asciiA + latSub)!).lowercased())

        guard precision.rawValue >= 8 else { return result }

        lon -= Double(lonSub) * lonSubDegrees
        lat -= Double(latSub) * latSubDegrees

        // Extended square: splits each subsquare into a 10x10 grid, digits 0-9.
        let lonExtDegrees = lonSubDegrees / 10.0
        let latExtDegrees = latSubDegrees / 10.0
        let lonExt = Int(lon / lonExtDegrees)
        let latExt = Int(lat / latExtDegrees)
        result.append(String(lonExt))
        result.append(String(latExt))

        return result
    }
}
