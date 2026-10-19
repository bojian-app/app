package cn.kelance.bojian.douyinapi

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import cn.kelance.bojian.DouyinLoginBridge
import com.bytedance.sdk.open.aweme.authorize.model.Authorization
import com.bytedance.sdk.open.aweme.common.handler.IApiEventHandler
import com.bytedance.sdk.open.aweme.common.model.BaseReq
import com.bytedance.sdk.open.aweme.common.model.BaseResp

class DouYinEntryActivity : Activity(), IApiEventHandler {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleCallback(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleCallback(intent)
    }

    private fun handleCallback(intent: Intent) {
        try {
            DouyinLoginBridge.callbackApi()?.handleIntent(intent, this)
        } catch (_: Exception) {
            // An unsolicited or malformed Intent must not complete a pending login.
        } finally {
            finish()
        }
    }

    override fun onResp(response: BaseResp) {
        if (response is Authorization.Response && DouyinLoginBridge.complete(response)) {
            // The callback has its own task. Bring the existing Flutter task
            // forward before finishing, instead of returning to Douyin's task.
            packageManager.getLaunchIntentForPackage(packageName)?.let { launch ->
                launch.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                startActivity(launch)
            }
        }
    }
    override fun onReq(request: BaseReq) {}
    override fun onErrorIntent(intent: Intent) {}
}
