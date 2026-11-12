import MapKit
import UIKit

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
        isZoomEnabled = true
        isScrollEnabled = true
        addZoomControls()
    }

    /// On-map + / − buttons, since iOS maps have no built-in zoom control and
    /// pinching isn't always practical (Simulator, one-handed use, accessibility).
    private func addZoomControls() {
        let zoomIn = zoomButton(symbol: "plus", label: "Zoom in", action: #selector(zoomInTapped))
        let zoomOut = zoomButton(symbol: "minus", label: "Zoom out", action: #selector(zoomOutTapped))
        let controls = UIStackView(arrangedSubviews: [zoomIn, zoomOut])
        controls.axis = .vertical
        controls.spacing = 8
        controls.translatesAutoresizingMaskIntoConstraints = false
        addSubview(controls)
        NSLayoutConstraint.activate([
            controls.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            controls.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24)
        ])
    }

    private func zoomButton(symbol: String, label: String, action: Selector) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(weight: .semibold))
        config.baseBackgroundColor = .blendCard
        config.baseForegroundColor = .blendEspresso
        config.cornerStyle = .medium
        let button = UIButton(configuration: config)
        button.accessibilityLabel = label
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.15
        button.layer.shadowRadius = 3
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.addTarget(self, action: action, for: .touchUpInside)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 44),
            button.heightAnchor.constraint(equalToConstant: 44)
        ])
        return button
    }

    @objc private func zoomInTapped() { zoom(by: 0.5) }
    @objc private func zoomOutTapped() { zoom(by: 2) }

    private func zoom(by factor: Double) {
        var span = region.span
        span.latitudeDelta = min(max(span.latitudeDelta * factor, 0.0005), 90)
        span.longitudeDelta = min(max(span.longitudeDelta * factor, 0.0005), 180)
        setRegion(MKCoordinateRegion(center: region.center, span: span), animated: true)
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
        // Tapping a pin opens the shop's page directly, so no callout bubble.
        marker.canShowCallout = false
        marker.titleVisibility = .adaptive
        marker.accessibilityHint = "Opens the coffee shop's page"
        return marker
    }

    func mapView(_ mapView: MKMapView, didSelect annotation: any MKAnnotation) {
        guard let pin = annotation as? CafePin else { return }
        // Deselect so tapping the same pin again after coming back still opens it.
        deselectAnnotation(annotation, animated: false)
        onShowCafe?(pin.cafe)
    }
}
