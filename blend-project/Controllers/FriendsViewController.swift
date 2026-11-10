import FirebaseAuth
import UIKit

final class FriendsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {
    private enum Mode: Int { case friends, requests, find }
    private enum Row {
        case connection(FriendConnection)
        case person(FriendProfile)
    }

    private let service = FriendsService()
    private let tabs = UISegmentedControl(items: ["Friends", "Requests", "Find"])
    private let search = UISearchBar()
    private let status = UILabel()
    private let discoveryButton = UIButton(type: .system)
    private let retryButton = UIButton(type: .system)
    private let table = UITableView(frame: .zero, style: .insetGrouped)
    private let refresh = UIRefreshControl()
    private var overview: FriendsService.Overview?
    private var matches: [FriendProfile]?
    private var sections: [(title: String?, rows: [Row])] = []
    private var user: String?
    private var busy = false
    private var errorMessage: String?
    private var mode: Mode { Mode(rawValue: tabs.selectedSegmentIndex) ?? .friends }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .blendCream
        let title = UILabel()
        title.text = "Friends"
        title.font = .preferredFont(forTextStyle: .largeTitle)
        title.adjustsFontForContentSizeCategory = true
        title.textColor = .blendInk
        title.accessibilityTraits = .header

        tabs.selectedSegmentIndex = Mode.friends.rawValue
        tabs.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        tabs.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true

        search.searchBarStyle = .minimal
        search.placeholder = "Exact username"
        search.autocapitalizationType = .none
        search.autocorrectionType = .no
        search.delegate = self

        status.numberOfLines = 0
        status.font = .preferredFont(forTextStyle: .subheadline)
        status.adjustsFontForContentSizeCategory = true
        status.textColor = .blendMuted
        status.accessibilityTraits = .updatesFrequently

        for button in [discoveryButton, retryButton] {
            button.tintColor = .blendEspresso
            button.titleLabel?.numberOfLines = 0
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        }
        discoveryButton.addTarget(self, action: #selector(toggleDiscovery), for: .touchUpInside)
        retryButton.setTitle("Refresh Friends", for: .normal)
        retryButton.addTarget(self, action: #selector(reload), for: .touchUpInside)

        table.dataSource = self
        table.delegate = self
        table.keyboardDismissMode = .onDrag
        table.alwaysBounceVertical = true
        table.backgroundColor = .clear
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 64
        table.register(UITableViewCell.self, forCellReuseIdentifier: "Person")
        table.refreshControl = refresh
        refresh.addTarget(self, action: #selector(reload), for: .valueChanged)

        let stack = UIStackView(arrangedSubviews: [title, tabs, search, status, discoveryButton, retryButton, table])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        let safe = view.safeAreaLayoutGuide
        let keyboardLimit = stack.bottomAnchor.constraint(lessThanOrEqualTo: view.keyboardLayoutGuide.topAnchor)
        keyboardLimit.priority = .required
        let bottom = stack.bottomAnchor.constraint(equalTo: safe.bottomAnchor)
        bottom.priority = .defaultHigh
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: safe.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            bottom, keyboardLimit,
            stack.bottomAnchor.constraint(lessThanOrEqualTo: safe.bottomAnchor)
        ])
        render()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let account = Auth.auth().currentUser?.uid
        if account != user {
            user = account
            overview = nil
            matches = nil
            search.text = nil
        }
        reload()
    }

    @objc private func reload() {
        perform { screen, uid in
            screen.overview = try await screen.service.overview(for: uid)
            if screen.overview?.discoverable != true { screen.matches = nil }
        }
    }

    private func perform(_ operation: @escaping (FriendsViewController, String) async throws -> Void) {
        guard !busy else { return }
        guard let user, Auth.auth().currentUser?.uid == user else {
            refresh.endRefreshing()
            render()
            return
        }
        busy = true
        errorMessage = nil
        render()
        Task { [weak self] in
            guard let self else { return }
            defer {
                self.busy = false
                self.refresh.endRefreshing()
                if Auth.auth().currentUser?.uid != user {
                    self.overview = nil
                    self.matches = nil
                }
                self.render()
            }
            do {
                try await operation(self, user)
            } catch let error as FriendsError {
                self.errorMessage = error.localizedDescription
            } catch {
                self.errorMessage = "Couldn't update Friends. Check your connection and try again."
            }
        }
    }

    @objc private func modeChanged() {
        view.endEditing(true)
        render()
    }

    @objc private func toggleDiscovery() {
        guard let current = overview?.discoverable else { return }
        if current {
            let alert = UIAlertController(title: "Hide from friend search?",
                                          message: "People won't find your username in search. Existing friends and requests will still show your name and username.",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Hide", style: .default) { [weak self] _ in
                self?.setDiscoverable(false)
            })
            present(alert, animated: true)
        } else {
            setDiscoverable(true)
        }
    }

    private func setDiscoverable(_ enabled: Bool) {
        perform { screen, uid in
            try await screen.service.setDiscoverable(enabled, for: uid)
            screen.matches = nil
            screen.overview = try await screen.service.overview(for: uid)
        }
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        let query = searchBar.text ?? ""
        guard !FriendProfile.lookupKey(query).isEmpty else { return }
        perform { screen, uid in
            screen.matches = try await screen.service.find(username: query, excluding: uid)
        }
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        matches = nil
        errorMessage = nil
        render()
    }

    private func render() {
        let discoverable = overview?.discoverable == true
        search.isHidden = mode != .find || !discoverable
        search.isUserInteractionEnabled = !busy
        discoveryButton.isHidden = mode != .find || overview == nil
        discoveryButton.isEnabled = !busy
        discoveryButton.setTitle(discoverable ? "Hide from friend search" : "Enable friend discovery", for: .normal)
        retryButton.isHidden = errorMessage == nil || busy
        table.isUserInteractionEnabled = !busy

        let links = overview?.connections ?? []
        let sorted = links.sorted {
            let first = name(for: $0)
            let second = name(for: $1)
            let order = first.localizedCaseInsensitiveCompare(second)
            return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
        }
        let pending = sorted.filter { $0.status == .pending }
        let incoming = pending.filter { $0.recipient == user }
        let outgoing = pending.filter { $0.sender == user }
        tabs.setTitle(incoming.isEmpty ? "Requests" : "Requests (\(incoming.count))", forSegmentAt: Mode.requests.rawValue)
        tabBarItem.badgeValue = incoming.isEmpty ? nil : String(incoming.count)

        let guidance: String
        sections = []
        switch mode {
        case .friends:
            let friends = sorted.filter { $0.status == .accepted }
            if !friends.isEmpty { sections = [(nil, friends.map(Row.connection))] }
            guidance = friends.isEmpty ? "No friends yet. Open Find to connect by username."
                : "\(friends.count) \(friends.count == 1 ? "friend" : "friends") · Tap a friend for options."
        case .requests:
            if !incoming.isEmpty { sections.append(("Received", incoming.map(Row.connection))) }
            if !outgoing.isEmpty { sections.append(("Sent", outgoing.map(Row.connection))) }
            guidance = pending.isEmpty ? "No pending requests." : "Tap a request to respond or cancel."
        case .find:
            if !discoverable {
                guidance = "Enable discovery to share your name and username with signed-in Blend members and send friend requests."
            } else if let matches {
                if !matches.isEmpty { sections = [(nil, matches.map(Row.person))] }
                guidance = matches.isEmpty ? "No matching member. Check the username and ask them to enable discovery."
                    : "Tap a member to send a request."
            } else {
                guidance = "Enter a friend's exact username and tap Search on the keyboard."
            }
        }
        if busy {
            status.text = "Updating Friends…"
        } else if let errorMessage {
            status.text = errorMessage
        } else if user == nil {
            status.text = "Sign in to use Friends."
        } else {
            status.text = guidance
        }
        table.reloadData()
    }

    private func name(for connection: FriendConnection) -> String {
        guard let user else { return "Blend member" }
        return connection.otherProfile(than: user).name
    }

    func numberOfSections(in tableView: UITableView) -> Int { sections.count }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sections[section].rows.count }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { sections[section].title }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Person", for: indexPath)
        var content = cell.defaultContentConfiguration()
        switch sections[indexPath.section].rows[indexPath.row] {
        case .person(let profile):
            content.text = profile.name
            let connection = overview?.connections.first { $0.otherUser(than: user ?? "") == profile.id }
            let label = connection.map { link in
                link.status == .accepted ? "Friends" : link.sender == user ? "Request sent" : "Request received"
            }
            content.secondaryText = ["@\(profile.username)", label].compactMap { $0 }.joined(separator: " · ")
        case .connection(let link):
            content.text = name(for: link)
            let profile = user.map { link.otherProfile(than: $0) }
            content.secondaryText = profile.map { "@\($0.username)" }
        }
        content.image = UIImage(systemName: "person.crop.circle")
        content.imageProperties.tintColor = .blendMocha
        content.textProperties.color = .blendInk
        content.secondaryTextProperties.color = .blendMuted
        cell.contentConfiguration = content
        cell.backgroundColor = .blendCard
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !busy, let user else { return }
        view.endEditing(true)
        switch sections[indexPath.section].rows[indexPath.row] {
        case .connection(let link): showActions(for: link, user: user)
        case .person(let profile):
            if let link = overview?.connections.first(where: { $0.otherUser(than: user) == profile.id }) {
                showActions(for: link, user: user)
                return
            }
            let alert = UIAlertController(title: "Connect with \(profile.name)?", message: "@\(profile.username)", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Send request", style: .default) { [weak self] _ in
                self?.change { service, uid in try await service.request(from: uid, to: profile.id) }
            })
            present(alert, animated: true)
        }
    }

    private func showActions(for link: FriendConnection, user: String) {
        let alert = UIAlertController(title: name(for: link), message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Close", style: .cancel))
        if link.status == .pending && link.recipient == user {
            alert.addAction(UIAlertAction(title: "Accept request", style: .default) { [weak self] _ in
                self?.change { service, _ in try await service.accept(link) }
            })
        }
        let removal = link.status == .accepted ? "Remove friend" : link.sender == user ? "Cancel request" : "Decline request"
        alert.addAction(UIAlertAction(title: removal, style: .destructive) { [weak self] _ in
            self?.change { service, _ in try await service.remove(link) }
        })
        present(alert, animated: true)
    }

    private func change(_ action: @escaping (FriendsService, String) async throws -> Void) {
        perform { screen, uid in
            try await action(screen.service, uid)
            screen.overview = try await screen.service.overview(for: uid)
        }
    }
}
