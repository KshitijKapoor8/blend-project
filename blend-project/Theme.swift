//
//  Theme.swift
//  blend-project
//

import UIKit

// Palette lives in Assets.xcassets so the storyboard can use the same named colors.
extension UIColor {
    static let blendCream = UIColor(named: "Cream")!
    static let blendCard = UIColor(named: "Card")!
    static let blendLine = UIColor(named: "Line")!
    static let blendEspresso = UIColor(named: "Espresso")!
    static let blendInk = UIColor(named: "Ink")!
    static let blendMuted = UIColor(named: "Muted")!
    static let blendLatte = UIColor(named: "Latte")!
    static let blendMocha = UIColor(named: "Mocha")!
}

// MARK: - Storyboard-inspectable styling

extension UIView {
    @IBInspectable var cornerRadius: CGFloat {
        get { layer.cornerRadius }
        set {
            layer.cornerRadius = newValue
            layer.cornerCurve = .continuous
        }
    }

    @IBInspectable var borderWidth: CGFloat {
        get { layer.borderWidth }
        set { layer.borderWidth = newValue }
    }

    @IBInspectable var borderColor: UIColor? {
        get { layer.borderColor.map(UIColor.init(cgColor:)) }
        set { layer.borderColor = newValue?.cgColor }
    }
}

// MARK: - Navigation

extension UIViewController {
    @IBAction func backTapped(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    func showMessage(_ title: String, _ message: String? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
