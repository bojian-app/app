package cn.kelance.pangle_ads

import android.content.Context
import android.graphics.Color
import android.util.Log
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import android.widget.TextView
import com.bytedance.sdk.openadsdk.AdSlot
import com.bytedance.sdk.openadsdk.TTAdDislike
import com.bytedance.sdk.openadsdk.TTAdNative
import com.bytedance.sdk.openadsdk.TTAdSdk
import com.bytedance.sdk.openadsdk.TTNativeExpressAd
import io.flutter.plugin.platform.PlatformView

/**
 * Banner 广告的 PlatformView。
 *
 * 高度由 Flutter 侧给定（与后台「代码位尺寸」一致，例如 300x150 dp）。
 * [debugLabel] 打开时，广告位里会显示「加载中 / 无填充 code=xxx」，
 * 联调时不用抓 logcat 也能看出是没拉到还是没渲染。
 */
class PangleBannerView(
    private val context: Context,
    creationParams: Map<*, *>,
) : PlatformView, TTAdNative.NativeExpressAdListener,
    TTNativeExpressAd.ExpressAdInteractionListener, TTAdDislike.DislikeInteractionCallback {

    private companion object {
        const val TAG = "PangleBanner"
        const val STATUS_BG = 0xFFF2F4F7.toInt()
        const val STATUS_FG = 0xFF697586.toInt()
    }

    private val container = FrameLayout(context).apply {
        layoutParams = FrameLayout.LayoutParams(-1, -1)
    }
    private val slotId: String = creationParams["slotId"] as? String ?: ""
    private val widthDp: Float = (creationParams["width"] as? Number)?.toFloat() ?: 300f
    private val heightDp: Float = (creationParams["height"] as? Number)?.toFloat() ?: 150f
    private val debugLabel: Boolean = creationParams["debugLabel"] as? Boolean ?: false
    private var bannerAd: TTNativeExpressAd? = null

    init {
        if (debugLabel) showStatus("Banner 加载中…")
        load()
    }

    override fun getView(): View = container

    override fun dispose() {
        release()
    }

    private fun load() {
        if (slotId.isBlank()) {
            Log.w(TAG, "缺少广告位 ID，跳过 Banner 加载")
            showStatus("缺少广告位 ID")
            return
        }
        val adSlot = AdSlot.Builder()
            .setCodeId(slotId)
            .setExpressViewAcceptedSize(widthDp, heightDp)
            .build()
        TTAdSdk.getAdManager().createAdNative(context).loadBannerExpressAd(adSlot, this)
    }

    private fun release() {
        container.removeAllViews()
        bannerAd?.let { ad ->
            bannerAd = null
            runCatching {
                ad.setExpressInteractionListener(null)
                ad.destroy()
            }
        }
    }

    private fun showStatus(text: String) {
        if (!debugLabel) return
        val label = TextView(context).apply {
            this.text = text
            gravity = Gravity.CENTER
            setTextColor(STATUS_FG)
            textSize = 11f
            setBackgroundColor(STATUS_BG)
        }
        container.removeAllViews()
        container.addView(label, FrameLayout.LayoutParams(-1, -1))
    }

    override fun onError(code: Int, message: String?) {
        Log.w(TAG, "Banner 拉取失败 code=$code msg=$message")
        release()
        showStatus("Banner 无填充\ncode=$code")
    }

    override fun onNativeExpressAdLoad(ads: List<TTNativeExpressAd>?) {
        val ad = ads?.firstOrNull()
        if (ad == null) {
            showStatus("Banner 返回空列表")
            return
        }
        Log.i(TAG, "Banner 拉取成功，开始渲染")
        bannerAd = ad
        ad.setExpressInteractionListener(this)
        ad.render()
    }

    override fun onAdClicked(view: View?, type: Int) = Unit

    override fun onAdShow(view: View?, type: Int) = Unit

    override fun onRenderFail(view: View?, message: String?, code: Int) {
        Log.w(TAG, "Banner 渲染失败 code=$code msg=$message")
        release()
        showStatus("Banner 渲染失败\ncode=$code")
    }

    override fun onRenderSuccess(view: View?, width: Float, height: Float) {
        val ad = bannerAd ?: return
        val adView = ad.expressAdView ?: return
        Log.i(TAG, "Banner 渲染成功 ${width}x$height")
        (adView.parent as? FrameLayout)?.removeView(adView)
        container.removeAllViews()
        container.addView(adView, FrameLayout.LayoutParams(-1, -1))
    }

    override fun onShow() = Unit

    override fun onSelected(position: Int, value: String?, dismiss: Boolean) {
        release()
    }

    override fun onCancel() = Unit
}
