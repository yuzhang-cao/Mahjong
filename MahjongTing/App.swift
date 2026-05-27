import SwiftUI
import UIKit

final class AppOrientationState {
    static var supportedOrientations: UIInterfaceOrientationMask = .allButUpsideDown

    static func updateSupportedOrientations(_ orientations: UIInterfaceOrientationMask) {
        supportedOrientations = orientations

        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in windowScenes {
            scene.windows.first(where: { $0.isKeyWindow })?
                .rootViewController?
                .setNeedsUpdateOfSupportedInterfaceOrientations()

            scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations))
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppOrientationState.supportedOrientations
    }
}

@main
struct MahjongTingApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}
