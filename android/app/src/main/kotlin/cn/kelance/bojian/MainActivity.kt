package cn.kelance.bojian

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowInsetsController
import android.view.animation.DecelerateInterpolator
import android.view.animation.LinearInterpolator
import android.widget.Button
import android.widget.FrameLayout
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformPlugin

class MainActivity : FlutterActivity() {
    private var resumeFiles: ResumeFileBridge? = null
    private var platformPlugin: PlatformPlugin? = null

    override fun providePlatformPlugin(activity: Activity?, flutterEngine: FlutterEngine): PlatformPlugin? =
        super.providePlatformPlugin(activity, flutterEngine).also { platformPlugin = it }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        resumeFiles = ResumeFileBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cn.kelance.bojian/settings")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "deviceInfo" -> {
                            val maker = Build.MANUFACTURER.trim()
                            val model = Build.MODEL.trim()
                            val fullModel = if (model.startsWith(maker, ignoreCase = true)) model else "$maker $model"
                            result.success(mapOf("model" to fullModel, "os_version" to Build.VERSION.RELEASE))
                        }
                        "appInfo" -> {
                            @Suppress("DEPRECATION")
                            val info = packageManager.getPackageInfo(packageName, 0)
                            result.success(mapOf("version" to info.versionName))
                        }
                        "openPermissions", "openNotifications" -> {
                            val destination = if (call.method == "openNotifications" && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            } else {
                                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                    Uri.parse("package:$packageName"))
                            }
                            startActivity(destination)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("SETTINGS_UNAVAILABLE", "无法打开系统设置", null)
                }
            }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        resumeFiles?.handleActivityResult(requestCode, resultCode, data)
    }

    // Flutter delegates an unhandled root-route back action here. Keep the
    // task and engine alive, just like pressing Home, on every Android version.
    override fun popSystemNavigator(): Boolean {
        if (!isTaskRoot) return false
        return moveTaskToBack(false)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        resumeFiles?.handleIntent(intent)
    }
    private var welcome: FrameLayout? = null
    private var scene: StartupView? = null
    private var skipButton: Button? = null
    private var startupAppearanceApplied = false
    private var intro: ValueAnimator? = null
    private var reduceMotion = false
    private var introPresented = false
    private var flutterReady = false
    private var introFinished = false
    private var exiting = false
    private var activityStarted = false
    private val underlyingAccessibility = mutableListOf<Pair<View, Int>>()
    private var originalStatusBarColor: Int? = null
    private var originalNavigationBarColor: Int? = null
    private var originalSystemUiVisibility: Int? = null
    private var originalSystemBarsAppearance: Int? = null
    private var originalNavigationBarContrast: Boolean? = null

    // A TextureView lets the native scene draw while Flutter prepares its first frame.
    // The default SurfaceView defers the whole Android window's first draw.
    override fun getRenderMode() = RenderMode.texture

    override fun getDartEntrypointArgs(): List<String> =
        (super.getDartEntrypointArgs() ?: emptyList()) + "--native-startup"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) resumeFiles?.handleIntent(intent)
        if (Build.VERSION.SDK_INT >= 31) {
            splashScreen.setOnExitAnimationListener { it.remove() }
        }
        reduceMotion = Settings.Global.getFloat(
            contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f
        ) == 0f
        val restoring = savedInstanceState?.getBoolean(STARTUP_PRESENTED, true) == true
        captureSystemBars()
        val content = findViewById<FrameLayout>(android.R.id.content)
        val layer = FrameLayout(this).apply {
            setBackgroundColor(0xFFF7F8FA.toInt())
            isClickable = true
        }
        val illustration = StartupView(this)
        scene = illustration
        welcome = layer
        layer.addView(illustration, FrameLayout.LayoutParams(-1, -1))
        val density = resources.displayMetrics.density
        val skip = Button(this).apply {
            text = "跳过"
            isAllCaps = false
            textSize = 14f
            setTextColor(0xFF697586.toInt())
            background = null
            stateListAnimator = null
            elevation = 0f
            typeface = android.graphics.Typeface.create(typeface, android.graphics.Typeface.NORMAL)
            minWidth = 0
            minimumWidth = 0
            setPadding((8 * density).toInt(), 0, (8 * density).toInt(), 0)
            setOnClickListener {
                isEnabled = false
                finishIntro()
            }
        }
        skipButton = skip
        val skipWidth = maxOf(48f, skip.paint.measureText(skip.text.toString()) / density + 16f)
        val skipLayout = FrameLayout.LayoutParams(
            (skipWidth * density).toInt(), (48 * density).toInt(), Gravity.TOP or Gravity.END
        ).apply {
            topMargin = (12 * density).toInt()
            rightMargin = (16 * density).toInt()
        }
        layer.addView(skip, skipLayout)
        layer.setOnApplyWindowInsetsListener { _, insets ->
            // Paint the scene edge to edge; only the skip action needs safe margins.
            skipLayout.topMargin = insets.systemWindowInsetTop + (12 * density).toInt()
            skipLayout.rightMargin = insets.systemWindowInsetRight + (16 * density).toInt()
            skipLayout.leftMargin = insets.systemWindowInsetLeft + (16 * density).toInt()
            skip.layoutParams = skipLayout
            insets
        }
        for (index in 0 until content.childCount) {
            val child = content.getChildAt(index)
            underlyingAccessibility.add(child to child.importantForAccessibility)
            child.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
        }
        content.addView(layer, FrameLayout.LayoutParams(-1, -1))
        layer.requestApplyInsets()
        // Restoring an activity should never replay the introduction.
        introPresented = true
        updateStartupAppearance(force = true)
        if (reduceMotion || restoring) {
            finishIntro()
        } else {
            val animator = ValueAnimator.ofFloat(0f, 1f).apply {
                duration = 2000
                interpolator = LinearInterpolator()
                addUpdateListener {
                    illustration.progress = it.animatedValue as Float
                }
                addListener(object : AnimatorListenerAdapter() {
                    override fun onAnimationEnd(animation: Animator) {
                        if (intro === animation) finishIntro()
                    }
                })
            }
            intro = animator
            animator.start()
        }
    }

    override fun onFlutterUiDisplayed() {
        super.onFlutterUiDisplayed()
        flutterReady = true
        updateStartupAppearance(force = true)
        dismissWhenReady()
    }

    private fun stopIntro() {
        val animator = intro ?: return
        intro = null
        animator.removeAllUpdateListeners()
        animator.removeAllListeners()
        animator.cancel()
    }

    private fun finishIntro() {
        stopIntro()
        introFinished = true
        scene?.progress = 1f
        updateStartupAppearance()
        skipButton?.apply {
            isEnabled = false
            visibility = View.INVISIBLE
        }
        dismissWhenReady()
    }

    private fun dismissWhenReady() {
        val layer = welcome ?: return
        if (!activityStarted || !flutterReady || !introFinished || exiting) return
        exiting = true
        if (reduceMotion) {
            removeWelcome()
            return
        }
        layer.animate().alpha(0f).setDuration(180)
            .setInterpolator(DecelerateInterpolator())
            .withEndAction { removeWelcome() }.start()
    }

    private fun removeWelcome() {
        stopIntro()
        val layer = welcome
        welcome = null
        scene = null
        skipButton = null
        startupAppearanceApplied = false
        if (layer != null) {
            layer.animate().withEndAction(null).setListener(null).cancel()
            (layer.parent as? FrameLayout)?.removeView(layer)
        }
        for ((child, importance) in underlyingAccessibility) {
            child.importantForAccessibility = importance
        }
        underlyingAccessibility.clear()
        restoreSystemBars()
        // Flutter may have declared the home page's style after the launch snapshot.
        platformPlugin?.updateSystemUiOverlays()
    }

    @Suppress("DEPRECATION")
    private fun captureSystemBars() {
        originalStatusBarColor = window.statusBarColor
        originalNavigationBarColor = window.navigationBarColor
        originalSystemUiVisibility = window.decorView.systemUiVisibility
        if (Build.VERSION.SDK_INT >= 30) {
            originalSystemBarsAppearance = window.insetsController?.systemBarsAppearance
        }
        if (Build.VERSION.SDK_INT >= 29) {
            originalNavigationBarContrast = window.isNavigationBarContrastEnforced
            window.isNavigationBarContrastEnforced = false
        }
    }

    @Suppress("DEPRECATION")
    private fun updateStartupAppearance(force: Boolean = false) {
        val layer = welcome ?: return
        if (startupAppearanceApplied && !force) return
        val color = 0xFFF7F8FA.toInt()
        layer.setBackgroundColor(color)
        window.statusBarColor = color
        window.navigationBarColor = color
        var mask = 0
        if (Build.VERSION.SDK_INT >= 23) mask = mask or View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
        if (Build.VERSION.SDK_INT >= 26) mask = mask or View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
        val flags = window.decorView.systemUiVisibility and mask.inv()
        window.decorView.systemUiVisibility = flags or mask
        if (Build.VERSION.SDK_INT >= 30) {
            val appearanceMask = WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or
                WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS
            window.insetsController?.setSystemBarsAppearance(appearanceMask, appearanceMask)
        }
        startupAppearanceApplied = true
    }

    @Suppress("DEPRECATION")
    private fun restoreSystemBars() {
        originalStatusBarColor?.let { window.statusBarColor = it }
        originalNavigationBarColor?.let { window.navigationBarColor = it }
        originalSystemUiVisibility?.let { original ->
            var mask = 0
            if (Build.VERSION.SDK_INT >= 23) mask = mask or View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
            if (Build.VERSION.SDK_INT >= 26) mask = mask or View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
            window.decorView.systemUiVisibility = (window.decorView.systemUiVisibility and mask.inv()) or (original and mask)
        }
        if (Build.VERSION.SDK_INT >= 30) {
            originalSystemBarsAppearance?.let { original ->
                val mask = WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS or
                    WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS
                window.insetsController?.setSystemBarsAppearance(original and mask, mask)
            }
        }
        if (Build.VERSION.SDK_INT >= 29) {
            originalNavigationBarContrast?.let { window.isNavigationBarContrastEnforced = it }
        }
        originalStatusBarColor = null
        originalNavigationBarColor = null
        originalSystemUiVisibility = null
        originalSystemBarsAppearance = null
        originalNavigationBarContrast = null
    }

    override fun onStart() {
        super.onStart()
        activityStarted = true
        updateStartupAppearance(force = true)
        dismissWhenReady()
    }

    override fun onPause() {
        // A quick trip home can resume before onStop, so settle the intro here too.
        if (intro != null) finishIntro()
        super.onPause()
    }

    override fun onStop() {
        // An interrupted launch resumes at the still landing scene rather than replaying.
        activityStarted = false
        stopIntro()
        introFinished = true
        scene?.progress = 1f
        updateStartupAppearance()
        skipButton?.apply {
            isEnabled = false
            visibility = View.INVISIBLE
        }
        if (flutterReady) removeWelcome()
        super.onStop()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        outState.putBoolean(STARTUP_PRESENTED, introPresented)
        super.onSaveInstanceState(outState)
    }

    override fun onDestroy() {
        activityStarted = false
        resumeFiles?.close()
        removeWelcome()
        platformPlugin = null
        super.onDestroy()
    }

    private companion object {
        const val STARTUP_PRESENTED = "bojian.startup_presented"
    }
}
