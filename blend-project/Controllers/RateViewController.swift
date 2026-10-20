//
//  RateViewController.swift
//  blend-project
//

import PhotosUI
import UIKit

class RateViewController: UIViewController, PHPickerViewControllerDelegate {
    // Each rating view and its "n/5" label share a tag (0-4, one per category).
    @IBOutlet var ratingViews: [StarRatingView]!
    @IBOutlet var ratingLabels: [UILabel]!
    @IBOutlet weak var scoreLabel: UILabel!
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var commentTextView: UITextView!

    override func viewDidLoad() {
        super.viewDidLoad()
        commentTextView.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        for ratingView in ratingViews {
            ratingView.onChange = { [weak self] _ in self?.updateScore() }
        }
        updateScore()
    }

    private func updateScore() {
        for ratingView in ratingViews {
            ratingLabels.first { $0.tag == ratingView.tag }?.text = "\(ratingView.rating)/5"
        }
        let total = ratingViews.reduce(0) { $0 + $1.rating }
        scoreLabel.text = String(format: "%.1f", Double(total) / Double(ratingViews.count))
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
                self?.photoImageView.image = image
                self?.photoImageView.isHidden = false
            }
        }
    }

    @IBAction func postRatingTapped(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }
}
