//
//  SignUpViewController.swift
//  blend-project
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class SignUpViewController: UIViewController {
    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var usernameField: UITextField!
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var phoneField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var confirmPasswordField: UITextField!

    private let db = Firestore.firestore()

    @IBAction func createAccountTapped(_ sender: UIButton) {
        view.endEditing(true)
        let name = (nameField.text ?? "").trimmingCharacters(in: .whitespaces)
        let username = (usernameField.text ?? "")
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        let email = (emailField.text ?? "").trimmingCharacters(in: .whitespaces)
        let phone = (phoneField.text ?? "").trimmingCharacters(in: .whitespaces)
        let password = passwordField.text ?? ""

        guard !name.isEmpty, !username.isEmpty, !email.isEmpty else {
            showMessage("Missing info", "Name, username, and email are required.")
            return
        }
        guard let usernameKey = UsernameRegistry.key(for: username) else {
            showMessage("Invalid username", "Use up to 30 letters, numbers, or underscores.")
            return
        }
        guard password.count >= 8 else {
            showMessage("Password too short", "Use at least 8 characters.")
            return
        }
        guard password == confirmPasswordField.text else {
            showMessage("Passwords don't match")
            return
        }

        sender.isEnabled = false
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }
            guard let user = result?.user else {
                sender.isEnabled = true
                self.showMessage("Couldn't create account", error?.localizedDescription)
                return
            }

            // Usernames must be unique: check the registry, then claim it alongside the profile.
            let claim = UsernameRegistry.document(usernameKey)
            claim.getDocument { snapshot, error in
                if let error = error {
                    self.rollBack(user, sender, "Couldn't create account", error.localizedDescription)
                    return
                }
                if snapshot?.exists == true {
                    self.rollBack(user, sender, "Username taken", "@\(username) is already in use. Try another.")
                    return
                }

                let profile: [String: Any] = [
                    "name": name,
                    "username": username,
                    "usernameLower": usernameKey,
                    "email": email,
                    "phone": phone,
                    "bio": "",
                    "photoURL": "",
                    "shopsVisitedCount": 0,
                    "createdAt": FieldValue.serverTimestamp()
                ]
                // Both writes succeed or neither does. If someone claimed the name a moment ago, the rules reject it.
                let batch = self.db.batch()
                batch.setData(profile, forDocument: self.db.collection("users").document(user.uid))
                batch.setData(["uid": user.uid], forDocument: claim)
                batch.commit { error in
                    if let error = error {
                        self.rollBack(user, sender, "Couldn't save profile", error.localizedDescription)
                        return
                    }
                    sender.isEnabled = true
                    self.performSegue(withIdentifier: "showMain", sender: sender)
                }
            }
        }
    }

    // Deletes the just-created auth account so a failed sign-up can be retried with the same email
    private func rollBack(_ user: User, _ sender: UIButton, _ title: String, _ message: String) {
        user.delete { _ in
            try? Auth.auth().signOut()
            sender.isEnabled = true
            self.showMessage(title, message)
        }
    }
}
