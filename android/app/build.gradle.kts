import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 正式包签名材料放在 android/key.properties（已加入 .gitignore），
// 仓库里只保留配置逻辑，不放密钥。
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// 联调用：-P useDebugSigning=true 时用 debug 证书签名。
// 微信/抖音开放平台目前登记的仍是 debug 证书 MD5，换正式签名后授权会失败，
// 所以联调包需要用它跑通登录；上架包绝不能带这个参数。
val useDebugSigning = project.hasProperty("useDebugSigning")

// 微信联调用：-P useWechatDebugSigning=true 时用带 b1e2c83b 指纹的 debug 证书签名
// （微信/抖音开放平台登记的正是它）。只能联调，不能上架。
val useWechatDebugSigning = project.hasProperty("useWechatDebugSigning")
val wechatDebugKeystore = rootProject.file("wechat-debug.keystore")

android {
    namespace = "cn.kelance.bojian"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        if (useWechatDebugSigning && wechatDebugKeystore.exists()) {
            create("wechatDebug") {
                storeFile = wechatDebugKeystore
                storeType = "jks"
                storePassword = "android"
                keyAlias = "androiddebugkey"
                keyPassword = "android"
            }
        }
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                storeType = keystoreProperties.getProperty("storeType") ?: "jks"
            }
        }
    }

    defaultConfig {
        applicationId = "cn.kelance.bojian"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // 穿山甲 GroMore 要求 minSdk >= 21；保持跟随 Flutter 默认值，但不会低于 21。
        minSdk = maxOf(flutter.minSdkVersion, 21)
        targetSdk = flutter.targetSdkVersion
        // 穿山甲 SDK 方法数较多，显式开启 multidex。
        multiDexEnabled = true
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            when {
                useWechatDebugSigning && wechatDebugKeystore.exists() -> {
                    // 微信/抖音开放平台登记的就是这张 debug 证书，联调登录必须用它。
                    logger.warn("⚠️ 使用微信联调 debug 证书签名，不可上架")
                    signingConfig = signingConfigs.getByName("wechatDebug")
                }
                hasReleaseKeystore && !useDebugSigning -> {
                    signingConfig = signingConfigs.getByName("release")
                }
                else -> {
                    if (useDebugSigning) {
                        logger.warn("⚠️ 使用本机 debug 证书签名（联调包），不可用于上架")
                    } else {
                        logger.warn("⚠️ 未找到 android/key.properties，release 包将使用 debug 签名，不可用于发布")
                    }
                    signingConfig = signingConfigs.getByName("debug")
                }
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 0.2.0.11's polaris dependency is unavailable from the documented repository.
    val douyinSdkVersion = "0.2.0.10"
    implementation("com.bytedance.ies.ugc.aweme:opensdk-china-external:$douyinSdkVersion")
    implementation("com.bytedance.ies.ugc.aweme:opensdk-common:$douyinSdkVersion")
    implementation("com.bytedance.ies.ugc.aweme:openokhttp-china-external:$douyinSdkVersion")
}
