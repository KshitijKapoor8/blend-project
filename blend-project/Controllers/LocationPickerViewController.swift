import MapKit
import UIKit
import FirebaseAuth
import FirebaseFirestore

// Resolve the user's text to an explicit place before applying a distance filter
final class LocationPickerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {
    var onSelect: ((CafeSearchArea) -> Void)?
    private let currentArea: CafeSearchArea?
    private let locationField = PaddedTextField()
    private let statusLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let searchButton = UIButton(type: .system)
    private var places: [MKMapItem] = []
    private var search: MKLocalSearch?
    private var task: Task<Void, Never>?
    private let db = Firestore.firestore()
    private let defaultRadiusMiles: Double = 3

    init(area: CafeSearchArea?) {
        currentArea = area
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("Use init(area:)") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Choose location"
        view.backgroundColor = .blendCream
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
        locationField.placeholder = "City, neighborhood, or address"
        locationField.text = currentArea?.name
        locationField.returnKeyType = .search
        locationField.delegate = self
        locationField.clearButtonMode = .whileEditing
        locationField.addTarget(self, action: #selector(locationChanged), for: .editingChanged)
        locationField.accessibilityIdentifier = "locationInput"

        for field in [locationField] {
            field.backgroundColor = .blendCard
            field.borderWidth = 1
            field.borderColor = .blendLine
            field.cornerRadius = 8
            field.heightAnchor.constraint(equalToConstant: 48).isActive = true
        }
        updateSearchButton()
        searchButton.setTitleColor(.blendCard, for: .normal)
        searchButton.backgroundColor = .blendEspresso
        searchButton.cornerRadius = 8
        searchButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        searchButton.addTarget(self, action: #selector(findLocation), for: .touchUpInside)
        statusLabel.text = "Enter a location, then choose a result below. Radius will use your profile setting."
        statusLabel.font = .preferredFont(forTextStyle: .subheadline)
        statusLabel.textColor = .blendMuted
        statusLabel.numberOfLines = 0
        statusLabel.accessibilityTraits = .updatesFrequently
        let stack = UIStackView(arrangedSubviews: [locationField, searchButton, statusLabel, tableView])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -12),
        ])
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.keyboardDismissMode = .onDrag
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        task?.cancel()
        search?.cancel()
    }

    private var locationQuery: String {
        (locationField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func updateSearchButton() {
        searchButton.setTitle("Find location", for: .normal)
    }

    /// Loads the radius saved in the user's profile, falling back to the default.
    private func loadProfileRadius(completion: @escaping (Double) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(defaultRadiusMiles)
            return
        }
        db.collection("users").document(uid).getDocument { [weak self] snap, _ in
            let fallback = self?.defaultRadiusMiles ?? 3
            if let radius = (snap?.data()? ["radiusMiles"] as? NSNumber)?.doubleValue,
               radius.isFinite, (0.5...50).contains(radius) {
                completion(radius)
            } else {
                completion(fallback)
            }
        }
    }

    @objc private func locationChanged() {
        task?.cancel()
        search?.cancel()
        places = []
        tableView.reloadData()
        searchButton.isEnabled = true
        updateSearchButton()
        statusLabel.text = "Find the location, then choose a result below."
    }

    @objc private func findLocation() {
        let query = locationQuery
        guard !query.isEmpty else {
            statusLabel.text = "Enter a city, neighborhood, or address."
            return
        }
        view.endEditing(true)
        task?.cancel()
        search?.cancel()
        places = []
        tableView.reloadData()
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .address
        let search = MKLocalSearch(request: request)
        self.search = search
        searchButton.isEnabled = false
        statusLabel.text = "Finding locations…"
        task = Task { [weak self] in
            do {
                let response = try await search.start()
                guard !Task.isCancelled, let self else { return }
                self.places = response.mapItems
                self.statusLabel.text = self.places.isEmpty
                    ? "No locations found. Try a city or a more complete address."
                    : "Choose your location to find nearby coffee shops."
                self.tableView.reloadData()
                self.searchButton.isEnabled = true
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.statusLabel.text = "Couldn't find that location. Check your connection and try again."
                self.searchButton.isEnabled = true
            }
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        findLocation()
        return true
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { places.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        let place = places[indexPath.row]
        cell.textLabel?.text = place.name
        cell.detailTextLabel?.text = place.address?.fullAddress
        cell.detailTextLabel?.numberOfLines = 0
        cell.backgroundColor = .blendCard
        cell.textLabel?.textColor = .blendInk
        cell.detailTextLabel?.textColor = .blendMuted
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let place = places[indexPath.row]
        let coordinate = place.location.coordinate
        let name = place.name ?? locationField.text ?? "Selected location"
        loadProfileRadius { [weak self] radius in
            guard let self else { return }
            self.onSelect?(CafeSearchArea(name: name, coordinate: coordinate, radiusMiles: radius))
            self.dismiss(animated: true)
        }
    }
}
