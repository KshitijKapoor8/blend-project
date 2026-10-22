//
//  ProfileViewController.swift
//  blend-project
//

import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

class ProfileViewController: UIViewController {


    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var bioLabel: UILabel!
    @IBOutlet weak var shopsCountLabel: UILabel!
    @IBOutlet weak var ratingsCountLabel: UILabel!
    @IBOutlet weak var contentStack: UIStackView!

    private let db = Firestore.firestore()
    // Horizontal row of the user's rating cards (testing aid).
    private let ratingsRow = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Clear storyboard placeholder text so it never shows as real data.
        nameLabel.text = nil
        usernameLabel.text = nil
        bioLabel.text = nil
        shopsCountLabel.text = "0"
        ratingsCountLabel.text = "0"
        addRatingsSection()
    }

    // Ensures that profile will reflect updates
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadUserProfile()
        loadRatings()
    }

    private func loadUserProfile() {
        // Get logged in user's uid
        guard let uid = Auth.auth().currentUser?.uid else {
            print("No user is signed in.")
            return
        }

        // Fetch the user's document from Firestore
        db.collection("users").document(uid).getDocument { [weak self] snapshot, error in
            // Ignore the result if a different user signed in while this was loading
            guard let self = self, Auth.auth().currentUser?.uid == uid else { return }
            guard let data = snapshot?.data(), error == nil else {
                print("Error fetching user profile: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            self.nameLabel.text = data["name"] as? String
            let username = data["username"] as? String ?? ""
            self.usernameLabel.text = username.isEmpty ? nil : "@\(username)"
            self.bioLabel.text = data["bio"] as? String
            self.shopsCountLabel.text = "\((data["shopsVisitedCount"] as? NSNumber)?.intValue ?? 0)"

            // Update pfp
            self.profileImageView.image = nil
            if let photoURLString = data["photoURL"] as? String,
               !photoURLString.isEmpty,
               let url = URL(string: photoURLString) {

                URLSession.shared.dataTask(with: url) { data, _, error in
                    if let error = error {
                        print("Error downloading profile image: \(error.localizedDescription)")
                        return
                    }
                    if let data = data, let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            guard Auth.auth().currentUser?.uid == uid else { return }
                            self.profileImageView.image = image
                        }
                    }
                }.resume()
            }
        }
    }

    private func addRatingsSection() {
        let title = UILabel()
        title.text = "Your ratings"
        title.font = .systemFont(ofSize: 17, weight: .semibold)
        title.textColor = .blendInk

        ratingsRow.axis = .horizontal
        ratingsRow.spacing = 12
        ratingsRow.alignment = .fill
        ratingsRow.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.addSubview(ratingsRow)
        NSLayoutConstraint.activate([
            ratingsRow.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            ratingsRow.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            ratingsRow.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            ratingsRow.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            ratingsRow.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: 170)
        ])

        let section = UIStackView(arrangedSubviews: [title, scrollView])
        section.axis = .vertical
        section.spacing = 10
        contentStack.insertArrangedSubview(section, at: max(contentStack.arrangedSubviews.count - 1, 0))
    }

    private func loadRatings() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        // Sorted client-side 
        db.collection("ratings").whereField("userId", isEqualTo: uid).getDocuments { [weak self] snapshot, error in
            guard let self = self, Auth.auth().currentUser?.uid == uid else { return }
            if let error = error {
                print("Error fetching ratings: \(error.localizedDescription)")
                return
            }
            let ratings = (snapshot?.documents ?? [])
                .sorted {
                    let a = ($0.data()["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast
                    let b = ($1.data()["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast
                    return a > b
                }

            self.ratingsCountLabel.text = "\(ratings.count)"
            self.ratingsRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
            if ratings.isEmpty {
                self.ratingsRow.addArrangedSubview(self.makeCard(lines: [("No ratings yet. Rate a shop to see it here.", .blendMuted, 14, .regular)]))
            }
            for rating in ratings {
                self.ratingsRow.addArrangedSubview(self.makeRatingCard(rating))
            }
        }
    }

    private func makeRatingCard(_ document: QueryDocumentSnapshot) -> UIView {
        let rating = document.data()
        let shopName = rating["shopName"] as? String ?? "Unknown shop"
        let score = (rating["score"] as? NSNumber)?.doubleValue ?? 0
        let categories = rating["ratings"] as? [String: Any] ?? [:]
        let categoryText = [("product", "Product"), ("vibe", "Vibe"), ("service", "Service"), ("seating", "Seating"), ("location", "Location")]
            .compactMap { key, name in (categories[key] as? NSNumber).map { "\(name) \($0.intValue)" } }
            .joined(separator: " · ")
        let comment = (rating["comment"] as? String).flatMap { $0.isEmpty ? nil : "\u{201C}\($0)\u{201D}" }

        var lines: [(String, UIColor, CGFloat, UIFont.Weight)] = [
            (shopName, .blendInk, 15, .semibold),
            (String(format: "\u{2605} %.1f", score), .blendMocha, 14, .semibold),
            (categoryText, .blendMuted, 12, .regular)
        ]
        if let comment = comment {
            lines.append((comment, .blendInk, 13, .regular))
        }
        if let date = (rating["updatedAt"] as? Timestamp)?.dateValue() {
            lines.append((date.formatted(date: .abbreviated, time: .shortened), .blendMuted, 11, .regular))
        }
        return makeCard(lines: lines) { [weak self] in
            self?.confirmDelete(document, shopName: shopName)
        }
    }

    private func confirmDelete(_ document: QueryDocumentSnapshot, shopName: String) {
        let alert = UIAlertController(title: "Delete rating?", message: "Your rating of \(shopName) will be removed.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteRating(document)
        })
        present(alert, animated: true)
    }

    private func deleteRating(_ document: QueryDocumentSnapshot) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        // Undo what posting did: remove the rating and the shop-visited count it added.
        let batch = db.batch()
        batch.deleteDocument(document.reference)
        batch.setData(["shopsVisitedCount": FieldValue.increment(Int64(-1))], forDocument: db.collection("users").document(uid), merge: true)
        batch.commit { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                self.showMessage("Couldn't delete rating", error.localizedDescription)
                return
            }
            if let photoURL = document.data()["photoURL"] as? String, !photoURL.isEmpty {
                Storage.storage().reference(forURL: photoURL).delete { error in
                    if let error = error { print("Error deleting rating photo: \(error.localizedDescription)") }
                }
            }
            self.loadUserProfile()
            self.loadRatings()
        }
    }

    private func makeCard(lines: [(String, UIColor, CGFloat, UIFont.Weight)], onDelete: (() -> Void)? = nil) -> UIView {
        let stack = UIStackView(arrangedSubviews: lines.map { text, color, size, weight in
            let label = UILabel()
            label.text = text
            label.textColor = color
            label.font = .systemFont(ofSize: size, weight: weight)
            label.numberOfLines = 2
            return label
        })
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        let card = UIView()
        card.backgroundColor = .blendCard
        card.cornerRadius = 12
        card.borderWidth = 1
        card.borderColor = .blendLine
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            card.widthAnchor.constraint(equalToConstant: 230),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            // Leave room for the trash button in the top-right corner
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: onDelete == nil ? -12 : -40),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -12)
        ])

        if let onDelete = onDelete {
            let trash = UIButton(type: .system, primaryAction: UIAction { _ in onDelete() })
            trash.setImage(UIImage(systemName: "trash"), for: .normal)
            trash.tintColor = .blendDanger
            trash.accessibilityLabel = "Delete rating"
            trash.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(trash)
            NSLayoutConstraint.activate([
                trash.topAnchor.constraint(equalTo: card.topAnchor, constant: 4),
                trash.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -4),
                trash.widthAnchor.constraint(equalToConstant: 36),
                trash.heightAnchor.constraint(equalToConstant: 36)
            ])
        }
        return card
    }
}
