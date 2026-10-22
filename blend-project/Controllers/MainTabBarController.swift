import UIKit

final class MainTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let discover = BlendNavigationController(rootViewController: DiscoverViewController())
        discover.setNavigationBarHidden(true, animated: false)
        discover.tabBarItem = UITabBarItem(title: "Discover", image: UIImage(systemName: "safari"), tag: 0)

        let profile = storyboard!.instantiateViewController(withIdentifier: "Profile")
        let profileNavigation = BlendNavigationController(rootViewController: profile)
        profileNavigation.setNavigationBarHidden(true, animated: false)
        profileNavigation.tabBarItem = UITabBarItem(title: "Profile", image: UIImage(systemName: "person"), tag: 1)
        viewControllers = [discover, profileNavigation]
        tabBar.tintColor = .blendEspresso
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .blendCream
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
    }
}
