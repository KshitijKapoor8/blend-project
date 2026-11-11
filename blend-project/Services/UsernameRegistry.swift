import FirebaseFirestore

/// Unique usernames, one `usernames/{lowercased username}` document per account.
enum UsernameRegistry {
    /// Letters, numbers and underscores; also valid as a Firestore document ID.
    static func key(for username: String) -> String? {
        let key = username.lowercased()
        guard (1...30).contains(key.count),
              key.allSatisfy({ ($0.isASCII && ($0.isLetter || $0.isNumber)) || $0 == "_" }) else { return nil }
        return key
    }

    static func document(_ key: String) -> DocumentReference {
        Firestore.firestore().collection("usernames").document(key)
    }

    /// Accounts created before the registry existed: claim their username on login. Failures are ignored.
    static func registerExisting(uid: String) {
        let db = Firestore.firestore()
        db.collection("users").document(uid).getDocument { snapshot, _ in
            guard let stored = snapshot?.data()?["usernameLower"] as? String,
                  let key = key(for: stored) else { return }
            let claim = document(key)
            claim.getDocument { existing, error in
                guard error == nil, existing?.exists == false else { return }
                claim.setData(["uid": uid])
            }
        }
    }
}
