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
    private var alipay: AlipayBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "cn.kelance.bojian/banner",
            BannerAdFactory(this, flutterEngine.dartExecutor.binaryMessenger),
        )
        baiduFace = BaiduFaceBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        resumeFiles = ResumeFileBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        douyinLogin = DouyinLoginBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        alipay = AlipayBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        SystemFontBridge(flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cn.kelance.bojian/settings")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "deviceInfo" -> {
                            result.success(mapOf(
                                "model" to Build.MODEL.trim(),
                                "os_version" to Build.VERSION.RELEASE,
                                "stable_id" to stableDeviceId(),
                            ))
                        }
                        "appInfo" -> {
                            @Suppress("DEPRECATION")
                            val info = packageManager.getPackageInfo(packageName, 0)
                            result.success(mapOf(
                                "version" to info.versionName,
                                "build" to info.longVersionCode,
                            ))
                        }
                        "installPermission" -> {
                            val granted = packageManager.canRequestPackageInstalls()
                            if (!granted && call.argument<Boolean>("request") == true) {
                                startActivity(
                                    Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")),
                                )
                            }
                            result.success(granted)
                        }
                        "installApk" -> installApk(
                            call.argument<String>("path") ?: "",
                            call.argument<String>("sha256") ?: "",
                            result,
                        )
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

    /**
     * 校验已下载安装包的摘要后调起系统安装器。未授权“安装未知应用”时先跳转授权页，
     * 返回 "permission"；摘要不符返回 "checksum"；成功调起返回 "started"。
     */
    private fun installApk(path: String, sha256: String, result: MethodChannel.Result) {
        val file = java.io.File(path)
        val updateDir = java.io.File(cacheDir, "update").canonicalFile
        if (!file.isFile || file.canonicalFile.parentFile != updateDir) {
            result.error("INVALID_PACKAGE", "安装包不存在", null)
            return
        }
        if (sha256.isNotEmpty()) {
            val digest = java.security.MessageDigest.getInstance("SHA-256")
            file.inputStream().use { input ->
                val buffer = ByteArray(64 * 1024)
                while (true) {
                    val read = input.read(buffer)
                    if (read < 0) break
                    digest.update(buffer, 0, read)
                }
            }
            val actual = digest.digest().joinToString("") { "%02x".format(it) }
            if (!actual.equals(sha256, ignoreCase = true)) {
                file.delete()
                result.success("checksum")
                return
            }
        }
        if (!packageManager.canRequestPackageInstalls()) {
            startActivity(
                Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")),
            )
            result.success("permission")
            return
        }
        val uri = androidx.core.content.FileProvider.getUriForFile(this, "$packageName.update_provider", file)
        startActivity(
            Intent(Intent.ACTION_VIEW)
                .setDataAndType(uri, "application/vnd.android.package-archive")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        result.success("started")
    }

    /**
     * 卸载重装后保持不变的设备标识：ANDROID_ID 对同一设备、同一签名、同一用户固定，
     * 再混入包名后哈希，不向服务端暴露原始值。取不到或是已知的无效值时返回空串。
     */
    private fun stableDeviceId(): String {
        val androidId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
        if (androidId.isNullOrBlank() || androidId == "9774d56d682e549c") return ""
        val digest = java.security.MessageDigest.getInstance("SHA-256")
            .digest("bojian:$packageName:$androidId".toByteArray())
        return digest.joinToString("") { "%02x".format(it) }.take(48)
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
        alipay?.close()
        alipay = null
        super.onDestroy()
    }
}
