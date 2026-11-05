package cn.kelance.bojian

import android.app.Activity
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import com.bytedance.sdk.openadsdk.*
import com.bytedance.sdk.openadsdk.mediation.MediationConstant
import com.bytedance.sdk.openadsdk.mediation.ad.MediationAdSlot
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** User-initiated rewarded video; never grants points on a load/show callback. */
class RewardedAdBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "cn.kelance.bojian/rewarded-ad")
    private val handler = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null
    private var ad: TTRewardVideoAd? = null
    private var eligible = false
    private var shown = false
    private var generation = 0

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "show") { result.notImplemented(); return@setMethodCallHandler }
            if (pending != null) { result.error("AD_BUSY", "广告正在播放", null); return@setMethodCallHandler }
            val appId = call.argument<String>("appId").orEmpty()
            val slotId = call.argument<String>("slotId").orEmpty()
            val userId = call.argument<String>("userId").orEmpty()
            val extra = call.argument<String>("extra").orEmpty()
            if (call.argument<Boolean>("consent") != true || appId.isEmpty() || slotId.isEmpty() || userId.isEmpty() || extra.isEmpty()) {
                result.error("AD_UNAVAILABLE", "广告配置暂不可用", null); return@setMethodCallHandler
            }
            pending = result; eligible = false; shown = false
            val attempt = ++generation
            handler.postDelayed({ if (attempt == generation && !shown) finish("广告加载超时，请稍后重试") }, 30000)
            PangleSdk.ensureReady(activity.applicationContext, appId) { error ->
                if (attempt != generation || pending == null) return@ensureReady
                if (error != null) { finish("广告暂不可用，请稍后重试"); return@ensureReady }
                try {
                    val mediation = MediationAdSlot.Builder()
                        .setRewardName("积分").setRewardAmount(20)
                        .setExtraObject(MediationConstant.KEY_GROMORE_EXTRA, extra).build()
                    val slot = AdSlot.Builder().setCodeId(slotId).setUserID(userId)
                        .setRewardName("积分").setRewardAmount(20).setOrientation(TTAdConstant.VERTICAL)
                        .setMediaExtra(extra).setMediationAdSlot(mediation).build()
                    TTAdSdk.getAdManager().createAdNative(activity).loadRewardVideoAd(slot, object : TTAdNative.RewardVideoAdListener {
                        override fun onError(code: Int, message: String?) { handler.post { if (attempt == generation) finish("暂时没有可观看的广告，请稍后重试") } }
                        override fun onRewardVideoAdLoad(value: TTRewardVideoAd?) { handler.post { if (attempt == generation && pending != null) ad = value } }
                        override fun onRewardVideoCached() { handler.post { show(attempt, ad) } }
                        override fun onRewardVideoCached(value: TTRewardVideoAd?) { handler.post { show(attempt, value) } }
                    })
                } catch (e: Exception) { finish("广告加载失败，请稍后重试") }
            }
        }
    }
    private fun show(attempt: Int, value: TTRewardVideoAd?) {
        if (attempt != generation || pending == null || shown || value == null) return
        if (activity.isFinishing || activity.isDestroyed) { finish("广告页面已关闭"); return }
        ad = value; shown = true
        handler.removeCallbacksAndMessages(null)
        // Bound the native call even if a vendor never delivers a close event.
        handler.postDelayed({ if (attempt == generation) finish("广告观看已超时") }, 20 * 60 * 1000L)
        value.setRewardAdInteractionListener(object : TTRewardVideoAd.RewardAdInteractionListener {
            override fun onAdShow() {}
            override fun onAdVideoBarClick() {}
            override fun onAdClose() { handler.postDelayed({ if (attempt == generation) finish(null) }, 500) }
            override fun onVideoComplete() {}
            override fun onVideoError() { handler.post { if (attempt == generation) finish("广告播放失败") } }
            override fun onRewardVerify(valid: Boolean, amount: Int, name: String?, code: Int, message: String?) {}
            override fun onRewardArrived(valid: Boolean, type: Int, extra: Bundle?) { handler.post { if (attempt == generation) eligible = valid } }
            override fun onSkippedVideo() {}
        })
        try { value.showRewardVideoAd(activity) } catch (e: Exception) { finish("广告展示失败") }
    }
    private fun finish(error: String?) {
        val result = pending ?: return
        pending = null; generation++; handler.removeCallbacksAndMessages(null)
        ad?.mediationManager?.destroy(); ad = null
        if (error == null) result.success(mapOf("eligible" to eligible)) else result.error("AD_UNAVAILABLE", error, null)
    }
    fun close() { finish("广告页面已关闭"); channel.setMethodCallHandler(null) }
}
