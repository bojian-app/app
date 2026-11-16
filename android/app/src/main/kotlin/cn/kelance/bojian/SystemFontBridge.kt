package cn.kelance.bojian

import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.fonts.Font
import android.graphics.text.TextRunShaper
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Tells Flutter whether the device's default Chinese font has a real bold
 * face. Theme fonts often ship one Regular file that fonts.xml registers for
 * every weight, so bold text is synthesized and its weight jumps mid-line.
 */
class SystemFontBridge(messenger: BinaryMessenger) {
    init {
        MethodChannel(messenger, "cn.kelance.bojian/system_fonts").setMethodCallHandler { call, result ->
            when (call.method) {
                "hasRealCjkBold" -> result.success(
                    try {
                        hasRealCjkBold()
                    } catch (_: Throwable) {
                        true
                    },
                )
                else -> result.notImplemented()
            }
        }
    }

    private fun hasRealCjkBold(): Boolean {
        // Mapping a glyph back to its font file needs API 31. Older devices
        // keep following the system font as before.
        if (Build.VERSION.SDK_INT < 31) return true
        val paint = Paint().apply {
            typeface = Typeface.create(Typeface.DEFAULT, 700, false)
            textSize = 48f
        }
        val text = "国"
        val glyphs = TextRunShaper.shapeTextRun(text, 0, text.length, 0, text.length, 0f, 0f, false, paint)
        if (glyphs.glyphCount() == 0) return true
        return isRealBold(glyphs.getFont(0))
    }

    /** The face is bold by design: a variable wght axis or a bold weight class. */
    private fun isRealBold(font: Font): Boolean {
        val buffer = font.buffer.duplicate().order(ByteOrder.BIG_ENDIAN)
        var base = 0
        if (buffer.getInt(0) == tag("ttcf")) base = buffer.getInt(12 + 4 * font.ttcIndex)
        val tables = buffer.getShort(base + 4).toInt() and 0xffff
        var weightClass = 400
        var variableWeight = false
        for (i in 0 until tables) {
            val record = base + 12 + 16 * i
            val offset = buffer.getInt(record + 8)
            when (buffer.getInt(record)) {
                tag("OS/2") -> weightClass = buffer.getShort(offset + 4).toInt() and 0xffff
                tag("fvar") -> variableWeight = hasBoldWeightAxis(buffer, offset)
            }
        }
        return variableWeight || weightClass >= 600
    }

    private fun hasBoldWeightAxis(buffer: ByteBuffer, fvar: Int): Boolean {
        val axesOffset = buffer.getShort(fvar + 4).toInt() and 0xffff
        val axisCount = buffer.getShort(fvar + 8).toInt() and 0xffff
        val axisSize = buffer.getShort(fvar + 10).toInt() and 0xffff
        for (i in 0 until axisCount) {
            val axis = fvar + axesOffset + axisSize * i
            // Fixed 16.16 maxValue follows the tag, minValue and defaultValue.
            if (buffer.getInt(axis) == tag("wght") && buffer.getInt(axis + 12) / 65536.0 >= 600) return true
        }
        return false
    }

    private fun tag(value: String): Int =
        value.fold(0) { acc, c -> (acc shl 8) or c.code }
}
