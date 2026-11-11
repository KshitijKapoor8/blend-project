import Foundation
import FirebaseFirestore

@MainActor
final class FeedService {
    private let db = Firestore.firestore()
    private let friends = FriendsService()

    /// Ratings from the user's accepted friends, newest first.
    func items(for user: String) async throws -> [FeedItem] {
        let connections = try await friends.connectionsForUser(user).filter { $0.status == .accepted }
        var authors: [String: FriendProfile] = [:]
        for connection in connections {
            let profile = connection.otherProfile(than: user)
            authors[profile.id] = profile
        }
        guard !authors.isEmpty else { return [] }

        // Each friend costs one rules lookup, and rules allow at most 10 per query.
        let ids = Array(authors.keys)
        var ratings: [FeedRating] = []
        for start in stride(from: 0, to: ids.count, by: 10) {
            let chunk = Array(ids[start..<min(start + 10, ids.count)])
            let snapshot = try await db.collection("ratings")
                .whereField("userId", in: chunk)
                .getDocuments(source: .server)
            ratings += snapshot.documents.compactMap(rating)
        }
        return FeedItem.build(from: ratings, authors: authors)
    }

    private func rating(_ doc: QueryDocumentSnapshot) -> FeedRating? {
        let data = doc.data()
        guard let userId = data["userId"] as? String,
              let shopName = data["shopName"] as? String,
              let score = (data["score"] as? NSNumber)?.doubleValue,
              let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() else { return nil }
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? updatedAt
        let comment = (data["comment"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return FeedRating(
            id: doc.documentID,
            userId: userId,
            shopName: shopName,
            score: score,
            categories: data["ratings"] as? [String: Int] ?? [:],
            comment: comment,
            photoURL: (data["photoURL"] as? String).flatMap(URL.init(string:)),
            likeCount: (data["likeCount"] as? NSNumber)?.intValue ?? 0,
            commentCount: (data["commentCount"] as? NSNumber)?.intValue ?? 0,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
