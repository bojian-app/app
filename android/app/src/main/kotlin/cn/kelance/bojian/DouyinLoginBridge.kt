package cn.kelance.bojian

import android.app.Activity
import android.os.Handler
import android.os.Looper
import android.util.SparseArray
import com.bytedance.sdk.open.aweme.authorize.model.Authorization
import com.bytedance.sdk.open.aweme.core.OpenHostInfoService
import com.bytedance.sdk.open.aweme.core.OpenLogService
import com.bytedance.sdk.open.aweme.init.DouYinOpenSDKConfig
import com.bytedance.sdk.open.douyin.DouYinOpenApiFactory
import com.bytedance.sdk.open.douyin.api.DouYinOpenApi
import com.bytedance.sdk.open.aweme.adapter.okhttp.OpenNetworkOkHttpServiceImpl
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Created with the engine; the SDK is initialized only for an agreed login request. */
class DouyinLoginBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "cn.kelance.bojian/douyin")
    private val main = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "authorize" -> {
                    val key = call.argument<String>("clientKey").orEmpty()
                    val state = call.argument<String>("state").orEmpty()
                    val redirect = call.argument<String>("redirectUri").orEmpty()
                    if (pending != null) {
                        result.error("BUSY", "正在等待抖音授权", null)
                    } else if (key.isBlank() || state.length != 48 || redirect != CALLBACK) {
                        result.error("INVALID_REQUEST", "抖音授权参数无效", null)
                    } else {
                        try {
                            val config = DouYinOpenSDKConfig.Builder()
                                .context(activity.applicationContext)
                                .clientKey(key)
                                .hostInfoService(HostInfo(activity))
                                .networkService(OpenNetworkOkHttpServiceImpl())
                                .logService(QuietLog())
                                .autoStartTracker(false)
                                .debug(false)
                                .build()
                            DouYinOpenApiFactory.initConfig(config)
                            val api = DouYinOpenApiFactory.create(activity)
                            if (!api.isAppInstalled) {
                                result.error("NOT_INSTALLED", "请先安装抖音", null)
                            } else {
                                val timeout = Runnable { fail(state, "TIMEOUT") }
                                pending = Pending(this, state, result, api, timeout)
                                main.postDelayed(timeout, 120_000)
                                val request = Authorization.Request().apply {
                                    this.state = state
                                    scope = "user_info"
                                    redirectUri = redirect
                                    callerLocalEntry = "cn.kelance.bojian.douyinapi.DouYinEntryActivity"
                                }
                                if (!api.authorize(request)) fail(state, "LAUNCH_FAILED")
                            }
                        } catch (_: Exception) {
                            if (pending?.owner === this) fail(state, "SDK_FAILED")
                            else result.error("SDK_FAILED", "抖音授权失败", null)
                        }
                    }
                }
                "cancel" -> {
                    val state = call.argument<String>("state").orEmpty()
                    if (pending?.owner === this && pending?.state == state) fail(state, "CANCELLED")
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    fun close() {
        channel.setMethodCallHandler(null)
        pending?.takeIf { it.owner === this }?.let { fail(it.state, "CANCELLED") }
    }

    private fun take(state: String): Pending? {
        val request = pending ?: return null
        if (request.owner !== this || request.state != state) return null
        pending = null
        main.removeCallbacks(request.timeout)
        return request
    }

    private fun fail(state: String, code: String) {
        take(state)?.result?.error(code, "抖音授权未完成", null)
    }

    private class Pending(
        val owner: DouyinLoginBridge,
        val state: String,
        val result: MethodChannel.Result,
        val api: DouYinOpenApi,
        val timeout: Runnable,
    )

    private class QuietLog : OpenLogService {
        override fun d(tag: String?, messages: String?) {}
        override fun i(tag: String?, messages: String?) {}
        override fun w(tag: String?, messages: String?) {}
        override fun e(tag: String?, messages: String?) {}
    }

    private class HostInfo(private val activity: Activity) : OpenHostInfoService {
        override fun getDeviceId() = ""
        override fun getInstallId() = ""
        override fun getChannel() = ""
        override fun getAppId() = activity.packageName
        override fun getAppName() = "博简"
        override fun getUpdateVersionCode() = getVersionCode()
        @Suppress("DEPRECATION")
        override fun getVersionCode() = activity.packageManager.getPackageInfo(activity.packageName, 0).versionCode.toString()
        @Suppress("DEPRECATION")
        override fun getVersionName() = activity.packageManager.getPackageInfo(activity.packageName, 0).versionName.orEmpty()
        override fun extraInfo(): SparseArray<String>? = null
    }

    companion object {
        private const val CALLBACK = "https://bojian.kelance.cn/douyin/"
        private var pending: Pending? = null

        fun callbackApi(): DouYinOpenApi? = pending?.api

        fun complete(response: Authorization.Response): Boolean {
            val request = pending ?: return false
            // Ignore an old or unsolicited response without consuming a newer request.
            if (response.state != request.state) return false
            request.owner.take(request.state) ?: return false
            when {
                response.isCancel -> request.result.success(mapOf("state" to request.state, "cancelled" to true))
                !response.isSuccess -> request.result.error(
                    "AUTH_FAILED", "抖音授权失败", mapOf("providerCode" to response.errorCode)
                )
                response.authCode.isNullOrBlank() -> request.result.error("INVALID_CODE", "抖音授权信息无效", null)
                else -> request.result.success(mapOf("state" to response.state, "code" to response.authCode))
            }
            return true
        }
    }
}
