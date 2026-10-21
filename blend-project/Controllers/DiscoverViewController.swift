import MapKit
import UIKit

final class DiscoverViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {
    private let locationButton = UIButton(type: .system)
    private let searchBar = UISearchBar()
    private let statusLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let retryButton = UIButton(type: .system)
    private let service = CafeSearchService()
    private var area: CafeSearchArea?
    private var cafes: [NearbyCafe] = []
    private var task: Task<Void, Never>?
    private var requestID = UUID()

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
        let stack = UIStackView(arrangedSubviews: [header, searchBar, nearLabel, statusLabel, retryButton, tableView])
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
        updateLocationButton()
        if area != nil { loadCafes() }
        else { statusLabel.text = "Choose a location and radius to discover nearby coffee shops." }
    }

    @objc private func editLocation() {
        view.endEditing(true)
        let picker = LocationPickerViewController(area: area)
        picker.onSelect = { [weak self] area in
            guard let self else { return }
            self.area = area
            self.saveArea(area)
            self.updateLocationButton()
            self.loadCafes()
        }
        present(UINavigationController(rootViewController: picker), animated: true)
    }

    private func updateLocationButton() {
        locationButton.setTitle(" " + (area?.summary ?? "Choose location & radius"), for: .normal)
        locationButton.accessibilityLabel = "Location and radius: \(area?.summary ?? "Not selected")"
    }

    @objc private func loadCafes() {
        guard let area else { return }
        task?.cancel()
        service.cancel()
        let id = UUID()
        requestID = id
        cafes = []
        tableView.reloadData()
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
        tableView.reloadData()
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
        content.secondaryText = "\(cafe.distanceText) · \(cafe.mapItem.address?.fullAddress ?? "")"
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
        visibleCafes[indexPath.row].mapItem.openInMaps()
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
}
