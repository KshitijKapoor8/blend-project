import UIKit

/// Downloads rating photos once and keeps them in memory.
final class FeedImageLoader {
    static let shared = FeedImageLoader()
    private let cache = NSCache<NSURL, UIImage>()

    func image(for url: URL) async -> UIImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: url as NSURL)
        return image
    }
}

/// Shared card chrome: rounded card inset inside a clear cell.
class FeedCardCell: UITableViewCell {
    let card = UIView()
    let avatar = AvatarLabel()
    let headline = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        card.backgroundColor = .blendCard
        card.cornerRadius = 12
        card.borderWidth = 1
        card.borderColor = .blendLine
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6)
        ])

        avatar.font = .preferredFont(forTextStyle: .subheadline).bold
        avatar.textAlignment = .center
        avatar.textColor = .blendInk
        avatar.isAccessibilityElement = false
        avatar.widthAnchor.constraint(equalToConstant: 44).isActive = true
        avatar.heightAnchor.constraint(equalTo: avatar.widthAnchor).isActive = true

        headline.numberOfLines = 0
        headline.adjustsFontForContentSizeCategory = true
        headline.textColor = .blendInk
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Pins a view inside the card with 16pt padding.
    func fill(with content: UIView) {
        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
    }

    /// "**Name** middle **Shop**" with the names in bold.
    static func headline(_ name: String, _ middle: String, _ shop: String) -> NSAttributedString {
        let regular = UIFont.preferredFont(forTextStyle: .body)
        let text = NSMutableAttributedString(string: name, attributes: [.font: regular.bold])
        text.append(NSAttributedString(string: middle, attributes: [.font: regular]))
        text.append(NSAttributedString(string: shop, attributes: [.font: regular.bold]))
        return text
    }
}

/// Full card for a rating with a comment or photo.
final class FeedReviewCell: FeedCardCell {
    static let identifier = "FeedReview"

    private let age = UILabel()
    private let photo = UIImageView()
    private let chips = UIStackView()
    private let comment = UILabel()
    private let likes = UILabel()
    private let replies = UILabel()
    private var photoTask: Task<Void, Never>?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        card.borderColor = .blendLatte
        avatar.backgroundColor = .blendLatte

        age.font = .preferredFont(forTextStyle: .subheadline)
        age.adjustsFontForContentSizeCategory = true
        age.textColor = .blendMuted
        age.setContentHuggingPriority(.required, for: .horizontal)
        age.setContentCompressionResistancePriority(.required, for: .horizontal)

        let header = UIStackView(arrangedSubviews: [avatar, headline, age])
        header.spacing = 12
        header.alignment = .center

        photo.backgroundColor = .blendPlaceholder
        photo.contentMode = .scaleAspectFill
        photo.cornerRadius = 8
        photo.clipsToBounds = true
        photo.isAccessibilityElement = true
        let ratio = photo.heightAnchor.constraint(equalTo: photo.widthAnchor, multiplier: 0.56)
        ratio.priority = .init(999)
        ratio.isActive = true

        chips.spacing = 8
        chips.alignment = .center
        let chipRow = UIStackView(arrangedSubviews: [chips, UIView()])

        comment.font = .preferredFont(forTextStyle: .body)
        comment.adjustsFontForContentSizeCategory = true
        comment.textColor = .blendInk
        comment.numberOfLines = 0

        for label in [likes, replies] {
            label.font = .preferredFont(forTextStyle: .subheadline)
            label.adjustsFontForContentSizeCategory = true
            label.textColor = .blendInk
        }
        let engagement = UIStackView(arrangedSubviews: [likes, replies, UIView()])
        engagement.spacing = 24

        let stack = UIStackView(arrangedSubviews: [header, photo, chipRow, comment, engagement])
        stack.axis = .vertical
        stack.spacing = 14
        stack.setCustomSpacing(18, after: comment)
        fill(with: stack)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        photoTask?.cancel()
        photo.image = nil
    }

    func configure(with item: FeedItem) {
        let rating = item.rating
        avatar.text = item.author.initials
        headline.attributedText = Self.headline(item.author.name, " rated ", rating.shopName)
        age.text = FeedItem.shortAge(item.date)

        chips.arrangedSubviews.forEach { $0.removeFromSuperview() }
        chips.addArrangedSubview(Self.chip(String(format: "%.1f", rating.score), primary: true))
        for category in item.topCategories {
            chips.addArrangedSubview(Self.chip("\(category.name) \(category.value)", primary: false))
        }
        chips.accessibilityLabel = (["Score \(String(format: "%.1f", rating.score))"]
            + item.topCategories.map { "\($0.name) \($0.value)" }).joined(separator: ", ")
        chips.isAccessibilityElement = true

        comment.text = rating.comment
        comment.isHidden = rating.comment.isEmpty

        likes.attributedText = Self.count(rating.likeCount, symbol: "heart")
        likes.accessibilityLabel = rating.likeCount == 1 ? "1 like" : "\(rating.likeCount) likes"
        replies.attributedText = Self.count(rating.commentCount, symbol: "bubble.left")
        replies.accessibilityLabel = rating.commentCount == 1 ? "1 comment" : "\(rating.commentCount) comments"

        photo.isHidden = rating.photoURL == nil
        photo.accessibilityLabel = "\(item.author.name)'s photo of \(rating.shopName)"
        photoTask?.cancel()
        if let url = rating.photoURL {
            photoTask = Task { [weak self] in
                let image = await FeedImageLoader.shared.image(for: url)
                guard !Task.isCancelled else { return }
                self?.photo.image = image
            }
        }
    }

    private static func chip(_ text: String, primary: Bool) -> PaddedLabel {
        let chip = PaddedLabel()
        chip.text = text
        chip.horizontalPadding = 10
        chip.verticalPadding = 6
        let font = UIFont.preferredFont(forTextStyle: .subheadline)
        chip.font = primary ? font.bold : font
        chip.adjustsFontForContentSizeCategory = true
        chip.textColor = primary ? .blendCard : .blendInk
        chip.backgroundColor = primary ? .blendEspresso : .blendHighlight
        chip.cornerRadius = 4
        chip.clipsToBounds = true
        chip.setContentCompressionResistancePriority(.required, for: .horizontal)
        return chip
    }

    private static func count(_ value: Int, symbol: String) -> NSAttributedString {
        let text = NSMutableAttributedString(attachment: NSTextAttachment(image: UIImage(systemName: symbol)!))
        text.append(NSAttributedString(string: "  \(value)"))
        return text
    }
}

/// Compact card: "tried a new spot" or "is back at".
final class FeedActivityCell: FeedCardCell {
    static let identifier = "FeedActivity"

    private let detail = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        avatar.backgroundColor = .blendHighlight

        detail.font = .preferredFont(forTextStyle: .subheadline)
        detail.adjustsFontForContentSizeCategory = true
        detail.textColor = .blendMuted
        detail.numberOfLines = 0

        let text = UIStackView(arrangedSubviews: [headline, detail])
        text.axis = .vertical
        text.spacing = 2
        let row = UIStackView(arrangedSubviews: [avatar, text])
        row.spacing = 12
        row.alignment = .center
        fill(with: row)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with item: FeedItem) {
        let rating = item.rating
        let age = FeedItem.shortAge(item.date)
        avatar.text = item.author.initials
        switch item.kind {
        case .newSpot(let number):
            headline.attributedText = Self.headline(item.author.name, " tried a new spot: ", rating.shopName)
            detail.text = "Shop #\(number) · \(age)"
        case .revisit, .review:
            headline.attributedText = Self.headline(item.author.name, " is back at ", rating.shopName)
            detail.text = "Rated \(String(format: "%.1f", rating.score)) · \(age)"
        }
    }
}

private extension UIFont {
    var bold: UIFont {
        fontDescriptor.withSymbolicTraits(.traitBold).map { UIFont(descriptor: $0, size: 0) } ?? self
    }
}
