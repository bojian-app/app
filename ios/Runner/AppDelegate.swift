import Flutter
import UIKit
import DouyinOpenSDK

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var douyinLogin: BojianDouyinLogin?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BojianDouyinLogin") {
      douyinLogin = BojianDouyinLogin(messenger: registrar.messenger())
    }
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

  override func application(
    _ application: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if BojianDouyinLogin.handle(url) { return true }
    return super.application(application, open: url, options: options)
  }

  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    if let url = userActivity.webpageURL, BojianDouyinLogin.handle(url) { return true }
    return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
  }
}

/// The SDK is initialized only after the agreed, user-initiated authorization call.
final class BojianDouyinLogin: NSObject, DouyinOpenSDKLogDelegate {
  private let channel: FlutterMethodChannel
  private var pending: FlutterResult?
  private var pendingState: String?
  private var timeout: DispatchWorkItem?
  private var request: DouyinOpenSDKAuthRequest?
  private static weak var active: BojianDouyinLogin?
  private static let clientKey = "awll007zjoe179hs"

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "cn.kelance.bojian/douyin", binaryMessenger: messenger)
    super.init()
    Self.active = self
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(FlutterError(code: "UNAVAILABLE", message: "抖音登录不可用", details: nil)) }
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "authorize": self.authorize(args, result: result)
      case "cancel":
        if self.pendingState == args["state"] as? String {
          self.finish(FlutterError(code: "CANCELLED", message: "抖音授权已取消", details: nil))
        }
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  private func authorize(_ args: [String: Any], result: @escaping FlutterResult) {
    guard pending == nil else { return result(FlutterError(code: "BUSY", message: "正在等待抖音授权", details: nil)) }
    guard args["clientKey"] as? String == Self.clientKey,
          let state = args["state"] as? String, state.count == 48,
          args["redirectUri"] as? String == "https://bojian.kelance.cn/douyin/" else {
      return result(FlutterError(code: "INVALID_REQUEST", message: "抖音授权参数无效", details: nil))
    }
    let sdk = DouyinOpenSDKApplicationDelegate.sharedInstance()
    sdk.openAutoTracker = false
    sdk.logDelegate = self
    sdk.application(UIApplication.shared, didFinishLaunchingWithOptions: nil)
    guard sdk.registerAppId(Self.clientKey) else {
      return result(FlutterError(code: "UNAVAILABLE", message: "抖音登录不可用", details: nil))
    }
    guard sdk.isAppInstalled() else {
      return result(FlutterError(code: "NOT_INSTALLED", message: "请先安装抖音", details: nil))
    }
    guard let viewController = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
      .flatMap({ $0.windows }).first(where: { $0.isKeyWindow })?.rootViewController else {
      return result(FlutterError(code: "UNAVAILABLE", message: "无法打开授权页面", details: nil))
    }
    pending = result
    pendingState = state
    let task = DispatchWorkItem { [weak self] in
      guard let self, self.pendingState == state else { return }
      self.finish(FlutterError(code: "TIMEOUT", message: "抖音授权超时", details: nil))
    }
    timeout = task
    DispatchQueue.main.asyncAfter(deadline: .now() + 120, execute: task)
    let request = DouyinOpenSDKAuthRequest()
    request.permissions = NSOrderedSet(array: ["user_info"])
    request.state = state
    self.request = request
    let launched = request.send(viewController) { [weak self] response in
      DispatchQueue.main.async {
        guard let self, self.pendingState == state else { return }
        guard let response else {
          return self.finish(FlutterError(code: "FAILED", message: "抖音授权失败", details: nil))
        }
        if response.errCode.rawValue == -2 {
          return self.finish(["state": state, "cancelled": true])
        }
        guard response.isSucceed else {
          return self.finish(FlutterError(code: "AUTH_FAILED", message: "抖音授权失败", details: ["providerCode": response.errCode.rawValue]))
        }
        guard response.state == state, let code = response.code, !code.isEmpty else {
          return self.finish(FlutterError(code: "STATE_MISMATCH", message: "抖音授权校验失败", details: nil))
        }
        self.finish(["state": state, "code": code])
      }
    }
    if !launched { finish(FlutterError(code: "LAUNCH_FAILED", message: "无法打开抖音", details: nil)) }
  }

  private func finish(_ value: Any?) {
    let result = pending
    pending = nil
    pendingState = nil
    request = nil
    timeout?.cancel()
    timeout = nil
    result?(value)
  }

  static func handle(_ url: URL) -> Bool {
    guard active?.pending != nil else { return false }
    guard url.scheme == clientKey || (url.scheme == "https" && url.host == "bojian.kelance.cn" && url.path.hasPrefix("/douyin/")) else { return false }
    return DouyinOpenSDKApplicationDelegate.sharedInstance().application(nil, open: url, sourceApplication: nil, annotation: nil)
  }

  // Provider authorization codes and tokens must not be forwarded to app logs.
  func onLog(_ logInfo: String) {}
}
