import Foundation
import FirebaseFirestore

@MainActor
final class FriendsService {
    struct Overview {
        let discoverable: Bool
        let connections: [FriendConnection]
    }

    private let db = Firestore.firestore()
    private var directory: CollectionReference { db.collection("friendDirectory") }
    private var connections: CollectionReference { db.collection("friendConnections") }

    func overview(for user: String) async throws -> Overview {
        let own = try await directory.document(user).getDocument(source: .server)
        let links = try await connectionsForUser(user)
        return Overview(discoverable: own.exists, connections: links)
    }

    func connectionsForUser(_ user: String) async throws -> [FriendConnection] {
        let snapshot = try await connections.whereFilter(Filter.orFilter([
            Filter.whereField("sender", isEqualTo: user),
            Filter.whereField("recipient", isEqualTo: user)
        ])).getDocuments(source: .server)
        return snapshot.documents.compactMap { doc -> FriendConnection? in
            let data = doc.data()
            guard let sender = data["sender"] as? String,
                  let recipient = data["recipient"] as? String,
                  let senderData = data["senderProfile"] as? [String: Any],
                  let recipientData = data["recipientProfile"] as? [String: Any],
                  let senderProfile = profile(id: sender, data: senderData),
                  let recipientProfile = profile(id: recipient, data: recipientData),
                  let rawStatus = data["status"] as? String,
                  let status = FriendConnection.Status(rawValue: rawStatus) else { return nil }
            return FriendConnection(id: doc.documentID, sender: sender, recipient: recipient, status: status,
                                    senderProfile: senderProfile, recipientProfile: recipientProfile)
        }
    }

    func setDiscoverable(_ enabled: Bool, for user: String) async throws {
        let entry = directory.document(user)
        guard enabled else {
            try await entry.delete()
            return
        }
        let own = try await db.collection("users").document(user).getDocument(source: .server)
        guard let data = own.data(),
              let name = data["name"] as? String,
              let username = data["username"] as? String,
              let key = data["usernameLower"] as? String else { throw FriendsError.profileUnavailable }
        try await entry.setData(["name": name, "username": username, "usernameLower": key])
    }

    func find(username: String, excluding user: String) async throws -> [FriendProfile] {
        let key = FriendProfile.lookupKey(username)
        guard !key.isEmpty else { return [] }
        let snapshot = try await directory.whereField("usernameLower", isEqualTo: key)
            .limit(to: 10).getDocuments(source: .server)
        return snapshot.documents.filter { $0.documentID != user }.compactMap {
            profile(id: $0.documentID, data: $0.data())
        }
    }

    func request(from user: String, to recipient: String) async throws {
        let senderProfile = try await directoryProfile(user)
        let recipientProfile = try await directoryProfile(recipient)
        let id = FriendConnection.pairID(user, recipient)
        try await connections.document(id).setData([
            "sender": user, "recipient": recipient, "status": FriendConnection.Status.pending.rawValue,
            "senderProfile": ["name": senderProfile.name, "username": senderProfile.username],
            "recipientProfile": ["name": recipientProfile.name, "username": recipientProfile.username],
            "createdAt": FieldValue.serverTimestamp()
        ])
    }

    func accept(_ connection: FriendConnection) async throws {
        try await connections.document(connection.id).updateData(["status": FriendConnection.Status.accepted.rawValue])
    }

    func remove(_ connection: FriendConnection) async throws {
        try await connections.document(connection.id).delete()
    }

    private func directoryProfile(_ id: String) async throws -> FriendProfile {
        let snapshot = try await directory.document(id).getDocument(source: .server)
        guard let data = snapshot.data(), let profile = profile(id: id, data: data) else {
            throw FriendsError.discoveryUnavailable
        }
        return profile
    }

    private func profile(id: String, data: [String: Any]) -> FriendProfile? {
        guard let name = data["name"] as? String, let username = data["username"] as? String else { return nil }
        return FriendProfile(id: id, name: name, username: username)
    }
}

enum FriendsError: LocalizedError {
    case profileUnavailable
    case discoveryUnavailable

    var errorDescription: String? {
        switch self {
        case .profileUnavailable: return "Your Blend profile is missing a name or username."
        case .discoveryUnavailable: return "Both members need to enable friend discovery before sending a request."
        }
    }
}
