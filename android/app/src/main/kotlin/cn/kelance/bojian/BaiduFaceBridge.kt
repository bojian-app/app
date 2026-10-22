package cn.kelance.bojian

import android.Manifest
import android.app.Activity
import android.app.Application
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.baidu.idl.face.api.manager.FaceServiceManager
import com.baidu.idl.facelive.api.FaceLiveManager
import com.baidu.idl.facelive.api.entity.ViewBackgroundType
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

/** Cloud credentials remain on the server. This bridge only accepts a scoped verify token. */
class BaiduFaceBridge(private val activity: Activity, messenger: BinaryMessenger) : Application.ActivityLifecycleCallbacks {
    private val channel = MethodChannel(messenger, "cn.kelance.bojian/identity_face")
    private val handler = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null
    private var pendingSession: String? = null
    private var token: String? = null
    private var dark = false
    private var attempt = 0
    private var permissionAttempt: Int? = null
    private val screens = mutableListOf<WeakReference<Activity>>()
    private val timeout = Runnable { finish("TIMEOUT", "人脸核验超时，请重试") }
    private var closed = false

    init {
        activity.application.registerActivityLifecycleCallbacks(this)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "available" -> result.success(mapOf("available" to resourcesAvailable(), "plan_id" to "27030"))
                "verify" -> {
                    if (closed || pending != null || permissionAttempt != null) { result.error("BUSY", "正在处理人脸核验", null); return@setMethodCallHandler }
                    val session = call.argument<String>("session_id")
                    val nativeToken = call.argument<String>("native_token")
                    if (session == null || !session.matches(Regex("[A-Za-z0-9_-]{43}")) || nativeToken.isNullOrBlank() || nativeToken.length > 512 || call.argument<String>("plan_id") != "27030" || call.argument<Int>("match_source") != 0 || call.argument<Boolean>("consent") != true) {
                        result.error("INVALID_REQUEST", "人脸核验参数无效", null); return@setMethodCallHandler
                    }
                    if (!resourcesAvailable()) { result.error("UNAVAILABLE", "人脸核验资源缺失，请更新应用", null); return@setMethodCallHandler }
                    attempt++; pending = result; pendingSession = session; token = nativeToken; dark = call.argument<Boolean>("dark") == true
                    handler.postDelayed(timeout, 240_000)
                    if (ContextCompat.checkSelfPermission(activity, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) initialize()
                    else { permissionAttempt = attempt; ActivityCompat.requestPermissions(activity, arrayOf(Manifest.permission.CAMERA), PERMISSION_REQUEST) }
                }
                "cancel" -> { if (call.argument<String>("session_id") == pendingSession) finish(null, null, true); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }

    private fun resourcesAvailable() = Build.SUPPORTED_ABIS.any { it == "arm64-v8a" || it == "armeabi-v7a" } && listOf("idl-license.face-android", "idl-key.face-android", "local_config.json", "quality_config.json").all { name ->
        runCatching { activity.assets.open(name).use { it.read() != -1 } }.getOrDefault(false)
    }

    fun onPermissionResult(requestCode: Int): Boolean {
        if (requestCode != PERMISSION_REQUEST) return false
        val requestedAttempt = permissionAttempt
        permissionAttempt = null
        if (pending != null && requestedAttempt == attempt) {
            if (ContextCompat.checkSelfPermission(activity, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) initialize()
            else finish("CAMERA_DENIED", "需要允许相机访问才能进行人脸核验")
        }
        return true
    }

    private fun initialize() {
        val session = pendingSession ?: return
        val currentAttempt = attempt
        try {
            // Initialize only after the explicit verification consent and camera grant.
            FaceServiceManager.getInstance().init(activity, "bojian-app-face-face-android", "idl-license.face-android", "idl-key.face-android") { code, _ ->
                activity.runOnUiThread {
                    if (pendingSession != session || pending == null || attempt != currentAttempt) return@runOnUiThread
                    if (code != 1000) { finish("INITIALIZATION_FAILED", "人脸核验初始化失败（$code），请检查授权后重试"); return@runOnUiThread }
                    try {
                        FaceLiveManager.getInstance().faceConfig.apply {
                            setBackgroundType(if (dark) ViewBackgroundType.BLACK else ViewBackgroundType.WHITE)
                            setLivenessLanguage("ZH_CN")
                            setShowLanguageSwitch(false)
                            setOpenRecord(false)
                            setSaveVideoWhenError(false)
                            setShowResultView(false)
                            setIsOpenLog(0)
                            setSaveEventLogs(false)
                        }
                        FaceServiceManager.getInstance().startFaceVerify(activity, hashMapOf<String, Any>("verify_token" to token!!, "match_source" to 0)) { resultCode, _ ->
                            activity.runOnUiThread {
                                if (pendingSession != session || pending == null || attempt != currentAttempt) return@runOnUiThread
                                when (resultCode) {
                                    0 -> finish(null, null, false)
                                    -102 -> finish(null, null, true)
                                    else -> finish("VERIFY_FAILED", "人脸核验未完成（$resultCode），请重试")
                                }
                            }
                        }
                    } catch (_: LinkageError) { finish("UNAVAILABLE", "当前设备不支持人脸核验组件") }
                    catch (_: Exception) { finish("VERIFY_FAILED", "无法打开人脸核验，请重试") }
                }
            }
        } catch (_: LinkageError) { finish("UNAVAILABLE", "当前设备不支持人脸核验组件") }
        catch (_: Exception) { finish("INITIALIZATION_FAILED", "无法初始化人脸核验，请重试") }
    }

    private fun finish(code: String?, message: String?, cancelled: Boolean = false) {
        val result = pending ?: return
        val session = pendingSession
        attempt++; pending = null; pendingSession = null; token = null
        handler.removeCallbacks(timeout)
        screens.mapNotNull { it.get() }.forEach { if (!it.isFinishing) it.finish() }
        screens.clear()
        runCatching { FaceServiceManager.release() }
        if (code != null) result.error(code, message, null)
        else result.success(mapOf("session_id" to session, "cancelled" to cancelled))
    }

    fun close() {
        closed = true
        finish(null, null, true)
        activity.application.unregisterActivityLifecycleCallbacks(this)
        channel.setMethodCallHandler(null)
    }
    override fun onActivityCreated(screen: Activity, state: Bundle?) { if (pending != null && screen.javaClass.name.startsWith("com.baidu.idl.face.")) screens.add(WeakReference(screen)) }
    override fun onActivityStarted(screen: Activity) {}
    override fun onActivityResumed(screen: Activity) {}
    override fun onActivityPaused(screen: Activity) {}
    override fun onActivityStopped(screen: Activity) {}
    override fun onActivitySaveInstanceState(screen: Activity, state: Bundle) {}
    override fun onActivityDestroyed(screen: Activity) { screens.removeAll { it.get() == null || it.get() === screen } }
    private companion object { const val PERMISSION_REQUEST = 27430 }
}
