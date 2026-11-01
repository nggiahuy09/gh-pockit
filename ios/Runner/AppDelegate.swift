import Flutter
import UIKit

// Plugins register in `SceneDelegate`, not here: with the UIScene lifecycle there is no window, so no engine, at launch (ADR-0023).
@main
@objc class AppDelegate: FlutterAppDelegate {}

/// iOS 27 will not launch an app without the UIScene lifecycle, and Flutter 3.35 has no implicit-engine hook to register plugins on (ADR-0023).
/// Kept in this file so the Xcode project needs no new source entry. Delete it with the Flutter ≥ 3.38 migration.
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    // `UISceneStoryboardFile` has already loaded Main.storyboard into `window`; its FlutterViewController owns the engine.
    guard let controller = window?.rootViewController as? FlutterViewController else { return }

    GeneratedPluginRegistrant.register(with: controller.engine)
    // FlutterAppDelegate finds its root view through its own `window`, e.g. to forward a status-bar tap.
    (UIApplication.shared.delegate as? FlutterAppDelegate)?.window = window
  }
}
