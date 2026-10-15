package cn.kelance.bojian

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Shader
import android.graphics.Typeface
import android.util.TypedValue
import android.view.View
import kotlin.math.PI
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/** One light composition: the dolphin tidies its paper, without waiting for Dart. */
class StartupView(context: Context) : View(context) {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val bodyPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        shader = LinearGradient(
            -108f, -116f, 120f, 118f,
            0xFF307DFF.toInt(), 0xFF2A5CDA.toInt(), Shader.TileMode.CLAMP
        )
    }
    private val body = Path()
    private val paper = Path().apply {
        moveTo(-46f, -34f)
        lineTo(40f, -34f)
        quadTo(49f, -34f, 49f, -24f)
        lineTo(49f, 61f)
        quadTo(49f, 67f, 41f, 69f)
        cubicTo(7f, 74f, -20f, 61f, -42f, 41f)
        quadTo(-49f, 35f, -49f, 23f)
        lineTo(-53f, -20f)
        quadTo(-55f, -34f, -46f, -34f)
        close()
    }
    private val leftFin = Path().apply {
        moveTo(-60f, 4f)
        cubicTo(-40f, 13f, -23f, 22f, -22f, 33f)
        cubicTo(-22f, 46f, -43f, 47f, -60f, 36f)
        quadTo(-66f, 23f, -60f, 4f)
        close()
    }
    private val rightFin = Path().apply {
        moveTo(44f, -3f)
        cubicTo(65f, 11f, 63f, 32f, 47f, 42f)
        cubicTo(36f, 49f, 24f, 44f, 26f, 32f)
        cubicTo(27f, 21f, 39f, 18f, 44f, -3f)
        close()
    }
    private val winkEye = Path().apply {
        moveTo(16f, -72f)
        quadTo(22f, -68f, 27f, -73f)
    }

    var progress = 0f
        set(value) {
            field = value.coerceIn(0f, 1f)
            invalidate()
        }

    init {
        contentDescription = "博简，把繁杂，变简单。"
        importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_YES
        paint.textAlign = Paint.Align.CENTER
        paint.strokeCap = Paint.Cap.ROUND
        paint.strokeJoin = Paint.Join.ROUND
    }

    private fun phase(start: Float, end: Float) =
        ((progress - start) / (end - start)).coerceIn(0f, 1f)
    private fun smooth(t: Float) = t * t * (3f - 2f * t)
    private fun pulse(start: Float, end: Float): Float {
        val t = phase(start, end)
        return if (t <= 0f || t >= 1f) 0f else sin(PI * t).toFloat()
    }
    private fun wave(start: Float, end: Float): Float {
        val t = phase(start, end)
        return if (t <= 0f || t >= 1f) 0f else sin(2 * PI * t).toFloat()
    }
    private fun fill(color: Int, opacity: Float = 1f) {
        paint.style = Paint.Style.FILL
        paint.color = color
        paint.alpha = (255 * opacity.coerceIn(0f, 1f)).toInt()
    }
    private fun stroke(color: Int, width: Float, opacity: Float = 1f) {
        fill(color, opacity)
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = width
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (width <= 0 || height <= 0) return
        canvas.drawColor(0xFFF7F8FA.toInt())
        val metrics = resources.displayMetrics
        val dp = metrics.density
        val unit = min(width / dp / 360f, height / dp / 440f) * dp
        val artScale = .82f * unit
        val titleSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, 30f, metrics)
        val captionSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, 13f, metrics)
        paint.typeface = Typeface.DEFAULT_BOLD
        paint.textSize = titleSize
        val titleMetrics = paint.fontMetrics
        val titleHeight = max(titleSize * 1.25f, titleMetrics.descent - titleMetrics.ascent)
        val titleWidth = paint.measureText("博简")
        paint.typeface = Typeface.DEFAULT
        paint.textSize = captionSize
        val captionMetrics = paint.fontMetrics
        val captionHeight = max(captionSize * 1.5f, captionMetrics.descent - captionMetrics.ascent)
        val captionWidth = paint.measureText("把繁杂，变简单。")
        val artHeight = 246f * artScale
        val groupHeight = artHeight + 28f * unit + titleHeight + 10f * unit + captionHeight
        val groupWidth = max(240f * artScale, max(titleWidth, captionWidth))
        val fit = min(1f, min(
            (width - 48f * dp).coerceAtLeast(1f) / groupWidth,
            (height - 144f * dp).coerceAtLeast(1f) / groupHeight
        ))
        val firstTop = min(72f * dp, height / 4f)
        val lastTop = max(firstTop, height - firstTop - groupHeight * fit)
        val top = (height * .46f - groupHeight * fit / 2f).coerceIn(firstTop, lastTop)

        canvas.save()
        canvas.translate(width / 2f, top)
        canvas.scale(fit, fit)
        canvas.save()
        canvas.translate(0f, 118f * artScale)
        canvas.scale(artScale, artScale)
        drawDolphin(canvas)
        canvas.restore()

        paint.typeface = Typeface.DEFAULT_BOLD
        paint.textSize = titleSize
        fill(0xFF202C41.toInt())
        val titleTop = artHeight + 28f * unit
        val titleBaseline = titleTop + titleHeight / 2f - (titleMetrics.ascent + titleMetrics.descent) / 2f
        canvas.drawText("博简", 0f, titleBaseline, paint)
        paint.typeface = Typeface.DEFAULT
        paint.textSize = captionSize
        fill(0xFF697586.toInt())
        val captionTop = titleTop + titleHeight + 10f * unit
        val captionBaseline = captionTop + captionHeight / 2f - (captionMetrics.ascent + captionMetrics.descent) / 2f
        canvas.drawText("把繁杂，变简单。", 0f, captionBaseline, paint)
        canvas.restore()
    }

    private fun drawDolphin(canvas: Canvas) {
        val jump = pulse(.10f, .47f)
        val prepare = pulse(0f, .18f)
        val settle = pulse(.47f, .65f)
        val wag = 9f * wave(.04f, .68f)
        val hug = 4f * pulse(.38f, .70f)
        val tidy = smooth(phase(.28f, .60f))
        val wink = pulse(.71f, .80f)
        val lift = 7f * (1f - smooth(phase(0f, .12f))) - 15f * jump + 2f * settle
        val shadowWidth = 130f - 22f * jump
        val shadowHeight = 9f - 2f * jump
        fill(0xFFE6EDF6.toInt())
        canvas.drawOval(-shadowWidth / 2f, 126f - shadowHeight / 2f,
            shadowWidth / 2f, 126f + shadowHeight / 2f, paint)

        canvas.save()
        canvas.translate(-3f * jump, lift)
        canvas.rotate((.035f * wave(.10f, .58f) * 180 / PI).toFloat())
        canvas.scale(1f + .022f * prepare, 1f - .035f * prepare)
        body.reset()
        body.moveTo(-53f, -88f)
        body.cubicTo(-22f, -122f, 25f, -115f, 36f, -86f)
        body.cubicTo(43f, -69f, 57f, -72f, 56f, -63f)
        body.cubicTo(56f, -47f, 46f, -40f, 24f, -36f)
        body.cubicTo(10f, -32f, 10f, -25f, 15f, -11f)
        body.cubicTo(33f, 1f, 48f, 12f, 48f, 27f)
        body.cubicTo(51f, 43f, 40f, 54f, 27f, 54f)
        body.cubicTo(19f, 61f, 27f, 73f, 41f, 69f)
        body.cubicTo(61f, 64f, 77f, 50f, 83f + wag * .35f, 15f)
        body.cubicTo(86f + wag * .55f, 2f, 86f + wag, -12f, 84f + wag, -29f)
        body.cubicTo(84f + wag, -35f, 87f + wag, -40f, 91f + wag, -35f)
        body.cubicTo(126f + wag * .3f, 5f, 114f, 60f, 79f, 92f)
        body.cubicTo(47f, 124f, -34f, 123f, -75f, 88f)
        body.cubicTo(-116f, 58f, -101f, -8f, -64f, -68f)
        body.cubicTo(-80f, -89f, -69f, -106f, -53f, -88f)
        body.close()
        canvas.drawPath(body, bodyPaint)

        fill(0xFFFFFEF1.toInt())
        canvas.drawPath(paper, paint)
        fill(0xFF2867EE.toInt())
        canvas.drawRoundRect(-29f, -14f, 27f, -6f, 4f, 4f, paint)
        for (row in 0..1) {
            val shift = (1f - tidy) * (if (row == 0) -7f else 8f)
            canvas.save()
            canvas.translate(-27f + shift, 10f + row * 14f)
            val turn = (1f - tidy) * (if (row == 0) -.10f else .13f)
            canvas.rotate((turn * 180 / PI).toFloat())
            fill(0xFFB4C8E9.toInt())
            canvas.drawRoundRect(0f, 0f, if (row == 0) 43f else 33f, 3f, 1.5f, 1.5f, paint)
            canvas.restore()
        }
        canvas.save()
        canvas.translate(hug * .6f, -hug * .2f)
        canvas.drawPath(leftFin, bodyPaint)
        canvas.restore()
        canvas.save()
        canvas.translate(-hug * .7f, -hug * .2f)
        canvas.drawPath(rightFin, bodyPaint)
        canvas.restore()
        if (wink > .6f) {
            stroke(Color.WHITE, 2.8f)
            canvas.drawPath(winkEye, paint)
        } else {
            val eyeHeight = 9.5f * (1f - .7f * wink)
            fill(Color.WHITE)
            canvas.drawOval(17.25f, -73f - eyeHeight / 2f, 26.75f, -73f + eyeHeight / 2f, paint)
        }
        canvas.restore()

        val pop = pulse(.15f, .42f)
        if (pop > 0f) {
            stroke(0xFF9EBEF0.toInt(), 2f, pop * .7f)
            for (index in 0..2) {
                val x = -102f + index * 10f
                val y = -90f - index * 12f
                canvas.drawLine(x, y, x - 4f * pop, y - 5f * pop, paint)
            }
        }
    }
}
