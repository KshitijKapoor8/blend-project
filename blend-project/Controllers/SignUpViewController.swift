//
//  SignUpViewController.swift
//  blend-project
//

import UIKit

class SignUpViewController: UIViewController {
    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var usernameField: UITextField!
    @IBOutlet weak var phoneField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var confirmPasswordField: UITextField!

    @IBAction func createAccountTapped(_ sender: UIButton) {
        view.endEditing(true)
        let password = passwordField.text ?? ""
        guard password.count >= 8 else {
            showMessage("Password too short", "Use at least 8 characters.")
            return
        }
        guard password == confirmPasswordField.text else {
            showMessage("Passwords don't match")
            return
        }
        performSegue(withIdentifier: "showMain", sender: sender)
    }
}
