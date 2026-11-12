import FirebaseAuth
import FirebaseFirestore
import MapKit
import UIKit

/// A coffee shop's page, opened from Discover (map pin or list row), with a Rate button.
final class CafeDetailViewController: UIViewController {
    private let cafe: NearbyCafe
    private let db = Firestore.firestore()
    private let ratingLabel = UILabel()
    private let rateButton = UIButton(type: .system)
    private var hasRating = false

    init(cafe: NearbyCafe) {
        self.cafe = cafe
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("Use init(cafe:)") }

    /// Stable id used in the "<uid>_<shopId>" rating document id.
    static func shopId(for item: MKMapItem) -> String {
        let raw: String
        if let identifier = item.identifier?.rawValue, !identifier.isEmpty {
            raw = identifier
        } else {
            let coordinate = item.location.coordinate
            raw = String(format: "%@-%.5f-%.5f", item.name ?? "shop", coordinate.latitude, coordinate.longitude)
        }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        return String(raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
    }

    private var shopName: String { cafe.mapItem.name ?? "Coffee shop" }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .blendCream

        let back = UIButton(type: .system)
        back.setTitle(" Back", for: .normal)
        back.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        back.tintColor = .blendEspresso
        back.contentHorizontalAlignment = .leading
        back.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        back.addTarget(self, action: #selector(backTapped(_:)), for: .touchUpInside)

        let title = UILabel()
        title.text = shopName
        title.font = .systemFont(ofSize: 28, weight: .bold)
        title.textColor = .blendInk
        title.numberOfLines = 0
        title.accessibilityTraits = .header

        let item = cafe.mapItem
        let details = UILabel()
        details.text = [cafe.distanceText + " away", item.address?.fullAddress].compactMap { $0 }.joined(separator: "\n")
        details.font = .preferredFont(forTextStyle: .subheadline)
        details.adjustsFontForContentSizeCategory = true
        details.textColor = .blendMuted
        details.numberOfLines = 0

        let preview = MKMapView()
        preview.isUserInteractionEnabled = false
        preview.pointOfInterestFilter = .excludingAll
        preview.layer.cornerRadius = 12
        preview.clipsToBounds = true
        preview.heightAnchor.constraint(equalToConstant: 160).isActive = true
        let pin = MKPointAnnotation()
        pin.coordinate = item.location.coordinate
        preview.addAnnotation(pin)
        preview.setRegion(MKCoordinateRegion(center: pin.coordinate, latitudinalMeters: 500, longitudinalMeters: 500), animated: false)
        preview.accessibilityElementsHidden = true

        ratingLabel.font = .preferredFont(forTextStyle: .body)
        ratingLabel.adjustsFontForContentSizeCategory = true
        ratingLabel.textColor = .blendInk
        ratingLabel.numberOfLines = 0
        ratingLabel.isHidden = true

        var rateConfig = UIButton.Configuration.filled()
        rateConfig.title = "Rate this shop"
        rateConfig.image = UIImage(systemName: "star.fill")
        rateConfig.imagePadding = 8
        rateConfig.baseBackgroundColor = .blendEspresso
        rateConfig.baseForegroundColor = .white
        rateConfig.cornerStyle = .large
        rateButton.configuration = rateConfig
        rateButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
        rateButton.addTarget(self, action: #selector(rateTapped), for: .touchUpInside)

        let directions = secondaryButton("Walking directions", symbol: "figure.walk", action: #selector(directionsTapped))
        let openMaps = secondaryButton("Open in Apple Maps", symbol: "map", action: #selector(openMapsTapped))
        var actions: [UIView] = [rateButton, directions, openMaps]
        if item.phoneNumber?.isEmpty == false {
            actions.append(secondaryButton("Call", symbol: "phone", action: #selector(callTapped)))
        }
        if item.url != nil {
            actions.append(secondaryButton("Website", symbol: "safari", action: #selector(websiteTapped)))
        }

        let stack = UIStackView(arrangedSubviews: [back, title, details, preview, ratingLabel] + actions)
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(4, after: back)
        stack.setCustomSpacing(20, after: ratingLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -20),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadOwnRating() // Refreshes after returning from the Rate screen.
    }

    private func secondaryButton(_ title: String, symbol: String, action: Selector) -> UIButton {
        var config = UIButton.Configuration.tinted()
        config.title = title
        config.image = UIImage(systemName: symbol)
        config.imagePadding = 8
        config.baseBackgroundColor = .blendLatte
        config.baseForegroundColor = .blendEspresso
        config.cornerStyle = .large
        let button = UIButton(configuration: config)
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func loadOwnRating() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let id = "\(uid)_\(Self.shopId(for: cafe.mapItem))"
        db.collection("ratings").document(id).getDocument { [weak self] snapshot, _ in
            guard let self else { return }
            if let score = (snapshot?.data()?["score"] as? NSNumber)?.doubleValue {
                self.hasRating = true
                self.ratingLabel.text = "Your rating: \(String(format: "%.1f", score)) / 5"
                self.ratingLabel.isHidden = false
            } else {
                self.hasRating = false
                self.ratingLabel.isHidden = true
            }
            self.rateButton.configuration?.title = self.hasRating ? "Update your rating" : "Rate this shop"
        }
    }

    @objc private func rateTapped() {
        guard Auth.auth().currentUser != nil else {
            showMessage("Sign in to rate", "Log in to rate coffee shops.")
            return
        }
        let storyboard = self.storyboard ?? UIStoryboard(name: "Main", bundle: nil)
        guard let rate = storyboard.instantiateViewController(withIdentifier: "Rate") as? RateViewController else { return }
        rate.shopId = Self.shopId(for: cafe.mapItem)
        rate.shopName = shopName
        navigationController?.pushViewController(rate, animated: true)
    }

    @objc private func directionsTapped() {
        if !cafe.mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking]) {
            showMessage("Couldn't open directions")
        }
    }

    @objc private func openMapsTapped() {
        if !cafe.mapItem.openInMaps() { showMessage("Couldn't open Apple Maps") }
    }

    @objc private func callTapped() {
        let digits = (cafe.mapItem.phoneNumber ?? "").filter { $0.isNumber || $0 == "+" }
        guard let url = URL(string: "tel:\(digits)") else { return }
        UIApplication.shared.open(url)
    }

    @objc private func websiteTapped() {
        guard let url = cafe.mapItem.url else { return }
        UIApplication.shared.open(url)
    }
}
