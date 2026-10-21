//
//  SettingsViewController.swift
//  blend-project
//

import UIKit

class SettingsViewController: UIViewController, UITextViewDelegate {
    @IBOutlet weak var bioTextView: UITextView!
    @IBOutlet weak var bioCountLabel: UILabel!
    @IBOutlet weak var locationField: UITextField!
    @IBOutlet weak var radiusSlider: UISlider!
    @IBOutlet weak var radiusLabel: UILabel!

    private let bioLimit = 150

    override func viewDidLoad() {
        super.viewDidLoad()
        bioTextView.delegate = self
        bioTextView.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        updateBioCount()
        radiusChanged(radiusSlider)
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
        navigationController?.popViewController(animated: true)
    }
}
