import MapKit
import UIKit
import FirebaseAuth
import FirebaseFirestore

final class DiscoverViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {
    private let locationButton = UIButton(type: .system)
    private let searchBar = UISearchBar()
    private let statusLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let resultMode = UISegmentedControl(items: ["List", "Map"])
    private let map = CafeMapView(frame: .zero)
    private let recenterButton = UIButton(type: .system)
    private let retryButton = UIButton(type: .system)
    private let service = CafeSearchService()
    private var area: CafeSearchArea?
    private var cafes: [NearbyCafe] = []
    private var task: Task<Void, Never>?
    private var requestID = UUID()

    private let db = Firestore.firestore()
    private var profileRadiusMiles: Double?

    private var visibleCafes: [NearbyCafe] {
        let query = (searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? cafes : cafes.filter { ($0.mapItem.name ?? "").localizedCaseInsensitiveContains(query) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .blendCream
        let titleLabel = UILabel()
        titleLabel.text = "Discover"
        titleLabel.font = .systemFont(ofSize: 30, weight: .bold)
        titleLabel.textColor = .blendInk
        titleLabel.accessibilityTraits = .header
        locationButton.setImage(UIImage(systemName: "mappin.and.ellipse"), for: .normal)
        locationButton.tintColor = .blendEspresso
        locationButton.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
        locationButton.titleLabel?.numberOfLines = 2
        locationButton.accessibilityIdentifier = "locationAndRadius"
        locationButton.addTarget(self, action: #selector(editLocation), for: .touchUpInside)
        locationButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        let header = UIStackView(arrangedSubviews: [titleLabel, locationButton])
        header.axis = .horizontal
        header.alignment = .center
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        header.spacing = 8
        searchBar.placeholder = "Search coffee shops"
        searchBar.searchBarStyle = .minimal
        searchBar.delegate = self
        searchBar.accessibilityIdentifier = "coffeeShopSearch"
        statusLabel.numberOfLines = 0
        statusLabel.font = .preferredFont(forTextStyle: .subheadline)
        statusLabel.textColor = .blendMuted
        statusLabel.accessibilityTraits = .updatesFrequently
        let nearLabel = UILabel()
        nearLabel.text = "Near you"
        nearLabel.font = .preferredFont(forTextStyle: .headline)
        nearLabel.textColor = .blendInk
        nearLabel.accessibilityTraits = .header
        retryButton.setTitle("Try again", for: .normal)
        retryButton.tintColor = .blendEspresso
        retryButton.addTarget(self, action: #selector(loadCafes), for: .touchUpInside)
        retryButton.isHidden = true
        resultMode.selectedSegmentIndex = 0
        resultMode.accessibilityLabel = "Coffee shop results view"
        resultMode.addTarget(self, action: #selector(changeResultMode), for: .valueChanged)
        resultMode.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        recenterButton.setTitle("Recenter search area", for: .normal)
        recenterButton.tintColor = .blendEspresso
        recenterButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        recenterButton.addTarget(self, action: #selector(recenterMap), for: .touchUpInside)
        map.cornerRadius = 10
        map.clipsToBounds = true
        map.accessibilityIdentifier = "coffeeShopMap"
        map.onShowCafe = { [weak self] cafe in self?.showDetails(for: cafe) }
        let results = UIView()
        for child in [tableView, map] {
            child.translatesAutoresizingMaskIntoConstraints = false
            results.addSubview(child)
            NSLayoutConstraint.activate([
                child.topAnchor.constraint(equalTo: results.topAnchor),
                child.bottomAnchor.constraint(equalTo: results.bottomAnchor),
                child.leadingAnchor.constraint(equalTo: results.leadingAnchor),
                child.trailingAnchor.constraint(equalTo: results.trailingAnchor),
            ])
        }
        let stack = UIStackView(arrangedSubviews: [header, searchBar, resultMode, nearLabel, statusLabel, retryButton, recenterButton, results])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        tableView.keyboardDismissMode = .onDrag
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cafe")
        restoreArea()
        fetchProfileRadiusIfNeeded()
        updateLocationButton()
<<<<<<< HEAD
        changeResultMode()
        if let area {
            map.setArea(area)
            loadCafes()
        } else {
            showNoAreaState()
=======
        if area != nil { loadCafes() }
        else {
            if let radius = profileRadiusMiles {
                statusLabel.text = "Choose a location to discover coffee shops within \(radius.formatted()) miles."
                locationButton.setTitle(" Choose location · \(radius.formatted()) mi", for: .normal)
                locationButton.accessibilityLabel = "Location and radius: Not selected. Radius \(radius.formatted()) miles from your profile."
            } else {
                statusLabel.text = "Choose a location to discover nearby coffee shops."
            }
>>>>>>> 8bcefb4 (now uses radius stored in user profile rather than manually adjusting radius)
        }
    }

    @objc private func editLocation() {
        view.endEditing(true)
        let picker = LocationPickerViewController(area: area)
        picker.onSelect = { [weak self] area in
            guard let self else { return }
            self.area = area
            self.saveArea(area)
            self.updateLocationButton()
            self.changeResultMode()
            self.map.setArea(area)
            self.loadCafes()
        }
        present(UINavigationController(rootViewController: picker), animated: true)
    }

    private func updateLocationButton() {
<<<<<<< HEAD
        if let area {
            locationButton.setTitle(" " + area.name, for: .normal)
            locationButton.accessibilityLabel = "Location: \(area.name)"
        } else if let radius = profileRadiusMiles {
            locationButton.setTitle(" Choose location · \(radius.formatted()) mi", for: .normal)
            locationButton.accessibilityLabel = "Location and radius: Not selected. Radius \(radius.formatted()) miles from your profile."
        } else {
            locationButton.setTitle(" Choose location", for: .normal)
            locationButton.accessibilityLabel = "Location: Choose location"
        }
=======
        let title = area?.name ?? "Choose location"
        locationButton.setTitle(" " + title, for: .normal)
        locationButton.accessibilityLabel = "Location: \(title)"
>>>>>>> 8bcefb4 (now uses radius stored in user profile rather than manually adjusting radius)
    }

    /// Status text shown before the user has picked a location.
    private func showNoAreaState() {
        if let radius = profileRadiusMiles {
            statusLabel.text = "Choose a location to discover coffee shops within \(radius.formatted()) miles."
        } else {
            statusLabel.text = "Choose a location to discover nearby coffee shops."
        }
    }

    @objc private func changeResultMode() {
        view.endEditing(true)
        let showMap = resultMode.selectedSegmentIndex == 1 && area != nil
        tableView.isHidden = showMap
        map.isHidden = !showMap
        recenterButton.isHidden = !showMap
        if showMap {
            view.layoutIfNeeded()
            map.recenter(animated: false)
        }
    }

    @objc private func recenterMap() { map.recenter() }

    @objc private func loadCafes() {
        guard let area else { return }
        task?.cancel()
        service.cancel()
        let id = UUID()
        requestID = id
        cafes = []
        updateResultViews()
        statusLabel.text = "Finding coffee shops within \(area.radiusMiles.formatted()) miles…"
        retryButton.isHidden = true
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let results = try await self.service.cafes(in: area)
                guard !Task.isCancelled, self.requestID == id else { return }
                self.cafes = results
                self.updateResults()
            } catch {
                guard !Task.isCancelled, self.requestID == id else { return }
                self.statusLabel.text = "Couldn't load coffee shops. Check your connection and try again."
                self.retryButton.isHidden = false
            }
        }
    }

    private func updateResults() {
        let count = visibleCafes.count
        if cafes.isEmpty {
            statusLabel.text = "No coffee shops found in this radius. Try another location or a larger radius."
        } else if count == 0 {
            statusLabel.text = "No coffee shops match your search in this radius."
        } else {
            statusLabel.text = "\(count) coffee \(count == 1 ? "shop" : "shops") · nearest first"
        }
        updateResultViews()
    }

    private func updateResultViews() {
        tableView.reloadData()
        map.showCafes(visibleCafes)
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // Text search narrows only the cafes already inside the selected radius.
        if area != nil, !cafes.isEmpty { updateResults() }
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) { searchBar.resignFirstResponder() }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { visibleCafes.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cafe = visibleCafes[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cafe", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = cafe.mapItem.name ?? "Coffee shop"
        content.secondaryText = [cafe.distanceText, cafe.mapItem.address?.fullAddress]
            .compactMap { $0 }.joined(separator: " · ")
        content.image = UIImage(systemName: "cup.and.saucer.fill")
        content.imageProperties.tintColor = .blendMocha
        content.textProperties.color = .blendInk
        content.secondaryTextProperties.color = .blendMuted
        content.secondaryTextProperties.numberOfLines = 0
        cell.contentConfiguration = content
        cell.backgroundColor = .blendCard
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        showDetails(for: visibleCafes[indexPath.row])
    }

    private func showDetails(for cafe: NearbyCafe) {
        view.endEditing(true)
        let item = cafe.mapItem
        let details = [cafe.distanceText, item.address?.fullAddress].compactMap { $0 }.joined(separator: "\n")
        let alert = UIAlertController(title: item.name ?? "Coffee shop", message: details, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Open in Apple Maps", style: .default) { [weak self] _ in
            if !item.openInMaps() { self?.showMessage("Couldn't open Apple Maps") }
        })
        alert.addAction(UIAlertAction(title: "Walking directions", style: .default) { [weak self] _ in
            if !item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking]) {
                self?.showMessage("Couldn't open directions")
            }
        })
        alert.addAction(UIAlertAction(title: "Close", style: .cancel))
        present(alert, animated: true)
    }

    private func saveArea(_ area: CafeSearchArea) {
        UserDefaults.standard.set(["name": area.name, "latitude": area.coordinate.latitude,
                                  "longitude": area.coordinate.longitude, "radius": area.radiusMiles],
                                 forKey: "discoverSearchArea")
    }

    private func restoreArea() {
        guard let saved = UserDefaults.standard.dictionary(forKey: "discoverSearchArea"),
              let name = saved["name"] as? String,
              let latitude = saved["latitude"] as? Double,
              let longitude = saved["longitude"] as? Double,
              let radius = saved["radius"] as? Double,
              radius.isFinite, (0.5...50).contains(radius) else { return }
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        guard CLLocationCoordinate2DIsValid(coordinate) else { return }
        area = CafeSearchArea(name: name, coordinate: coordinate, radiusMiles: radius)
    }

    private func fetchProfileRadiusIfNeeded() {
        // Only fetch if no saved area and a user is signed in
        guard area == nil, let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).getDocument { [weak self] snap, _ in
<<<<<<< HEAD
            guard let self, self.area == nil else { return }
            if let radius = (snap?.data()?["radiusMiles"] as? NSNumber)?.doubleValue,
               radius.isFinite, (0.5...50).contains(radius) {
                self.profileRadiusMiles = radius
                // Reflect the radius hint in the UI if no area has been chosen yet
                self.updateLocationButton()
                self.showNoAreaState()
=======
            guard let self = self, self.area == nil else { return }
            if let radiusNum = (snap?.data()? ["radiusMiles"] as? NSNumber)?.doubleValue,
               radiusNum.isFinite, (0.5...50).contains(radiusNum) {
                self.profileRadiusMiles = radiusNum
                // Reflect the radius hint in the UI if no area has been chosen yet
                if self.area == nil {
                    self.statusLabel.text = "Choose a location to discover coffee shops within \(radiusNum.formatted()) miles."
                    self.locationButton.setTitle(" Choose location · \(radiusNum.formatted()) mi", for: .normal)
                    self.locationButton.accessibilityLabel = "Location and radius: Not selected. Radius \(radiusNum.formatted()) miles from your profile."
                }
>>>>>>> 8bcefb4 (now uses radius stored in user profile rather than manually adjusting radius)
            }
        }
    }
}
