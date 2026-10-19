import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    let unhandled = Set(URLContexts.filter { !BojianDouyinLogin.handle($0.url) })
    if !unhandled.isEmpty { super.scene(scene, openURLContexts: unhandled) }
  }

  override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    if let url = userActivity.webpageURL, BojianDouyinLogin.handle(url) { return }
    super.scene(scene, continue: userActivity)
  }
}
