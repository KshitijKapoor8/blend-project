import Foundation

struct FriendProfile {
    let id: String
    let name: String
    let username: String

    static func lookupKey(_ input: String) -> String {
        input.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
            .lowercased()
    }
}

struct FriendConnection {
    enum Status: String { case pending, accepted }

    let id: String
    let sender: String
    let recipient: String
    let status: Status
    let senderProfile: FriendProfile
    let recipientProfile: FriendProfile

    static func pairID(_ first: String, _ second: String) -> String {
        [first, second].sorted().joined(separator: ":")
    }

    func otherUser(than user: String) -> String {
        otherProfile(than: user).id
    }
    func otherProfile(than user: String) -> FriendProfile {
        sender == user ? recipientProfile : senderProfile
    }
}
