import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        
        let sampleVC = RSKExampleViewController()
        let navController = UINavigationController(rootViewController: sampleVC)
        window?.rootViewController = navController
        
        window?.backgroundColor = UIColor.white
        window?.makeKeyAndVisible()
        return true
    }
}
