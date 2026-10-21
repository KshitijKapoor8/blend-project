//
//  ProfileViewController.swift
//  blend-project
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class ProfileViewController: UIViewController {


    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var bioLabel: UILabel!

    private let db = Firestore.firestore()

    override func viewDidLoad() {
        super.viewDidLoad()
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
            guard let self = self, let data = snapshot?.data(), error == nil else {
                print("Error fetching user profile: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            // Update bio
            if let bio = data["bio"] as? String {
                self.bioLabel.text = bio
            }

            // Update pfp
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
                            self.profileImageView.image = image
                        }
                    }
                }.resume()
            } else {
                DispatchQueue.main.async {
                    self.profileImageView.image = nil
                }
            }
        }
    }
}
