// Run from the repo root using the command in README.md. No live Maps requests.
import CoreLocation
import MapKit

@main
struct CafeSearchTests {
    static func main() {
        let center = CLLocationCoordinate2D(latitude: 30.286, longitude: -97.742)
        let origin = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let area = CafeSearchArea(name: "West Campus", coordinate: center, radiusMiles: 1)
        func cafe(_ name: String, northMeters: Double) -> MKMapItem {
            let coordinate = CLLocationCoordinate2D(latitude: center.latitude + northMeters / 111_000,
                                                    longitude: center.longitude)
            let item = MKMapItem(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), address: nil)
            item.name = name
            return item
        }
        let near = cafe("Near", northMeters: 200)
        let far = cafe("Far", northMeters: 1_000)
        let outside = cafe("Outside", northMeters: 2_000)
        let results = NearbyCafe.filtered([outside, far, near, near], in: area)
        assert(results.map { $0.mapItem.name! } == ["Near", "Far"], "Exclude outside radius, remove duplicates, sort by distance")
        assert(results.first!.distanceMeters == origin.distance(from: near.location))
        assert(NearbyCafe.filtered([], in: area).isEmpty)
        let onEdge = origin.distance(from: far.location) / 1_609.344
        let edgeArea = CafeSearchArea(name: "Boundary", coordinate: center, radiusMiles: onEdge)
        assert(NearbyCafe.filtered([far], in: edgeArea).count == 1, "Include boundary")
        let narrowArea = CafeSearchArea(name: "Narrow", coordinate: center, radiusMiles: 0.5)
        assert(NearbyCafe.filtered([far, near], in: narrowArea).count == 1, "Changing radius changes results")
        assert(CafeSearchArea.validatedRadius("0.5") == 0.5)
        assert(CafeSearchArea.validatedRadius("50") == 50)
        assert(CafeSearchArea.validatedRadius("1,5", locale: Locale(identifier: "fr_FR")) == 1.5)
        for invalid in ["", "0", "-3", "0.49", "50.1", "nan", "inf", "3 miles", "3.2.1"] {
            assert(CafeSearchArea.validatedRadius(invalid) == nil, "Reject invalid radius: \(invalid)")
        }
        print("All cafe search checks passed.")
    }
}
