//
//  LoginViewController.swift
//  blend-project
//

import UIKit

class LoginViewController: UIViewController {
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var passwordField: UITextField!

    @IBAction func loginTapped(_ sender: UIButton) {
        view.endEditing(true)
        performSegue(withIdentifier: "showMain", sender: sender)
    }

    @IBAction func forgotPasswordTapped(_ sender: UIButton) {
        showMessage("Reset password", "We'll text you a link to reset your password.")
    }

    // Settings › Log out unwinds back here.
    @IBAction func unwindToLogin(_ segue: UIStoryboardSegue) {
        passwordField.text = nil
    }
}
