//
//  Components.swift
//  blend-project
//
//  Small reusable views referenced by custom class in Main.storyboard.
//

import UIKit

/// Text field with inner padding and an optional SF Symbol on the left.
class PaddedTextField: UITextField {
    @IBInspectable var leftSymbol: String? {
        didSet { configureLeftSymbol() }
    }

    private let padding: CGFloat = 12
    private let iconSize: CGFloat = 16

    private var textInsets: UIEdgeInsets {
        let left = leftSymbol == nil ? padding : padding + iconSize + 8
        return UIEdgeInsets(top: 0, left: left, bottom: 0, right: padding)
    }

    override func textRect(forBounds bounds: CGRect) -> CGRect {
        bounds.inset(by: textInsets)
    }

    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        bounds.inset(by: textInsets)
    }

    override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        bounds.inset(by: textInsets)
    }

    override func leftViewRect(forBounds bounds: CGRect) -> CGRect {
        CGRect(x: padding, y: (bounds.height - iconSize) / 2, width: iconSize, height: iconSize)
    }

    private func configureLeftSymbol() {
        guard let leftSymbol else {
            leftView = nil
            return
        }
        let imageView = UIImageView(image: UIImage(systemName: leftSymbol))
        imageView.tintColor = .blendMuted
        imageView.contentMode = .scaleAspectFit
        leftView = imageView
        leftViewMode = .always
    }
}

/// Label with padding, used for chips/tags.
class PaddedLabel: UILabel {
    @IBInspectable var horizontalPadding: CGFloat = 8
    @IBInspectable var verticalPadding: CGFloat = 4

    private var insets: UIEdgeInsets {
        UIEdgeInsets(top: verticalPadding, left: horizontalPadding, bottom: verticalPadding, right: horizontalPadding)
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + horizontalPadding * 2, height: size.height + verticalPadding * 2)
    }
}

/// Circular initials avatar.
class AvatarLabel: UILabel {
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
        clipsToBounds = true
    }
}

/// Row of five tappable stars.
class StarRatingView: UIView {
    @IBInspectable var rating: Int = 0 {
        didSet { updateStars() }
    }

    var onChange: ((Int) -> Void)?

    private var buttons: [UIButton] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
        ])

        for value in 1...5 {
            let button = UIButton(type: .system)
            button.tag = value
            button.tintColor = .blendEspresso
            button.setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 20), forImageIn: .normal)
            button.addTarget(self, action: #selector(starTapped(_:)), for: .touchUpInside)
            buttons.append(button)
            stack.addArrangedSubview(button)
        }
        updateStars()
    }

    @objc private func starTapped(_ sender: UIButton) {
        rating = sender.tag
        onChange?(rating)
    }

    private func updateStars() {
        for button in buttons {
            button.setImage(UIImage(systemName: button.tag <= rating ? "star.fill" : "star"), for: .normal)
        }
    }
}

/// Two overlapping circles (the Blend logo / taste-match diagram).
class VennView: UIView {
    @IBInspectable var leftColor: UIColor = .blendMocha { didSet { setNeedsDisplay() } }
    @IBInspectable var rightColor: UIColor = .blendLatte { didSet { setNeedsDisplay() } }
    @IBInspectable var overlapColor: UIColor = .blendEspresso { didSet { setNeedsDisplay() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {
        isOpaque = false
        contentMode = .redraw
    }

    override func draw(_ rect: CGRect) {
        // Circles overlap by 40% of their diameter, so the pair is 1.6 diameters wide.
        let diameter = min(bounds.height, bounds.width / 1.6)
        let originX = bounds.midX - diameter * 0.8
        let leftRect = CGRect(x: originX, y: bounds.midY - diameter / 2, width: diameter, height: diameter)
        let left = UIBezierPath(ovalIn: leftRect)
        let right = UIBezierPath(ovalIn: leftRect.offsetBy(dx: diameter * 0.6, dy: 0))

        leftColor.setFill()
        left.fill()
        rightColor.setFill()
        right.fill()

        UIGraphicsGetCurrentContext()?.saveGState()
        left.addClip()
        overlapColor.setFill()
        right.fill()
        UIGraphicsGetCurrentContext()?.restoreGState()
    }
}

/// Navigation controller with a hidden bar that keeps the swipe-back gesture.
class BlendNavigationController: UINavigationController, UIGestureRecognizerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
