//
//  SettingsViewController.swift
//  blend-project
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class SettingsViewController: UIViewController, UITextViewDelegate {
    @IBOutlet weak var bioTextView: UITextView!
    @IBOutlet weak var bioCountLabel: UILabel!
    @IBOutlet weak var locationField: UITextField!
    @IBOutlet weak var radiusSlider: UISlider!
    @IBOutlet weak var radiusLabel: UILabel!

    private let bioLimit = 150
    
    private let db = Firestore.firestore()

    override func viewDidLoad() {
        super.viewDidLoad()
        bioTextView.delegate = self
        bioTextView.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        updateBioCount()
        radiusChanged(radiusSlider)
        if Auth.auth().currentUser == nil {
            Auth.auth().signIn(withEmail: "korny@gmail.com", password: "lalala") { [weak self] _, error in
                if let error = error { print("Sign in error:", error) }
                self?.loadSettings()
            }
        } else {
            loadSettings()
        }
    }
    
    private func loadSettings() {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("No signed-in user")
            return
        }
        db.collection("users").document(uid).getDocument { [weak self] snap, error in
            guard let self = self, let data = snap?.data() else { return }
            self.bioTextView.text = data["bio"] as? String ?? ""
            self.locationField.text = data["locationName"] as? String ?? ""
            self.radiusSlider.value = (data["radiusMiles"] as? NSNumber)?.floatValue ?? 5
            self.updateBioCount()
            self.radiusChanged(self.radiusSlider)
        }
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let current = textView.text as NSString
        return current.replacingCharacters(in: range, with: text).count <= bioLimit
    }

    func textViewDidChange(_ textView: UITextView) {
        updateBioCount()
    }

    private func updateBioCount() {
        bioCountLabel.text = "\(bioTextView.text.count)/\(bioLimit)"
    }

    @IBAction func radiusChanged(_ sender: UISlider) {
        sender.value = sender.value.rounded()
        radiusLabel.text = "\(Int(sender.value)) mi"
    }

    @IBAction func useCurrentLocationTapped(_ sender: UIButton) {
        locationField.text = "Austin, TX"
    }

    @IBAction func changePhotoTapped(_ sender: UIButton) {
        showMessage("Coming soon", "Photo uploads aren't available yet.")
    }

    @IBAction func saveTapped(_ sender: UIButton) {
        view.endEditing(true)
        guard let user = Auth.auth().currentUser else {
            showMessage("Not signed in", "Please log in and try again.")
            return
        }
        let ref = db.collection("users").document(user.uid)

        ref.getDocument { [weak self] snap, error in
            guard let self = self else { return }
            if let error = error {
                self.showMessage("Save failed", error.localizedDescription)
                return
            }
            let existing = snap?.data() ?? [:]

            // Fields this screen always writes
            var data: [String: Any] = [
                "bio": self.bioTextView.text ?? "",
                "locationName": self.locationField.text ?? "",
                "radiusMiles": Int(self.radiusSlider.value)
            ]

            // Fields the doc should have; only added if missing
            let emailPrefix = (user.email ?? "").components(separatedBy: "@").first ?? ""
            let defaults: [String: Any] = [
                "email": user.email ?? "",
                "username": emailPrefix,
                "usernameLower": emailPrefix.lowercased(),
                "photoURL": "",
                "shopsVisitedCount": 0,
                "createdAt": FieldValue.serverTimestamp()
            ]
            for (key, value) in defaults where existing[key] == nil {
                data[key] = value
            }

            ref.setData(data, merge: true) { error in
                if let error = error {
                    self.showMessage("Save failed", error.localizedDescription)
                } else {
                    self.navigationController?.popViewController(animated: true)
                }
            }
        }
    }
}
