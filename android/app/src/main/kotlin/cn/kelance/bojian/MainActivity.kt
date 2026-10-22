package cn.kelance.bojian

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var baiduFace: BaiduFaceBridge? = null
    private var resumeFiles: ResumeFileBridge? = null
    private var douyinLogin: DouyinLoginBridge? = null
    private var startupAds: StartupAdsBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "cn.kelance.bojian/banner",
            BannerAdFactory(this, flutterEngine.dartExecutor.binaryMessenger),
        )
        startupAds = StartupAdsBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        baiduFace = BaiduFaceBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        resumeFiles = ResumeFileBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        douyinLogin = DouyinLoginBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cn.kelance.bojian/settings")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "deviceInfo" -> {
                            Thread {
                                val model = deviceDisplayName()
                                runOnUiThread {
                                    result.success(mapOf("model" to model, "os_version" to Build.VERSION.RELEASE))
                                }
                            }.start()
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

    private fun deviceDisplayName(): String {
        // Vendors can expose a retail name separately from Build.MODEL.
        for (property in listOf("ro.product.marketname", "ro.vendor.oplus.market.name")) {
            val name = runCatching {
                val process = ProcessBuilder("/system/bin/getprop", property).start()
                try {
                    // Keep the timeout compatible with Android 7 (API 24).
                    val deadline = SystemClock.elapsedRealtime() + 200
                    var exitCode: Int? = null
                    while (SystemClock.elapsedRealtime() < deadline) {
                        exitCode = try { process.exitValue() } catch (_: IllegalThreadStateException) { null }
                        if (exitCode != null) break
                        Thread.sleep(5)
                    }
                    if (exitCode != 0) {
                        ""
                    } else {
                        process.inputStream.bufferedReader().use { it.readText().trim() }
                    }
                } finally {
                    process.inputStream.close()
                    process.errorStream.close()
                    process.outputStream.close()
                    process.destroy()
                }
            }.getOrDefault("")
            if (name.isNotBlank() && !name.equals("unknown", ignoreCase = true)) return name
        }
        val maker = Build.MANUFACTURER.trim()
        val model = Build.MODEL.trim()
        return if (model.startsWith(maker, ignoreCase = true)) model else "$maker $model".trim()
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
        if (startupAds?.active == true) {
            startupAds?.finish("back")
            return true
        }
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

    override fun onResume() {
        super.onResume()
        startupAds?.onResume()
    }

    override fun onPause() {
        startupAds?.onPause()
        super.onPause()
    }

    override fun onDestroy() {
        startupAds?.close()
        startupAds = null
        resumeFiles?.close()
        baiduFace?.close()
        baiduFace = null
        douyinLogin?.close()
        douyinLogin = null
        super.onDestroy()
    }
}
