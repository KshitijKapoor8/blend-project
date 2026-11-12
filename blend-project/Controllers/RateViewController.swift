import PhotosUI
import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

class RateViewController: UIViewController, PHPickerViewControllerDelegate {
    // Each rating view and its "n/5" label share a tag (0-4, one per category).
    @IBOutlet var ratingViews: [StarRatingView]!
    @IBOutlet var ratingLabels: [UILabel]!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var scoreLabel: UILabel!
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var commentTextView: UITextView!

    // Set by whichever screen pushes this one; defaults to the demo shop until shop browsing exists.
    var shopId = "epoch-coffee"
    var shopName = "Epoch Coffee"

    // Firestore keys for each category, indexed by tag.
    private let categoryKeys = ["product", "vibe", "service", "seating", "location"]

    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var selectedPhoto: UIImage?
    private var loadedRatingUserID: String?
    private var isLoadingRating = false

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = "Rate \(shopName)"
        commentTextView.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        for ratingView in ratingViews {
            ratingView.onChange = { [weak self] _ in self?.updateScore() }
        }
        updateScore()
        setRatingFieldsEnabled(false)
        loadExistingRating()
    }

    private func loadExistingRating() {
        guard !isLoadingRating, let uid = Auth.auth().currentUser?.uid else { return }
        loadedRatingUserID = nil
        isLoadingRating = true
        setRatingFieldsEnabled(false)

        let ratingRef = db.collection("ratings").document("\(uid)_\(shopId)")
        ratingRef.getDocument(source: .server) { [weak self] snapshot, error in
            guard let self else { return }
            self.isLoadingRating = false
            guard Auth.auth().currentUser?.uid == uid else { return }
            guard let snapshot, error == nil else {
                let alert = UIAlertController(
                    title: "Couldn't load your rating",
                    message: "Try again before making changes to this rating.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                alert.addAction(UIAlertAction(title: "Retry", style: .default) { [weak self] _ in
                    self?.loadExistingRating()
                })
                self.present(alert, animated: true)
                return
            }

            let data = snapshot.data()
            let categories = data?["ratings"] as? [String: Int] ?? [:]
            for ratingView in self.ratingViews where self.categoryKeys.indices.contains(ratingView.tag) {
                let key = self.categoryKeys[ratingView.tag]
                ratingView.rating = categories[key] ?? 0
            }
            self.commentTextView.text = data?["comment"] as? String ?? ""
            self.updateScore()
            self.loadedRatingUserID = uid
            self.setRatingFieldsEnabled(true)
        }
    }

    private func setRatingFieldsEnabled(_ enabled: Bool) {
        for ratingView in ratingViews {
            ratingView.isUserInteractionEnabled = enabled
        }
        commentTextView.isEditable = enabled
    }

    private var averageScore: Double {
        let total = ratingViews.reduce(0) { $0 + $1.rating }
        return Double(total) / Double(ratingViews.count)
    }

    private func updateScore() {
        for ratingView in ratingViews {
            ratingLabels.first { $0.tag == ratingView.tag }?.text = "\(ratingView.rating)/5"
        }
        scoreLabel.text = String(format: "%.1f", averageScore)
    }

    @IBAction func addPhotoTapped(_ sender: Any) {
        var config = PHPickerConfiguration()
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
            guard let image = image as? UIImage else { return }
            DispatchQueue.main.async {
                self?.selectedPhoto = image
                self?.photoImageView.image = image
                self?.photoImageView.isHidden = false
            }
        }
    }

    @IBAction func postRatingTapped(_ sender: UIButton) {
        view.endEditing(true)
        guard let uid = Auth.auth().currentUser?.uid else {
            showMessage("Not signed in", "Please log in and try again.")
            return
        }
        guard loadedRatingUserID == uid else {
            loadExistingRating()
            return
        }

        let storageBucket = Storage.storage().reference().bucket
        print("[RateVC] UID:", uid)
        print("[RateVC] Storage bucket:", storageBucket)

        sender.isEnabled = false
        // One rating per user per shop; posting again updates it.
        let ratingRef = db.collection("ratings").document("\(uid)_\(shopId)")

        let finish: (Error?) -> Void = { [weak self] error in
            sender.isEnabled = true
            if let error = error {
                self?.showMessage("Couldn't post rating", error.localizedDescription)
            } else {
                self?.navigationController?.popViewController(animated: true)
            }
        }

        guard let photo = selectedPhoto, let imageData = photo.jpegData(compressionQuality: 0.5) else {
            saveRating(ratingRef, uid: uid, photoURL: nil, completion: finish)
            return
        }

        print("[RateVC] Preparing to upload rating photo…")
        let photoRef = storage.reference().child("rating_images/\(ratingRef.documentID).jpg")
        print("[RateVC] Upload path:", photoRef.fullPath)
        photoRef.putData(imageData, metadata: nil) { [weak self] _, error in
            guard let self = self else { return }
            if let error = error {
                print("[RateVC] Upload error:", error.localizedDescription)
                return finish(error)
            }
            print("[RateVC] Upload succeeded. Fetching downloadURL…")
            photoRef.downloadURL { url, error in
                if let error = error {
                    // Likely a read permission issue. Log and proceed without photo instead of blocking the rating.
                    print("[RateVC] downloadURL error:", error.localizedDescription)
                    print("[RateVC] Proceeding to save rating without photoURL due to downloadURL failure.")
                    self.saveRating(ratingRef, uid: uid, photoURL: nil, completion: finish)
                    return
                }
                guard let url = url else {
                    print("[RateVC] downloadURL returned nil URL; proceeding without photoURL.")
                    self.saveRating(ratingRef, uid: uid, photoURL: nil, completion: finish)
                    return
                }
                print("[RateVC] Got downloadURL:", url.absoluteString)
                self.saveRating(ratingRef, uid: uid, photoURL: url.absoluteString, completion: finish)
            }
        }
    }

    private func saveRating(_ ratingRef: DocumentReference, uid: String, photoURL: String?, completion: @escaping (Error?) -> Void) {
        var categories: [String: Int] = [:]
        for ratingView in ratingViews where categoryKeys.indices.contains(ratingView.tag) {
            categories[categoryKeys[ratingView.tag]] = ratingView.rating
        }

        var data: [String: Any] = [
            "userId": uid,
            "shopId": shopId,
            "shopName": shopName,
            "ratings": categories,
            "score": (averageScore * 10).rounded() / 10,
            "comment": commentTextView.text.trimmingCharacters(in: .whitespacesAndNewlines),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        // Only overwrite the photo when a new one was picked.
        if let photoURL = photoURL {
            data["photoURL"] = photoURL
        }

        let userRef = db.collection("users").document(uid)
        ratingRef.getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error { return completion(error) }

            let batch = self.db.batch()
            if snapshot?.exists == true {
                batch.setData(data, forDocument: ratingRef, merge: true)
            } else {
                // First rating of this shop counts as a new shop visited.
                data["createdAt"] = FieldValue.serverTimestamp()
                batch.setData(data, forDocument: ratingRef)
                batch.setData(["shopsVisitedCount": FieldValue.increment(Int64(1))], forDocument: userRef, merge: true)
            }
            batch.commit(completion: completion)
        }
    }
}
