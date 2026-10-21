package cn.kelance.pangle_ads

import android.app.Activity
import android.content.Context
import android.graphics.Color
import android.util.Log
import android.widget.FrameLayout
import com.bytedance.sdk.openadsdk.AdSlot
import com.bytedance.sdk.openadsdk.CSJAdError
import com.bytedance.sdk.openadsdk.CSJSplashAd
import com.bytedance.sdk.openadsdk.TTAdConfig
import com.bytedance.sdk.openadsdk.TTAdNative
import com.bytedance.sdk.openadsdk.TTAdSdk
import com.bytedance.sdk.openadsdk.TTCustomController
import com.bytedance.sdk.openadsdk.mediation.init.MediationPrivacyConfig
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * 穿山甲（GroMore）Android 通道。
 *
 * Dart 侧只决定「什么时候可以展示」，SDK 初始化、隐私开关、生命周期都由这里兜住。
 */
class PangleAdsPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "PangleAds"
        const val CHANNEL = "cn.kelance.bojian/pangle_ads"
        const val BANNER_VIEW = "cn.kelance.bojian/pangle_banner"

        /** 开屏拉取超时：超时静默跳过，不能拖慢冷启动。 */
        private const val DEFAULT_SPLASH_TIMEOUT_MS = 3000
    }

    private var channel: MethodChannel? = null
    private var appContext: Context? = null
    private var activity: Activity? = null
    private var splashContainer: FrameLayout? = null
    private var splashAd: CSJSplashAd? = null

    @Volatile
    private var initialized = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
        binding.platformViewRegistry.registerViewFactory(
            BANNER_VIEW,
            object : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
                override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
                    PangleBannerView(context, args as? Map<*, *> ?: emptyMap<String, Any?>())
            },
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        appContext = null
        dismissSplash()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        dismissSplash()
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        dismissSplash()
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> initAd(call, result)
            "isInitialized" -> result.success(initialized && TTAdSdk.isInitSuccess())
            "showSplash" -> showSplash(call, result)
            else -> result.notImplemented()
        }
    }

    private fun initAd(call: MethodCall, result: MethodChannel.Result) {
        val context = appContext
        if (context == null) {
            result.error("NO_CONTEXT", "插件未绑定引擎", null)
            return
        }
        if (initialized && TTAdSdk.isInitSuccess()) {
            result.success(true)
            return
        }
        val appId = call.argument<String>("appId")
        if (appId.isNullOrBlank()) {
            result.error("NO_APP_ID", "缺少穿山甲应用 ID", null)
            return
        }
        val debug = call.argument<Boolean>("debug") ?: false
        val personalized = call.argument<Boolean>("personalized") ?: true

        val config = TTAdConfig.Builder()
            .appId(appId)
            .useMediation(true)
            .debug(debug)
            .supportMultiProcess(false)
            .customController(customController(personalized))
            .build()

        TTAdSdk.init(context, config)
        TTAdSdk.start(object : TTAdSdk.Callback {
            override fun success() {
                initialized = true
                Log.i(TAG, "穿山甲 SDK 初始化成功")
                result.success(true)
            }

            override fun fail(code: Int, message: String?) {
                Log.e(TAG, "穿山甲 SDK 初始化失败 code=$code msg=$message")
                result.success(false)
            }
        })
    }

    /**
     * 隐私合规：默认关闭定位、手机号、外部存储读取，只保留广告下发必需的最小能力。
     */
    private fun customController(personalized: Boolean) = object : TTCustomController() {
        override fun isCanUseLocation() = false
        override fun isCanUsePhoneState() = false
        override fun isCanUseWifiState() = true
        override fun isCanUseWriteExternal() = false
        override fun isCanUseAndroidId() = true

        override fun getMediationPrivacyConfig(): MediationPrivacyConfig =
            object : MediationPrivacyConfig() {
                override fun isLimitPersonalAds() = !personalized
                override fun isProgrammaticRecommend() = !personalized
            }
    }

    private fun showSplash(call: MethodCall, result: MethodChannel.Result) {
        val currentActivity = activity
        val context = appContext
        val slotId = call.argument<String>("slotId")
        if (currentActivity == null || context == null || slotId.isNullOrBlank()) {
            result.success(false)
            return
        }
        if (!initialized || !TTAdSdk.isInitSuccess()) {
            result.success(false)
            return
        }
        // 已有开屏在展示时不再叠加，避免热启动重复出广告。
        if (splashContainer != null) {
            result.success(false)
            return
        }
        val timeout = call.argument<Int>("timeoutMs") ?: DEFAULT_SPLASH_TIMEOUT_MS
        val metrics = currentActivity.resources.displayMetrics

        val adSlot = AdSlot.Builder()
            .setCodeId(slotId)
            .setImageAcceptedSize(metrics.widthPixels, metrics.heightPixels)
            .build()

        TTAdSdk.getAdManager().createAdNative(context).loadSplashAd(
            adSlot,
            object : TTAdNative.CSJSplashAdListener {
                override fun onSplashLoadSuccess(ad: CSJSplashAd?) = Unit

                override fun onSplashLoadFail(error: CSJAdError?) {
                    Log.w(TAG, "开屏拉取失败 code=${error?.code} msg=${error?.msg}")
                    result.success(false)
                }

                override fun onSplashRenderSuccess(ad: CSJSplashAd?) {
                    if (ad == null) {
                        result.success(false)
                        return
                    }
                    renderSplash(currentActivity, ad)
                    result.success(true)
                }

                override fun onSplashRenderFail(ad: CSJSplashAd?, error: CSJAdError?) {
                    Log.w(TAG, "开屏渲染失败 code=${error?.code} msg=${error?.msg}")
                    result.success(false)
                }
            },
            timeout,
        )
    }

    private fun renderSplash(currentActivity: Activity, ad: CSJSplashAd) {
        val root = currentActivity.findViewById<FrameLayout>(android.R.id.content) ?: return
        val adView = ad.splashView ?: return
        val container = FrameLayout(currentActivity).apply {
            setBackgroundColor(Color.WHITE)
            isClickable = true
            addView(adView, FrameLayout.LayoutParams(-1, -1))
        }
        splashAd = ad
        splashContainer = container
        root.addView(container, FrameLayout.LayoutParams(-1, -1))

        ad.setSplashAdListener(object : CSJSplashAd.SplashAdListener {
            override fun onSplashAdShow(ad: CSJSplashAd?) = Unit
            override fun onSplashAdClick(ad: CSJSplashAd?) = Unit
            override fun onSplashAdClose(ad: CSJSplashAd?, closeType: Int) = dismissSplash()
        })
    }

    private fun dismissSplash() {
        val container = splashContainer
        splashContainer = null
        if (container != null) {
            runCatching { (container.parent as? FrameLayout)?.removeView(container) }
            container.removeAllViews()
        }
        splashAd?.let { ad ->
            splashAd = null
            runCatching { ad.mediationManager?.destroy() }
        }
    }
}
