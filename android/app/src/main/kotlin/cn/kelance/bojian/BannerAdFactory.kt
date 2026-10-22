package cn.kelance.bojian

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import com.bytedance.sdk.openadsdk.AdSlot
import com.bytedance.sdk.openadsdk.TTAdDislike
import com.bytedance.sdk.openadsdk.TTAdNative
import com.bytedance.sdk.openadsdk.TTAdSdk
import com.bytedance.sdk.openadsdk.TTNativeExpressAd
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class BannerAdFactory(private val activity: Activity, private val messenger: BinaryMessenger) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        BannerAdView(context, activity, messenger, viewId)
}

private class BannerAdView(context: Context, private val activity: Activity,
                         messenger: BinaryMessenger, id: Int) : PlatformView {
    private val frame = FrameLayout(context).apply { visibility = View.INVISIBLE }
    private val channel = MethodChannel(messenger, "cn.kelance.bojian/banner/$id")
    private val handler = Handler(Looper.getMainLooper())
    private var ad: TTNativeExpressAd? = null
    private var requested = false
    private var ended = false
    private var rendered = false
    private val deadline = Runnable { end("failed", "load_timeout") }

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method == "show") {
                if (rendered && !ended) frame.visibility = View.VISIBLE
                result.success(null)
            } else if (call.method != "load") {
                result.notImplemented()
            } else {
                // Flutter installs its callback before asking us to load.
                result.success(null)
                if (!requested && !ended) {
                    requested = true
                    val appId = call.argument<String>("appId").orEmpty()
                    val slotId = call.argument<String>("slotId").orEmpty()
                    if (call.argument<Boolean>("consent") != true || appId.isBlank() || slotId.isBlank()) {
                        end("failed", "not_permitted")
                    } else {
                        handler.postDelayed(deadline, 12000)
                        PangleSdk.ensureReady(activity.applicationContext, appId) { error ->
                            if (!ended) {
                                if (error == null) load(slotId) else end("failed", error)
                            }
                        }
                    }
                }
            }
        }
    }

    private fun load(slotId: String) {
        if (activity.isFinishing || activity.isDestroyed) {
            end("failed", "activity_gone")
            return
        }
        try {
            val slot = AdSlot.Builder().setCodeId(slotId)
                .setExpressViewAcceptedSize(300f, 150f).setAdCount(1).build()
            TTAdSdk.getAdManager().createAdNative(activity).loadBannerExpressAd(
                slot, object : TTAdNative.NativeExpressAdListener {
                    override fun onError(code: Int, message: String?) {
                        handler.post { end("failed", "load_failed:$code") }
                    }
                    override fun onNativeExpressAdLoad(ads: MutableList<TTNativeExpressAd>?) {
                        handler.post {
                            if (ended) {
                                ads?.forEach { destroy(it) }
                            } else {
                                val first = ads?.firstOrNull()
                                ads?.drop(1)?.forEach { destroy(it) }
                                if (first == null) end("failed", "empty_ad")
                                else render(first)
                            }
                        }
                    }
                },
            )
        } catch (error: Exception) {
            end("failed", "load_exception")
        } catch (error: LinkageError) {
            end("failed", "sdk_unavailable")
        }
    }

    private fun render(loaded: TTNativeExpressAd) {
        if (ad != null) {
            if (ad !== loaded) destroy(loaded)
            return
        }
        ad = loaded
        try {
            loaded.setDislikeCallback(activity, object : TTAdDislike.DislikeInteractionCallback {
                override fun onShow() {}
                override fun onCancel() {}
                override fun onSelected(position: Int, value: String?, enforce: Boolean) {
                    handler.post { end("closed", "disliked") }
                }
            })
            loaded.setExpressInteractionListener(object : TTNativeExpressAd.ExpressAdInteractionListener {
                override fun onAdClicked(view: View?, type: Int) {}
                override fun onAdShow(view: View?, type: Int) { Log.i(TAG, "Banner shown") }
                override fun onRenderFail(view: View?, message: String?, code: Int) {
                    handler.post { end("failed", "render_failed:$code") }
                }
                override fun onRenderSuccess(view: View?, width: Float, height: Float) {}
            })
            // GroMore supplies the ready banner view in the load callback;
            // render()/onRenderSuccess belong to the non-mediation CSJ API.
            val creative = loaded.expressAdView
            if (creative == null) {
                end("failed", "empty_view")
                return
            }
            (creative.parent as? ViewGroup)?.removeView(creative)
            frame.addView(creative, FrameLayout.LayoutParams(-1, -1))
            rendered = true
            handler.removeCallbacks(deadline)
            channel.invokeMethod("loaded", null)
        } catch (error: Exception) {
            end("failed", "render_exception")
        } catch (error: LinkageError) {
            end("failed", "sdk_unavailable")
        }
    }

    private fun end(event: String, reason: String) {
        if (ended) return
        release()
        Log.i(TAG, reason)
        channel.invokeMethod(event, reason)
    }

    private fun destroy(value: TTNativeExpressAd) {
        runCatching { value.destroy() }
    }

    private fun release() {
        ended = true
        handler.removeCallbacks(deadline)
        frame.removeAllViews()
        ad?.let { destroy(it) }
        ad = null
    }

    override fun getView(): View = frame
    override fun dispose() {
        release()
        channel.setMethodCallHandler(null)
    }

    companion object { private const val TAG = "BojianBannerAds" }
}
