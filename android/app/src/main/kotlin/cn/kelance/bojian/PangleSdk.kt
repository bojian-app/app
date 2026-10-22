package cn.kelance.bojian

import android.content.Context
import android.content.pm.ApplicationInfo
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import com.bytedance.sdk.openadsdk.TTAdConfig
import com.bytedance.sdk.openadsdk.TTAdSdk
import com.bytedance.sdk.openadsdk.TTCustomController
import com.bytedance.sdk.openadsdk.mediation.init.MediationPrivacyConfig

/** One SDK initialization shared by splash and banner; never holds an Activity. */
object PangleSdk {
    private val handler = Handler(Looper.getMainLooper())
    private val waiters = mutableListOf<(String?) -> Unit>()
    private var started = false
    private var complete = false
    private var failure: String? = null

    fun ensureReady(context: Context, appId: String, callback: (String?) -> Unit) {
        check(Looper.myLooper() == Looper.getMainLooper())
        if (!Process.is64Bit() || Build.SUPPORTED_64_BIT_ABIS.firstOrNull() != "arm64-v8a") {
            callback("unsupported_abi")
            return
        }
        if (complete) {
            callback(failure)
            return
        }
        waiters.add(callback)
        if (started) return
        started = true
        handler.postDelayed({ finish("init_timeout") }, 8000)
        try {
            val config = TTAdConfig.Builder()
                .appId(appId)
                .useMediation(true)
                .supportMultiProcess(false)
                .debug(context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0)
                .customController(object : TTCustomController() {
                    override fun isCanUseLocation() = false
                    override fun isCanUsePhoneState() = false
                    override fun isCanUseWifiState() = false
                    override fun isCanUseWriteExternal() = false
                    override fun isCanUseAndroidId() = false
                    override fun isCanUsePermissionRecordAudio() = false
                    override fun alist() = false
                    override fun getMediationPrivacyConfig() = object : MediationPrivacyConfig() {
                        override fun isCanUseOaid() = false
                        override fun isLimitPersonalAds() = true
                        override fun isProgrammaticRecommend() = false
                    }
                }).build()
            TTAdSdk.init(context.applicationContext, config)
            TTAdSdk.start(object : TTAdSdk.Callback {
                override fun success() { handler.post { finish(null) } }
                override fun fail(code: Int, message: String?) {
                    handler.post { finish("init_failed:$code") }
                }
            })
        } catch (error: Exception) {
            finish("init_exception")
        } catch (error: LinkageError) {
            finish("sdk_unavailable")
        }
    }

    private fun finish(error: String?) {
        if (complete) return
        complete = true
        failure = error
        handler.removeCallbacksAndMessages(null)
        val callbacks = waiters.toList()
        waiters.clear()
        callbacks.forEach { it(error) }
    }
}
