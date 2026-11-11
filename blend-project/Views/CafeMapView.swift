import MapKit

final class CafeMapView: MKMapView, MKMapViewDelegate {
    private final class CafePin: NSObject, MKAnnotation {
        let cafe: NearbyCafe
        let coordinate: CLLocationCoordinate2D
        let title: String?
        let subtitle: String?

        init(cafe: NearbyCafe) {
            self.cafe = cafe
            coordinate = cafe.mapItem.location.coordinate
            title = cafe.mapItem.name ?? "Coffee shop"
            subtitle = cafe.distanceText
        }
    }

    var onShowCafe: ((NearbyCafe) -> Void)?
    private var boundary: MKCircle?

    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
        register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "CafePin")
        pointOfInterestFilter = .excludingAll
        showsCompass = true
    }

    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    func setArea(_ area: CafeSearchArea) {
        if let boundary { removeOverlay(boundary) }
        let circle = MKCircle(center: area.coordinate, radius: area.radiusMeters)
        boundary = circle
        addOverlay(circle, level: .aboveRoads)
        recenter(animated: false)
    }

    func recenter(animated: Bool = true) {
        guard let boundary, bounds.width > 48, bounds.height > 48 else { return }
        setVisibleMapRect(boundary.boundingMapRect,
                          edgePadding: UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24),
                          animated: animated)
    }

    func showCafes(_ cafes: [NearbyCafe]) {
        removeAnnotations(annotations)
        addAnnotations(cafes.map(CafePin.init))
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
        guard let circle = overlay as? MKCircle else { return MKOverlayRenderer(overlay: overlay) }
        let renderer = MKCircleRenderer(circle: circle)
        renderer.fillColor = .blendLatte.withAlphaComponent(0.20)
        renderer.strokeColor = .blendEspresso
        renderer.lineWidth = 2
        return renderer
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
        guard annotation is CafePin else { return nil }
        let marker = dequeueReusableAnnotationView(withIdentifier: "CafePin", for: annotation) as! MKMarkerAnnotationView
        // Keep nearby pins visible when the full search radius is on screen.
        marker.displayPriority = .required
        marker.markerTintColor = .blendEspresso
        marker.glyphImage = UIImage(systemName: "cup.and.saucer.fill")
        marker.canShowCallout = true
        marker.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
        marker.rightCalloutAccessoryView?.accessibilityLabel = "Coffee shop details"
        return marker
    }

    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        guard let pin = view.annotation as? CafePin else { return }
        onShowCafe?(pin.cafe)
    }
}
