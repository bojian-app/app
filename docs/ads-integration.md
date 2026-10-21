# 穿山甲广告接入说明（开屏 + Banner）

关联 Issue：[#38](https://github.com/fahnzjan/bojian-mobile/issues/38)

## 一、后台现状

| 项 | 值 | 说明 |
| --- | --- | --- |
| 应用 | 博简 `5898107` | **应用属性 = 测试**，系统/包名/下载地址均为空 |
| 开屏广告位 | `104711277` | 博简-开屏，含穿山甲竞价、GM ADX 竞价、穿山甲兜底代码位 |
| Banner 广告位 | `104712824` | 博简-Banner，代码位尺寸 300×150 dp |
| 合同 | 已签署 | 税率 6%，需开增值税专票 |
| 结算单 | 无 | 平台要求「资质认证 + 合同 + 正式应用 + 代码位」齐全后按自然月生成 |

> **测试应用只能联调，请求广告不计费。** 正式变现前必须把应用转成正式（应用商店 + 下载地址 + 程序包名，走真实性校验），
> 且 Android / iOS 各需要一条独立应用记录（应用商店选「苹果商店」即视为 iOS）。

## 二、为什么用 GroMore SDK 而不是纯穿山甲 ADN SDK

后台创建的广告位是 GroMore 结构：一个广告位下挂「穿山甲竞价 + GM ADX 竞价 + 穿山甲兜底」。
纯 ADN SDK 只能消费单个代码位，等于把竞价和兜底都丢掉；GroMore SDK 直接传**广告位 ID**，
竞价、兜底、后续新增优量汇/快手/百度都由 SDK 内部完成，客户端不用改。

所以：`appId = 5898107`，`开屏 = 104711277`，`Banner = 104712824`。

## 三、代码结构

```
packages/pangle_ads/               本地插件：只做「Flutter ↔ 原生 SDK」的桥接
  lib/pangle_ads.dart              PangleAds.initialize / showSplash / PangleBannerView
  android/…/PangleAdsPlugin.kt     初始化、开屏浮层、PlatformView 注册
  android/…/PangleBannerView.kt    Banner 的 PlatformView
  android/src/main/res/xml/*.xml   穿山甲/联盟网络需要的 FileProvider 路径与明文网络配置
  ios/Classes/PangleAdsPlugin.m    初始化、开屏、Banner PlatformView（Objective-C）
  ios/pangle_ads.podspec           Ads-CN + Ads-Mediation-CN 依赖

lib/ads/
  ads_config.dart                  应用 ID、广告位 ID、尺寸、开关
  ads_service.dart                 初始化时机、开屏只放一次
  ads_banner.dart                  页面内 Banner（未就绪时不占位）

lib/main.dart                      登录态就绪后初始化广告并展示开屏
lib/points_page.dart               积分页任务卡下方挂 Banner
lib/legal_document.dart            隐私政策补充穿山甲 SDK 条款
```

## 四、平台配置改动

Android：

- `android/build.gradle.kts`：新增 `https://artifact.bytedance.com/repository/pangle` 仓库。
- `android/app/build.gradle.kts`：`minSdk` 不低于 21，开启 `multiDexEnabled`。
- `android/app/src/main/AndroidManifest.xml`：`networkSecurityConfig` 指向 `@xml/pangle_network_config`，并允许 legacy 外部存储（广告落地页下载用）。
- 插件清单声明广告所需权限；定位、手机号、外部存储读取在 SDK 初始化时已通过 `TTCustomController` 关闭。

iOS：

- `ios/Runner/Info.plist`：新增 `NSUserTrackingUsageDescription`。
- 仍需人工补齐：`SKAdNetworkItems`（从穿山甲后台「接入与测试 → SDK → IOS」复制官方列表）、按官方文档确认 ATS 例外。

## 五、上线前必做

1. **转正式应用**：Android 一条（包名 `cn.kelance.bojian`）、iOS 一条（Bundle ID），补应用商店与下载地址，提交真实性校验。
2. **换广告位 ID**：转正式后如果重新建广告位，改 `lib/ads/ads_config.dart` 里的两个常量即可，客户端代码不用动。
3. **回调联调**：用「接入与测试 → SDK 预览工具」验证素材与交互（100% 填充，不用发版）。
4. **隐私合规**：广告 SDK 初始化放在用户同意协议之后（当前实现要求已登录）；首次启动若允许游客进入，需要补一个独立的隐私同意弹窗再初始化。
5. **结算**：结算中心补齐开票信息，次月第 10 个工作日出结算单。

## 六、验证状态（2026-10-21）

已在本机完成：

- `flutter pub get` 通过，本地插件 `pangle_ads` 被正确解析。
- `dart analyze`：**No issues found**（`flutter analyze` 的 LSP 在中文路径下会崩，用 `dart analyze` 替代）。
- `flutter build apk --debug` 通过，产物 `build/app/outputs/flutter-apk/app-debug.apk`。
- 合并后的清单里已包含穿山甲权限、Activity、Provider（`cn.kelance.bojian.TTMultiProvider` 等），证明 SDK 确实进了包。
- **模拟器无法验证广告，两条硬约束互斥**：
  1. `com.pangle.cn:mediation-sdk:7.8.1.4` 的 AAR 里只有 `jni/arm64-v8a/**`（v7a 也只有 `libpangleflipped.so` 半个），
     **没有任何 x86/x86_64 原生库**。x86_64 镜像上启动会 `dlopen failed: libpanglearmor.so` →
     `RuntimeException: Please init Zeus first!` 崩溃。
  2. 换 arm64 镜像也不行：`FATAL | Avd's CPU Architecture 'arm64' is not supported by the QEMU2 emulator on
     x86_64 host. System image must match the host architecture.`

  结论：**穿山甲广告只能在 arm64 真机上验证**，模拟器这条路在我们这台 x86_64 机器上完全走不通。

未完成：

- 真机运行验证（需要一台 arm64 安卓手机）。
- iOS 编译验证（需 macOS + Xcode；`pod install` 还需确认 `Ads-CN` / `Ads-Mediation-CN` 的可用版本）。

## 七、本机构建环境

| 项 | 位置 |
| --- | --- |
| Flutter 3.47.7（Dart 3.13.5） | `D:\dev\flutter`（已加入用户 PATH） |
| Android SDK（platform 34/35/36、build-tools 36、NDK 28.2） | `D:\dev\android-sdk` |
| Gradle 独立缓存 | `D:\dev\gradle-home` |

两个必须注意的坑：

1. **Gradle 全局代理是死的**：`E:\RJ\DmRJ\Gradle\gradle.properties` 里写着 `127.0.0.1:7890`，Clash 未启动时所有依赖下载都会
   `Connection refused`。构建时用 `GRADLE_USER_HOME=D:\dev\gradle-home` 绕开，或在启动 Clash 后再构建。
2. **工程路径含中文**，AGP 9 默认拒绝，已在 `android/gradle.properties` 打开 `android.overridePathCheck=true`；
   同时因依赖缓存与工程跨盘（C:/F:），关掉了 Kotlin 增量编译（`kotlin.incremental=false`）。
3. **release 的 AOT 编译读不了中文路径**（`gen_snapshot` 报 `Unable to read file: ...\app.dill`）。
   debug（JIT）不受影响，release 必须从 ASCII 路径构建，用目录联接即可，不用搬工程：

```bat
mklink /J D:\dev\bojian-mobile "F:\Dm\companyProject\自己\bojian-mobile"
cd /d D:\dev\bojian-mobile
```

## 八、正式包出包

签名材料（不入库，`.gitignore` 已忽略）：

| 项 | 值 |
| --- | --- |
| keystore | `android/bojian-release.jks`（RSA 2048，有效期 30 年） |
| alias | `bojian` |
| store / key 密码 | `Bojian@Ads2026Ks7mQ` |
| 证书 MD5 | `041be49bd42cc4b8e8ae534eee604765` |
| 证书 SHA-256 | `f8fff5475bead3e9d9b183921f66ee6c032652aa35b3fbc98a13c911eff78355` |

> ⚠️ **立刻离线备份** `bojian-release.jks` 与密码。这份文件丢了，已上架的应用就再也无法更新。
> ⚠️ 上架前必须把**微信开放平台**与**抖音开放平台**的「应用签名」改成上面的 MD5，
> 否则换签名后微信/抖音登录会直接失败（抖音错误码 `10017`）。

出包命令：

```bat
cd /d D:\dev\bojian-mobile
set GRADLE_USER_HOME=D:\dev\gradle-home
flutter build apk --release --split-per-abi -P force-version-code-ignoring-abi=true
```

产物（versionCode 1 / versionName 1.0.0）：

- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`（52.8MB，主流机型）
- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`（45.2MB，老机型）
- `build/app/outputs/flutter-apk/app-x86_64-release.apk`（51.0MB，模拟器/部分平板）

混淆策略：正式包当前 `isMinifyEnabled = false`。穿山甲与抖音 SDK 依赖大量反射与动态加载，
在广告/登录真机回归通过前不开启 R8；后续如需开启，必须先补 keep 规则并回归。

## 十、证书对照表（务必只认一个）

| 来源 | 文件 | 密钥类型 | 证书 MD5 | 说明 |
| --- | --- | --- | --- | --- |
| 正式签名（默认） | `android/bojian-release.jks` | RSA 2048 | `041be49bd42cc4b8e8ae534eee604765` | 主体 `CN=Zhuhai Kelance Network Technology Co Ltd`，30 年，**推荐作为上架证书** |
| 项目根目录 p12 | `bojian-release.p12` | **EC P-256** | `0144270d4e173e5cabf49234e844143e` | 主体 `CN=bojian`（其余字段为空），自签名；密码 `Fzj!2024!`，alias `bojian` |
| 本机 debug | `%USERPROFILE%\.android\debug.keystore` | RSA 2048 | `9d09337c5d06e426ed924cb7dd94ffc6` | `CN=Android Debug`，只能联调 |
| 微信/抖音联调证书 | `android/wechat-debug.keystore` | RSA 2048 | `b1e2c83b09bcdea35a00ce4bd15bae42` | `CN=Android Debug`，SHA-1 `098531cdd8a1a7f903c6617f8b534675473d91cf`，alias `androiddebugkey`，密码 `android`；**微信/抖音后台登记的就是它**，只能联调 |
| 微信/抖音后台历史登记值 | — | — | `b1e2c83b09bcdea35a00ce4bd15bae42` | 来自另一台机器的 debug 证书，本机原先那份是 `9d09337c`，已把对应 keystore 放入 `android/wechat-debug.keystore` |

**微信/抖音登录能否通过，只取决于「后台登记的 MD5」是否等于「安装包证书的 MD5」**，与文件是否齐全无关。
选定一个证书后，把它的 MD5 写进微信开放平台 → 开发信息 → 应用签名，以及抖音开放平台的应用签名，然后一直用它出包。

注意：`minSdk = 24`，所以 EC 证书（p12）可以正常用 v2/v3 签名；若将来把 minSdk 降到 23 及以下，
EC 证书会因为无法生成 v1（JAR）签名而导致安装失败。

切换签名只需改 `android/key.properties`：

```properties
storeFile=../bojian-release.jks   # 或 ../../bojian-release.p12
storeType=jks                      # p12 用 PKCS12
keyAlias=bojian
```

联调时不用改文件，直接加构建参数：

```bat
:: 用微信/抖音后台登记的 debug 证书签名（b1e2c83b），登录能过，但不能上架
flutter build apk --release --target-platform android-arm64 --dart-define=ADS_FORCE=true -P useWechatDebugSigning=true
```


`lib/main.dart` 里广告初始化有两个条件：

- **正式包**：`store.isAuthenticated` 为真才初始化 SDK。因为游客入口 `browseAsGuest()` 没有协议同意动作，
  用"已登录"等价于"用户已同意《用户协议》《隐私政策》"，这是合规底线。
  → 不登录直接进 App 看，**不会有开屏也不会有 Banner**，这不是 bug。
- **联调包**：给 `AdsService` 放行，不登录也初始化。

出联调包（release 引擎 + 免登录出广告，用于真机验证）：

```bat
cd /d D:\dev\bojian-mobile
set GRADLE_USER_HOME=D:\dev\gradle-home
flutter build apk --release --target-platform android-arm64 --dart-define=ADS_FORCE=true
```

`ADS_FORCE=true` 还会让 App **自动以游客身份进入**——因为 `browseAsGuest()` 在 UI 上没有任何入口，
不加这一步就永远卡在登录页，根本到不了 Banner 所在的积分页。

产物 `build/app/outputs/flutter-apk/app-release.apk`，签名与正式包一致。
抓日志：

```bat
adb logcat -s PangleAds:V PangleBanner:V
```

关键日志：`穿山甲 SDK 初始化成功` / `初始化失败 code=... msg=...` / `开屏拉取失败 code=...` /
`Banner 拉取成功，开始渲染` / `Banner 拉取失败 code=...`。

> 注意：如果日志里只有 `PangleAds` 而没有任何 `PangleBanner`，说明 Banner 的 PlatformView 根本没创建，
> 也就是页面没被打开，而不是广告没填充。




