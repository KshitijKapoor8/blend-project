import UIKit

final class MainTabBarController: UITabBarController {
    func openFriends() {
        if let friends = viewControllers?.first(where: { $0 is FriendsViewController }) {
            selectedViewController = friends
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let discover = BlendNavigationController(rootViewController: DiscoverViewController())
        discover.setNavigationBarHidden(true, animated: false)
        discover.tabBarItem = UITabBarItem(title: "Discover", image: UIImage(systemName: "safari"), tag: 0)

        let feed = FeedViewController()
        feed.tabBarItem = UITabBarItem(title: "Feed", image: UIImage(systemName: "line.3.horizontal"), tag: 1)

        let friends = FriendsViewController()
        friends.tabBarItem = UITabBarItem(title: "Friends", image: UIImage(systemName: "person.2"), tag: 2)

        let profile = storyboard!.instantiateViewController(withIdentifier: "Profile")
        let profileNavigation = BlendNavigationController(rootViewController: profile)
        profileNavigation.setNavigationBarHidden(true, animated: false)
        profileNavigation.tabBarItem = UITabBarItem(title: "Profile", image: UIImage(systemName: "person"), tag: 3)
        viewControllers = [discover, feed, friends, profileNavigation]
        tabBar.tintColor = .blendEspresso
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .blendCream
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
    }
}
