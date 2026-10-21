//
//  SettingsViewController.swift
//  blend-project
//

import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage // Added
import PhotosUI        // Added

class SettingsViewController: UIViewController, UITextViewDelegate {
    @IBOutlet weak var bioTextView: UITextView!
    @IBOutlet weak var bioCountLabel: UILabel!
    @IBOutlet weak var locationField: UITextField!
    @IBOutlet weak var radiusSlider: UISlider!
    @IBOutlet weak var radiusLabel: UILabel!
    
    // Connect this to the new UIImageView you add over the "AK" box
    @IBOutlet weak var profileImageView: UIImageView!

    private let bioLimit = 150
    private let db = Firestore.firestore()
    private let storage = Storage.storage() // Added

    // On loading set constrants and check user authentication details
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
    
    // Get the attributes from backend and show in settings
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
            
            // Load existing profile image
            if let photoURLString = data["photoURL"] as? String,
               !photoURLString.isEmpty,
               let url = URL(string: photoURLString) {
                URLSession.shared.dataTask(with: url) { data, _, _ in
                    if let data = data, let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            self.profileImageView.image = image
                        }
                    }
                }.resume()
            }
            
            self.updateBioCount()
            self.radiusChanged(self.radiusSlider)
        }
    }

    // Show text
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let current = textView.text as NSString
        return current.replacingCharacters(in: range, with: text).count <= bioLimit
    }

    // If text changed then update the bio
    func textViewDidChange(_ textView: UITextView) {
        updateBioCount()
    }

    // Update bio when triggered on save
    private func updateBioCount() {
        bioCountLabel.text = "\(bioTextView.text.count)/\(bioLimit)"
    }

    // Update radius when triggered on save
    @IBAction func radiusChanged(_ sender: UISlider) {
        sender.value = sender.value.rounded()
        radiusLabel.text = "\(Int(sender.value)) mi"
    }

    // Set location hardcoded for now
    @IBAction func useCurrentLocationTapped(_ sender: UIButton) {
        locationField.text = "Austin, TX"
    }

    // Change the picture when change picture pressed
    @IBAction func changePhotoTapped(_ sender: UIButton) {
        // Open the native photo picker
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    // On save, populate changed attributes in backend
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

            var data: [String: Any] = [
                "bio": self.bioTextView.text ?? "",
                "locationName": self.locationField.text ?? "",
                "radiusMiles": Int(self.radiusSlider.value)
            ]

            let emailPrefix = (user.email ?? "").components(separatedBy: "@").first ?? ""
            let defaults: [String: Any] = [
                "email": user.email ?? "",
                "username": emailPrefix,
                "usernameLower": emailPrefix.lowercased(),
                "photoURL": existing["photoURL"] ?? "", // Preserve existing photoURL
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
    
    // Helper to show alerts
    private func showMessage(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// Photo upload and Firebase details
extension SettingsViewController: PHPickerViewControllerDelegate {
    
    // Photo picker
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        
        provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
            guard let selectedImage = image as? UIImage else { return }
            
            DispatchQueue.main.async {
                self?.profileImageView.image = selectedImage
            }
            
            self?.uploadImageToFirebase(image: selectedImage)
        }
    }
    
    // Upload image back to Firebase storage
    private func uploadImageToFirebase(image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.5),
              let uid = Auth.auth().currentUser?.uid else { return }
        
        let storageRef = storage.reference().child("profile_images/\(uid).jpg")
        
        storageRef.putData(imageData, metadata: nil) { [weak self] metadata, error in
            if let error = error {
                print("Failed to upload image: \(error.localizedDescription)")
                return
            }
            
            storageRef.downloadURL { url, error in
                guard let downloadURL = url else { return }
                self?.updateFirestorePhotoURL(url: downloadURL.absoluteString, uid: uid)
            }
        }
    }
    
    // Update Firestore with the storage URL
    private func updateFirestorePhotoURL(url: String, uid: String) {
        db.collection("users").document(uid).updateData([
            "photoURL": url
        ]) { error in
            if let error = error {
                print("Error updating Firestore: \(error.localizedDescription)")
            } else {
                print("Successfully updated photoURL!")
            }
        }
    }
}
