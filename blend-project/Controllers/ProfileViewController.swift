//
//  ProfileViewController.swift
//  blend-project
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class ProfileViewController: UIViewController {


    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var bioLabel: UILabel!
    @IBOutlet weak var shopsCountLabel: UILabel!

    private let db = Firestore.firestore()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Clear storyboard placeholder text so it never shows as real data.
        nameLabel.text = nil
        usernameLabel.text = nil
        bioLabel.text = nil
        shopsCountLabel.text = "0"
    }

    // Ensures that profile will reflect updates
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadUserProfile()
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
}
