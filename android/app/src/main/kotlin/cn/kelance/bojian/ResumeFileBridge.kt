package cn.kelance.bojian

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

class ResumeFileBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "cn.kelance.bojian/resume_files")
    private val executor = Executors.newSingleThreadExecutor()
    private var pending: Map<String, Any>? = null
    private var saveResult: MethodChannel.Result? = null
    private var saveSource: File? = null
    private val saveRequestCode = 7041

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "takeSharedResume" -> {
                    val file = pending
                    pending = null
                    result.success(file)
                }
                "openWeChat" -> {
                    val intent = activity.packageManager.getLaunchIntentForPackage("com.tencent.mm")
                    if (intent == null) {
                        result.error("WECHAT_MISSING", "未安装微信", null)
                    } else {
                        try {
                            activity.startActivity(intent)
                            result.success(null)
                        } catch (_: Exception) {
                            result.error("WECHAT_UNAVAILABLE", "无法打开微信", null)
                        }
                    }
                }
                "saveExport" -> {
                    if (saveResult != null) { result.error("SAVE_BUSY", "请先完成当前保存", null) }
                    else {
                        val path = call.argument<String>("path") ?: ""
                        val file = File(path)
                        val mime = call.argument<String>("mime") ?: ""
                        val validCache = try {
                            listOf(activity.cacheDir, activity.codeCacheDir).any { file.canonicalPath.startsWith(it.canonicalPath + File.separator) }
                                && file.parentFile?.name?.startsWith("bojian-resume-export-") == true
                        } catch (_: Exception) { false }
                        if (!file.isFile || !validCache || mime !in setOf("application/pdf", "application/vnd.openxmlformats-officedocument.wordprocessingml.document")) {
                            result.error("FILE_INVALID", "导出文件无效", null)
                        } else {
                            saveResult = result; saveSource = file
                            try {
                                val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                    addCategory(Intent.CATEGORY_OPENABLE)
                                    type = mime
                                    putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: file.name)
                                }
                                activity.startActivityForResult(intent, saveRequestCode)
                            } catch (_: Exception) { saveResult = null; saveSource = null; result.error("SAVE_FAILED", "无法打开文件保存窗口", null) }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    @Suppress("DEPRECATION")
    fun handleIntent(intent: Intent?) {
        val uri = when (intent?.action) {
            Intent.ACTION_SEND -> intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                ?: intent.clipData?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.uri
            Intent.ACTION_VIEW -> intent.data
            else -> null
        } ?: return
        if (uri.scheme != "content") return
        executor.execute {
            var output: File? = null
            val payload = try {
                val resolver = activity.contentResolver
                var name: String? = null
                resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
                    if (it.moveToFirst()) name = it.getString(0)
                }
                val filename = name?.substringAfterLast('/')?.substringAfterLast('\\')
                    ?: when (resolver.getType(uri)) {
                        "application/pdf" -> "微信简历.pdf"
                        "application/msword" -> "微信简历.doc"
                        "application/vnd.openxmlformats-officedocument.wordprocessingml.document" -> "微信简历.docx"
                        else -> throw IllegalArgumentException("请选择 PDF、DOC 或 DOCX 简历文件")
                    }
                val extension = filename.substringAfterLast('.', "").lowercase()
                if (extension !in setOf("pdf", "doc", "docx")) {
                    throw IllegalArgumentException("请选择 PDF、DOC 或 DOCX 简历文件")
                }
                val directory = File(activity.cacheDir, "resume-shares").apply { mkdirs() }
                output = File(directory, "${UUID.randomUUID()}.$extension")
                var total = 0L
                resolver.openInputStream(uri)?.use { input ->
                    output!!.outputStream().use { target ->
                        val buffer = ByteArray(64 * 1024)
                        while (true) {
                            if (Thread.currentThread().isInterrupted) throw IllegalStateException()
                            val count = input.read(buffer)
                            if (count == -1) break
                            total += count
                            if (total > 20L * 1024 * 1024) {
                                throw IllegalArgumentException("文件不能超过 20 MB")
                            }
                            target.write(buffer, 0, count)
                        }
                    }
                } ?: throw IllegalStateException()
                if (total == 0L) throw IllegalArgumentException("文件为空，请重新选择")
                mapOf<String, Any>("path" to output!!.absolutePath, "name" to filename, "size" to total)
            } catch (e: Exception) {
                output?.delete()
                mapOf<String, Any>("error" to
                    (if (e is IllegalArgumentException) e.message ?: "文件无效"
                     else "无法读取微信文件，请保存到手机后重新选择"))
            }
            activity.runOnUiThread {
                if (!activity.isDestroyed) {
                    pending = payload
                    channel.invokeMethod("sharedResumeAvailable", null)
                }
            }
        }
    }

    fun handleActivityResult(requestCode: Int, resultCode: Int, intent: Intent?) {
        if (requestCode != saveRequestCode) return
        val result = saveResult ?: return
        val source = saveSource
        saveResult = null; saveSource = null
        val uri = intent?.data
        if (resultCode != Activity.RESULT_OK || uri == null || source == null) { result.success(false); return }
        executor.execute {
            try {
                activity.contentResolver.openOutputStream(uri, "w")?.use { output -> source.inputStream().use { input -> input.copyTo(output) } } ?: throw IllegalStateException()
                activity.runOnUiThread { result.success(true) }
            } catch (_: Exception) { activity.runOnUiThread { result.error("SAVE_FAILED", "文件保存失败，请重试", null) } }
        }
    }

    fun close() {
        saveResult?.error("SAVE_CANCELLED", "保存已取消", null)
        saveResult = null; saveSource = null
        channel.setMethodCallHandler(null)
        executor.shutdownNow()
    }
}
