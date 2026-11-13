package cn.kelance.bojian

import android.app.Activity
import android.os.Handler
import android.os.Looper
import com.alipay.sdk.app.PayTask
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/** Opens the Alipay cashier for a server-signed order string. */
class AlipayBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "cn.kelance.bojian/alipay")
    private val main = Handler(Looper.getMainLooper())
    // PayTask blocks until the cashier closes, so it must not run on the UI thread.
    private val worker = Executors.newSingleThreadExecutor()
    private var busy = false

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "pay") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val order = call.argument<String>("orderString").orEmpty()
            when {
                order.isBlank() -> result.error("INVALID_REQUEST", "支付参数无效", null)
                busy -> result.error("BUSY", "正在等待支付宝支付", null)
                else -> {
                    busy = true
                    worker.execute {
                        val outcome = try {
                            PayTask(activity).payV2(order, true)
                        } catch (error: Exception) {
                            mapOf("resultStatus" to "4000")
                        }
                        main.post {
                            busy = false
                            result.success(mapOf("resultStatus" to outcome["resultStatus"].orEmpty()))
                        }
                    }
                }
            }
        }
    }

    fun close() {
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }
}
