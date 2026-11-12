// Run from the repo root using the command in README.md. No Firebase access.
import Foundation

@main
struct FeedItemTests {
    static func main() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func rating(_ id: String, by user: String, created: Double, updated: Double? = nil,
                    comment: String = "", photo: String? = nil, categories: [String: Int] = [:]) -> FeedRating {
            FeedRating(id: id, userId: user, shopName: id, score: 4.2, categories: categories, comment: comment,
                       photoURL: photo.flatMap(URL.init(string:)), likedBy: [],
                       createdAt: now.addingTimeInterval(-created), updatedAt: now.addingTimeInterval(-(updated ?? created)))
        }
        let authors = [
            "k": FriendProfile(id: "k", name: "Karnika Choudhury", username: "karnika"),
            "p": FriendProfile(id: "p", name: "Pranav", username: "pranav")
        ]
        let ratings = [
            rating("first", by: "p", created: 9_000),
            rating("second", by: "p", created: 5_000),
            rating("review", by: "k", created: 7_200, comment: "Good beans"),
            rating("photo", by: "k", created: 100, photo: "https://example.com/a.jpg"),
            rating("revisit", by: "k", created: 90_000, updated: 60),
            rating("stranger", by: "x", created: 10)
        ]
        let feed = FeedItem.build(from: ratings, authors: authors)

        assert(feed.map(\.rating.id) == ["revisit", "photo", "second", "review", "first"], "Newest first; skip non-friends")
        assert(feed.first { $0.rating.id == "review" }?.kind == .review, "Comment makes a full card")
        assert(feed.first { $0.rating.id == "photo" }?.kind == .review, "Photo makes a full card")
        assert(feed.first { $0.rating.id == "revisit" }?.kind == .revisit, "Rated again later")
        assert(feed.first { $0.rating.id == "first" }?.kind == .newSpot(number: 1), "Shops numbered oldest first")
        assert(feed.first { $0.rating.id == "second" }?.kind == .newSpot(number: 2))
        assert(FeedItem.build(from: ratings, authors: authors, limit: 2).count == 2)
        assert(FeedItem.build(from: ratings, authors: [:]).isEmpty)

        let chips = FeedItem(rating: rating("c", by: "k", created: 0, categories:
            ["seating": 4, "vibe": 5, "product": 5, "location": 2, "service": 0]), author: authors["k"]!, kind: .review)
        assert(chips.topCategories.map(\.name) == ["Product", "Vibe", "Seating"], "Highest first, ties in Rate order, at most 3")

        let calendar = Calendar(identifier: .gregorian)
        assert(FeedItem.shortAge(now.addingTimeInterval(-30), now: now) == "Now")
        assert(FeedItem.shortAge(now.addingTimeInterval(-5 * 60), now: now) == "5m")
        assert(FeedItem.shortAge(now.addingTimeInterval(-2 * 3_600), now: now) == "2h")
        assert(FeedItem.shortAge(now.addingTimeInterval(60), now: now) == "Now", "Clock skew never goes negative")
        let threeDays = now.addingTimeInterval(-3 * 86_400)
        assert(FeedItem.shortAge(threeDays, now: now, calendar: calendar) == "3d")

        assert(authors["k"]!.initials == "KC")
        assert(authors["p"]!.initials == "P")
        assert(FriendProfile(id: "e", name: " ", username: "e").initials == "?")
        print("All feed checks passed.")
    }
}
