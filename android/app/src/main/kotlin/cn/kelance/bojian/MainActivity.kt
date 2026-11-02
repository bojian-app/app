package cn.kelance.bojian

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var baiduFace: BaiduFaceBridge? = null
    private var resumeFiles: ResumeFileBridge? = null
    private var douyinLogin: DouyinLoginBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "cn.kelance.bojian/banner",
            BannerAdFactory(this, flutterEngine.dartExecutor.binaryMessenger),
        )
        baiduFace = BaiduFaceBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        resumeFiles = ResumeFileBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        douyinLogin = DouyinLoginBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cn.kelance.bojian/settings")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "deviceInfo" -> {
                            result.success(mapOf(
                                "model" to Build.MODEL.trim(),
                                "os_version" to Build.VERSION.RELEASE,
                            ))
                        }
                        "appInfo" -> {
                            @Suppress("DEPRECATION")
                            val info = packageManager.getPackageInfo(packageName, 0)
                            result.success(mapOf("version" to info.versionName))
                        }
                        "openPermissions", "openNotifications" -> {
                            val destination = if (call.method == "openNotifications" && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            } else {
                                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                    Uri.parse("package:$packageName"))
                            }
                            startActivity(destination)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("SETTINGS_UNAVAILABLE", "无法打开系统设置", null)
                }
            }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (baiduFace?.onPermissionResult(requestCode) == true) return
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        resumeFiles?.handleActivityResult(requestCode, resultCode, data)
    }

    // Flutter delegates an unhandled root-route back action here. Keep the
    // task and engine alive, just like pressing Home, on every Android version.
    override fun popSystemNavigator(): Boolean {
        if (!isTaskRoot) return false
        return moveTaskToBack(false)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        resumeFiles?.handleIntent(intent)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) resumeFiles?.handleIntent(intent)
        if (Build.VERSION.SDK_INT >= 31) {
            splashScreen.setOnExitAnimationListener { it.remove() }
        }
    }

    override fun onDestroy() {
        resumeFiles?.close()
        baiduFace?.close()
        baiduFace = null
        douyinLogin?.close()
        douyinLogin = null
        super.onDestroy()
    }
}
