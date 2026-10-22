package cn.kelance.bojian

import android.app.Activity
import android.content.res.Configuration
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import com.bytedance.sdk.openadsdk.AdSlot
import com.bytedance.sdk.openadsdk.CSJAdError
import com.bytedance.sdk.openadsdk.CSJSplashAd
import com.bytedance.sdk.openadsdk.TTAdNative
import com.bytedance.sdk.openadsdk.TTAdSdk
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

/** One bounded cold-start attempt. Late SDK callbacks never reopen the overlay. */
class StartupAdsBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "cn.kelance.bojian/startup_ads")
    private val handler = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null
    private var container: FrameLayout? = null
    private var splash: CSJSplashAd? = null
    private var foreground = false
    private var clicked = false
    private var displayed = false
    private val accessibility = mutableListOf<Pair<View, Int>>()

    val active: Boolean get() = pending != null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "showSplash" -> {
                    val appId = call.argument<String>("appId").orEmpty()
                    val slotId = call.argument<String>("slotId").orEmpty()
                    if (call.argument<Boolean>("consent") != true ||
                        appId.isBlank() || slotId.isBlank()) {
                        result.success("not_permitted")
                    } else {
                        start(appId, slotId, result)
                    }
                }
                "cancel" -> {
                    finish("cancelled")
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun start(appId: String, slotId: String, result: MethodChannel.Result) {
        // 7.8.1.4 ships its complete native libraries only for arm64-v8a.
        if (!Process.is64Bit() || Build.SUPPORTED_64_BIT_ABIS.firstOrNull() != "arm64-v8a") {
            result.success("unsupported_abi")
            return
        }
        if (!foreground || activity.isFinishing || activity.isDestroyed) {
            result.success("background")
            return
        }
        if (!attempted.compareAndSet(false, true)) {
            result.success("already_attempted")
            return
        }
        pending = result
        try {
            val root = activity.findViewById<FrameLayout>(android.R.id.content)
            val layer = FrameLayout(activity).apply {
                val dark = resources.configuration.uiMode and
                    Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES
                setBackgroundColor(if (dark) 0xFF11151C.toInt() else 0xFFF7F8FA.toInt())
                isClickable = true
                // Keep SDK controls inside system bars, including landscape cutouts.
                fitsSystemWindows = true
            }
            for (index in 0 until root.childCount) {
                val view = root.getChildAt(index)
                accessibility.add(view to view.importantForAccessibility)
                view.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
            }
            container = layer
            root.addView(layer, FrameLayout.LayoutParams(-1, -1))
            layer.requestApplyInsets()
            handler.postDelayed({ finish("load_timeout") }, 5000)
            layer.post {
                if (!active) return@post
                try {
                    initialize(appId, slotId)
                } catch (error: Exception) {
                    fail("init_exception", error)
                } catch (error: LinkageError) {
                    fail("sdk_unavailable", error)
                }
            }
        } catch (error: Exception) {
            fail("overlay_failed", error)
        }
    }

    private fun initialize(appId: String, slotId: String) {
        PangleSdk.ensureReady(activity.applicationContext, appId) { error ->
            if (active && foreground) {
                if (error == null) load(slotId) else finish(error)
            }
        }
    }

    private fun load(slotId: String) {
        val layer = container ?: return
        try {
            val metrics = activity.resources.displayMetrics
            // SDK initialization can finish before the newly added overlay is laid out.
            val measuredWidth = layer.width.takeIf { it > 0 } ?: metrics.widthPixels
            val measuredHeight = layer.height.takeIf { it > 0 } ?: metrics.heightPixels
            val width = (measuredWidth - layer.paddingLeft - layer.paddingRight).coerceAtLeast(1)
            val height = (measuredHeight - layer.paddingTop - layer.paddingBottom).coerceAtLeast(1)
            val density = metrics.density
            val slot = AdSlot.Builder()
                .setCodeId(slotId)
                .setImageAcceptedSize(width, height)
                .setExpressViewAcceptedSize(width / density, height / density)
                .build()
            TTAdSdk.getAdManager().createAdNative(activity).loadSplashAd(
                slot,
                object : TTAdNative.CSJSplashAdListener {
                    override fun onSplashLoadSuccess(ad: CSJSplashAd?) {
                        handler.post {
                            if (active && !displayed) splash = ad
                            else if (splash !== ad) destroy(ad)
                        }
                    }
                    override fun onSplashLoadFail(error: CSJAdError?) {
                        handler.post { finish("load_failed:${error?.code}") }
                    }
                    override fun onSplashRenderSuccess(ad: CSJSplashAd?) {
                        handler.post { show(ad) }
                    }
                    override fun onSplashRenderFail(ad: CSJSplashAd?, error: CSJAdError?) {
                        handler.post {
                            if (splash !== ad) destroy(ad)
                            finish("render_failed:${error?.code}")
                        }
                    }
                },
                3000,
            )
        } catch (error: Exception) {
            fail("load_exception", error)
        } catch (error: LinkageError) {
            fail("sdk_unavailable", error)
        }
    }

    private fun show(ad: CSJSplashAd?) {
        if (!active || !foreground || activity.isFinishing || activity.isDestroyed) {
            destroy(ad)
            return
        }
        if (displayed) {
            if (splash !== ad) destroy(ad)
            return
        }
        if (ad == null) {
            finish("empty_ad")
            return
        }
        try {
            val layer = container ?: return
            splash = ad
            ad.setSplashAdListener(object : CSJSplashAd.SplashAdListener {
                override fun onSplashAdShow(ad: CSJSplashAd?) {
                    Log.i(TAG, "Splash shown")
                }
                override fun onSplashAdClick(ad: CSJSplashAd?) { clicked = true }
                override fun onSplashAdClose(ad: CSJSplashAd?, closeType: Int) {
                    handler.post { finish("closed") }
                }
            })
            handler.removeCallbacksAndMessages(null)
            displayed = true
            // Independent safety net if an SDK close callback is lost.
            handler.postDelayed({ finish("display_timeout") }, 12000)
            ad.showSplashView(layer)
        } catch (error: Exception) {
            fail("show_exception", error)
        }
    }

    fun onResume() {
        foreground = true
        if (clicked) finish("returned_from_ad")
    }

    fun onPause() {
        foreground = false
        // Keep a clicked ad alive while its landing page uses its SDK object.
        if (!clicked) finish("background")
    }

    fun finish(reason: String) {
        val result = pending ?: return
        pending = null
        handler.removeCallbacksAndMessages(null)
        container?.let { (it.parent as? ViewGroup)?.removeView(it) }
        container = null
        accessibility.forEach { (view, importance) -> view.importantForAccessibility = importance }
        accessibility.clear()
        destroy(splash)
        splash = null
        Log.i(TAG, reason)
        result.success(reason)
    }

    private fun destroy(ad: CSJSplashAd?) {
        runCatching { ad?.mediationManager?.destroy() }
    }

    private fun fail(reason: String, error: Throwable) {
        Log.w(TAG, reason, error)
        finish(reason)
    }

    fun close() {
        finish("disposed")
        channel.setMethodCallHandler(null)
    }

    companion object {
        private const val TAG = "BojianStartupAds"
        private val attempted = AtomicBoolean(false)
    }
}
