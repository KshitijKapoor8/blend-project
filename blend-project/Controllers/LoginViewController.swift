//
//  LoginViewController.swift
//  blend-project
//

import UIKit
import FirebaseAuth

class LoginViewController: UIViewController {
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var passwordField: UITextField!

    @IBAction func loginTapped(_ sender: UIButton) {
        view.endEditing(true)
        let email = (emailField.text ?? "").trimmingCharacters(in: .whitespaces)
        let password = passwordField.text ?? ""
        guard !email.isEmpty, !password.isEmpty else {
            showMessage("Missing info", "Enter your email and password.")
            return
        }

        sender.isEnabled = false
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] _, error in
            sender.isEnabled = true
            guard let self = self else { return }
            if let error = error {
                self.showMessage("Couldn't log in", error.localizedDescription)
                return
            }
            self.passwordField.text = nil
            self.performSegue(withIdentifier: "showMain", sender: sender)
        }
    }

    @IBAction func forgotPasswordTapped(_ sender: UIButton) {
        let email = (emailField.text ?? "").trimmingCharacters(in: .whitespaces)
        guard !email.isEmpty else {
            showMessage("Reset password", "Enter your email above, then tap \"Forgot password?\" again.")
            return
        }
        Auth.auth().sendPasswordReset(withEmail: email) { [weak self] error in
            if let error = error {
                self?.showMessage("Reset failed", error.localizedDescription)
            } else {
                self?.showMessage("Reset password", "If an account exists for \(email), we've emailed a reset link.")
            }
        }
    }

    // Settings › Log out unwinds back here.
    @IBAction func unwindToLogin(_ segue: UIStoryboardSegue) {
        try? Auth.auth().signOut()
        passwordField.text = nil
    }
}
