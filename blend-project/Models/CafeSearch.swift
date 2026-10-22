import CoreLocation
import MapKit

struct CafeSearchArea {
    let name: String
    let coordinate: CLLocationCoordinate2D
    let radiusMiles: Double

    static func validatedRadius(_ text: String, locale: Locale = .current) -> Double? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: locale.decimalSeparator ?? ".", with: ".")
        guard let value = Double(normalized), value.isFinite, (0.5...50).contains(value) else { return nil }
        return value
    }

    var radiusMeters: Double { radiusMiles * 1_609.344 }
    var summary: String { "\(name) · \(radiusMiles.formatted()) mi" }
}

struct NearbyCafe {
    let mapItem: MKMapItem
    let distanceMeters: Double

    var distanceText: String {
        String(format: "%.1f mi", distanceMeters / 1_609.344)
    }

    /// MapKit's search region is a hint, so enforce the circular radius ourselves.
    static func filtered(_ items: [MKMapItem], in area: CafeSearchArea) -> [NearbyCafe] {
        let origin = CLLocation(latitude: area.coordinate.latitude, longitude: area.coordinate.longitude)
        var seen = Set<String>()
        return items.compactMap { item in
            let coordinate = item.location.coordinate
            let distance = origin.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
            guard distance <= area.radiusMeters else { return nil }
            let key = "\(item.name ?? "")|\(coordinate.latitude)|\(coordinate.longitude)"
            guard seen.insert(key).inserted else { return nil }
            return NearbyCafe(mapItem: item, distanceMeters: distance)
        }.sorted { $0.distanceMeters < $1.distanceMeters }
    }
}
