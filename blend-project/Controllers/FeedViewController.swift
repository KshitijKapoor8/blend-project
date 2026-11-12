import FirebaseAuth
import UIKit

final class FeedViewController: UIViewController, UITableViewDataSource {
    private let service = FeedService()
    private let status = UILabel()
    private let table = UITableView(frame: .zero, style: .plain)
    private let refresh = UIRefreshControl()
    private var items: [FeedItem] = []
    private var user: String?
    private var busy = false
    private var errorMessage: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .blendCream

        let title = UILabel()
        title.text = "Feed"
        title.font = .preferredFont(forTextStyle: .largeTitle)
        title.adjustsFontForContentSizeCategory = true
        title.textColor = .blendInk
        title.accessibilityTraits = .header

        let addFriend = UIButton(type: .system)
        addFriend.setImage(UIImage(systemName: "person.badge.plus"), for: .normal)
        addFriend.tintColor = .blendEspresso
        addFriend.backgroundColor = .blendCard
        addFriend.borderColor = .blendLatte
        addFriend.borderWidth = 1.5
        addFriend.cornerRadius = 26
        addFriend.accessibilityLabel = "Add friends"
        addFriend.addTarget(self, action: #selector(openFriends), for: .touchUpInside)
        NSLayoutConstraint.activate([
            addFriend.widthAnchor.constraint(equalToConstant: 52),
            addFriend.heightAnchor.constraint(equalToConstant: 52)
        ])

        let header = UIStackView(arrangedSubviews: [title, addFriend])
        header.alignment = .center

        status.numberOfLines = 0
        status.font = .preferredFont(forTextStyle: .subheadline)
        status.adjustsFontForContentSizeCategory = true
        status.textColor = .blendMuted
        status.textAlignment = .center
        status.accessibilityTraits = .updatesFrequently

        table.dataSource = self
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.showsVerticalScrollIndicator = false
        table.alwaysBounceVertical = true
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 120
        table.register(FeedReviewCell.self, forCellReuseIdentifier: FeedReviewCell.identifier)
        table.register(FeedActivityCell.self, forCellReuseIdentifier: FeedActivityCell.identifier)
        table.refreshControl = refresh
        refresh.addTarget(self, action: #selector(reload), for: .valueChanged)

        let stack = UIStackView(arrangedSubviews: [header, status, table])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: safe.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: safe.bottomAnchor)
        ])
        render()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let account = Auth.auth().currentUser?.uid
        if account != user {
            user = account
            items = []
        }
        reload()
    }

    @objc private func openFriends() {
        (tabBarController as? MainTabBarController)?.openFriends()
    }

    @objc private func reload() {
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
            do {
                let loaded = try await self.service.items(for: user)
                if Auth.auth().currentUser?.uid == user { self.items = loaded }
            } catch {
                self.errorMessage = "Couldn't load your feed. Pull down to try again."
            }
            self.busy = false
            self.refresh.endRefreshing()
            self.render()
        }
    }

    private func render() {
        if user == nil {
            status.text = "Sign in to see your friends' ratings."
        } else if let errorMessage {
            status.text = errorMessage
        } else if busy && items.isEmpty {
            status.text = "Loading your feed…"
        } else if items.isEmpty && !busy {
            status.text = "Nothing here yet. Add friends to see where they've been."
        } else {
            status.text = nil
        }
        status.isHidden = status.text == nil
        table.reloadData()
    }

    private func toggleLike(_ ratingId: String) {
        guard let user, let item = items.first(where: { $0.rating.id == ratingId }) else { return }
        let liked = !item.rating.likedBy.contains(user)
        setLiked(liked, ratingId: ratingId, user: user)
        Task { [weak self] in
            do {
                try await self?.service.setLiked(liked, ratingId: ratingId, user: user)
            } catch {
                self?.setLiked(!liked, ratingId: ratingId, user: user)
                self?.showMessage("Couldn't update like", "Check your connection and try again.")
            }
        }
    }

    /// Updates one post right away, without waiting for Firestore.
    private func setLiked(_ liked: Bool, ratingId: String, user: String) {
        guard let index = items.firstIndex(where: { $0.rating.id == ratingId }) else { return }
        items[index].rating.likedBy.removeAll { $0 == user }
        if liked { items[index].rating.likedBy.append(user) }
        table.reconfigureRows(at: [IndexPath(row: index, section: 0)])
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { items.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = items[indexPath.row]
        if item.kind == .review {
            let cell = tableView.dequeueReusableCell(withIdentifier: FeedReviewCell.identifier, for: indexPath) as! FeedReviewCell
            cell.configure(with: item, viewer: user)
            let ratingId = item.rating.id
            cell.onLike = { [weak self] in self?.toggleLike(ratingId) }
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: FeedActivityCell.identifier, for: indexPath) as! FeedActivityCell
        cell.configure(with: item)
        return cell
    }
}
