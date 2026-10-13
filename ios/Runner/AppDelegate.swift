import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BojianDeviceMetadata") else { return }
    FlutterMethodChannel(name: "cn.kelance.bojian/settings", binaryMessenger: registrar.messenger())
      .setMethodCallHandler { call, result in
        guard call.method == "deviceInfo" else {
          result(FlutterMethodNotImplemented)
          return
        }
        var system = utsname()
        uname(&system)
        let identifier = withUnsafePointer(to: &system.machine) {
          $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        result(["model": "Apple \(UIDevice.current.model) (\(identifier))",
                "os_version": UIDevice.current.systemVersion])
      }
  }
}
