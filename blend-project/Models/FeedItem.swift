import Foundation

/// A friend's rating document, as stored in the `ratings` collection.
struct FeedRating {
    let id: String
    let userId: String
    let shopName: String
    let score: Double
    let categories: [String: Int]
    let comment: String
    let photoURL: URL?
    let likeCount: Int
    let commentCount: Int
    let createdAt: Date
    let updatedAt: Date
}

/// One entry in the feed.
struct FeedItem {
    enum Kind: Equatable {
        /// Rating with a comment or photo: shown as a full card.
        case review
        /// First rating of a shop with nothing else to show: "tried a new spot".
        case newSpot(number: Int)
        /// A shop the friend rated before and has rated again: "is back at".
        case revisit
    }

    let rating: FeedRating
    let author: FriendProfile
    let kind: Kind

    var date: Date { rating.updatedAt }

    static let categoryOrder = ["product", "vibe", "service", "seating", "location"]

    /// The three highest-scored categories, for the chips under a review.
    var topCategories: [(name: String, value: Int)] {
        rating.categories
            .filter { $0.value > 0 }
            .sorted {
                if $0.value != $1.value { return $0.value > $1.value }
                let first = Self.categoryOrder.firstIndex(of: $0.key) ?? .max
                let second = Self.categoryOrder.firstIndex(of: $1.key) ?? .max
                return first < second
            }
            .prefix(3)
            .map { (name: $0.key.capitalized, value: $0.value) }
    }

    /// Builds the feed from friends' ratings, newest first.
    static func build(from ratings: [FeedRating], authors: [String: FriendProfile], limit: Int = 50) -> [FeedItem] {
        var shopNumbers: [String: Int] = [:]
        for (_, own) in Dictionary(grouping: ratings, by: \.userId) {
            for (index, rating) in own.sorted(by: { $0.createdAt < $1.createdAt }).enumerated() {
                shopNumbers[rating.id] = index + 1
            }
        }

        return ratings.compactMap { rating -> FeedItem? in
            guard let author = authors[rating.userId] else { return nil }
            let kind: Kind
            if !rating.comment.isEmpty || rating.photoURL != nil {
                kind = .review
            } else if rating.updatedAt.timeIntervalSince(rating.createdAt) > 60 {
                kind = .revisit
            } else {
                kind = .newSpot(number: shopNumbers[rating.id] ?? 1)
            }
            return FeedItem(rating: rating, author: author, kind: kind)
        }
        .sorted { $0.date > $1.date }
        .prefix(limit)
        .map { $0 }
    }

    /// Short age like "Now", "5m", "2h", "Yesterday", "3d" or "Nov 2".
    static func shortAge(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        switch seconds {
        case ..<60: return "Now"
        case ..<3_600: return "\(Int(seconds / 60))m"
        case ..<86_400: return "\(Int(seconds / 3_600))h"
        default:
            if calendar.isDateInYesterday(date) { return "Yesterday" }
            if seconds < 7 * 86_400 { return "\(Int(seconds / 86_400))d" }
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
    }
}

extension FriendProfile {
    var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}
