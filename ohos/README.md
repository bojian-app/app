# 博简 HarmonyOS 接入工程（尚未可运行）

包名：`cn.kelance.bojian`。应用显示名称：博简。该目录是已生成的 Flutter 鸿蒙宿主工程，加载仓库根目录的 Flutter 业务代码；不是独立的演示应用，也尚未产出可安装或可申报的鸿蒙版本。

## 工程来源

使用 OpenHarmony Flutter 工具的 `flutter create --platforms ohos --org cn.kelance --project-name bojian --no-pub` 生成，再同步图标、名称和版本号，移除计数器示例的测试代码。

- 仓库：https://gitcode.com/openharmony-sig/flutter_flutter
- 分支：`oh-3.44.9-dev`
- 已核验提交：`340d835f9ecc28e74555068f68b6f22b9038a6b2`
- 实际配套 Dart：`3.12.2`
- 模板兼容 SDK：`5.0.5(17)`；目标 SDK：`26.0.0`（上游模板值，尚未与本机 DevEco SDK 验证）

该开发分支仅用于兼容性验证，不能据此认定可正式发布。现有 Android / iOS 的 pubspec 和锁文件未降级。

## 当前阻塞项

1. 根工程要求 Dart `^3.13.5`，下载并执行的鸿蒙 SDK 实际为 `3.12.2`。需选择兼容的鸿蒙 SDK，或在隔离环境验证业务代码及全部依赖可降级后再调整约束。
2. 本机未安装 DevEco Studio / HarmonyOS SDK，无法编译 ArkTS 或生成 HAP。
3. 当前 pub.dev 依赖的安全存储、文件选择、系统分享、URL 打开、WebView，以及富文本编辑器的原生依赖需要适配版本或自行实现；不能仅凭上游列表“已适配”认定当前版本可用。参考 https://gitcode.com/OpenHarmony-Flutter/docs/blob/main/ThirdpartyLibrarites.md 。
4. `cn.kelance.bojian/settings` 原生通道需要设备信息、版本及系统设置实现；简历文件接收、保存与系统分享流程需要鸿蒙实现和真机验证。
5. `lib/app_store.dart` 当前只识别 iOS / Android / macOS，其余平台回落 WINDOWS。上线前必须添加真实鸿蒙平台标识，并在独立后端项目中同步认证、设备会话校验；禁止以 WINDOWS 伪装完成鸿蒙接入。此前后端仅接受 WINDOWS / MACOS / ANDROID / IOS，接入时需重新核对。
6. 华为开发者账号已有，但尚未创建此鸿蒙应用，也没有签名 Profile / appIdentifier。

## 华为账号准备

在华为 AppGallery Connect 创建鸿蒙应用：名称“博简”、包名 `cn.kelance.bojian`。在 DevEco Studio 登录同一账号，为本工程配置真实签名和调试设备。自动签名可能修改 `build-profile.json5`：不要提交含密码、私钥路径等本机签名配置。

微信开放平台的 Identifier 必须来自真实签名 Profile 的 `app-identifier` / 应用签名信息，不能用包名、Android MD5 或随机值代替。不要将私钥、证书密码发到聊天或提交到仓库。

## 后续构建与验收

解决上述兼容性问题并安装工具链后，用鸿蒙 Flutter 的绝对路径执行 `flutter doctor -v`、`flutter pub get`、`flutter build hap --release`。使用独立工作副本和独立 PUB_CACHE，防止覆盖现有 Android / iOS 的依赖解析结果。

真机验收至少覆盖登录刷新、凭证安全存储、文章与聊天、简历导入、AI 优化确认保存、标准及市场模板 WebView 预览、PDF / Word 保存分享、账号退出与注销。签名成功和完整业务验收完成前，不应在开放平台申报为已具备可用鸿蒙版本。

## 已核查的插件候选（2026-10-15）

通过 pub.dev 元数据核查以下候选。尚未接入正式 pubspec，不能视为已通过构建或功能验证。

| 功能 | 候选包 | 核查结果 |
| --- | --- | --- |
| 文件选择 | `file_selector_ohos 0.5.0+2` | 声明实现 `file_selector`，接口约束 `^2.6.0`，需验证当前调用 |
| WebView | `webview_flutter_ohos 3.15.0` | 接口约束 `^2.10.0`，需验证模板脚本、分页与截图 |
| URL 打开 | `url_launcher_ohos 6.3.0` | 声明实现 `url_launcher`，接口约束 `^2.3.1` |
| 系统分享 | `share_plus_ohos 1.0.0` | 第三方 ClosedHarmony 实现，接口约束 `^7.0.0`，需与现有 share_plus 核对 |
| 安全存储 | `flutter_secure_storage_ohos 1.0.0` | Dart 限定 `<3.0.0`，不可用于本项目；需核查 OpenHarmony 维护仓库的新适配分支，或另做安全实现 |

安全存储不允许降级为明文偏好设置。所有令牌、简历优化任务状态仍应遵循现有安全存储约定。

签名 Profile 下载后，可在仓库根目录提取公开的微信登记字段：

```sh
python3 scripts/harmonyos_profile_info.py /本机路径/应用Profile.p7b
```

脚本只输出 Bundle ID 与 Identifier，会拒绝包名不符或缺少标识的文件；不需要私钥，不会修改签名文件。该工具用于读取资料，不作为证书信任链或发布签名验证工具。

## 隔离兼容性试验结果

已额外检出上游真实标签 `3.44.9+ohos-0.0.1-canary1`（`39285df71a97ffe0c23241dcc459d997a9d8b7c6`），其 Dart 版本为 `3.12.2`。在临时副本中将 SDK 约束改为 `^3.12.2`，完成 `flutter pub get` 和 `dart analyze lib`：依赖解析成功，静态检查无问题。这说明 Dart 代码存在兼容路径，但不等于原生插件支持鸿蒙，也不等于完整测试通过。

根工程仍保持原 SDK 约束和 pubspec.lock。原锁文件要求 Flutter `>=3.47.0`，试验副本重解析为 Flutter `>=3.44.0` 的依赖集合，因此没有直接把试验锁文件覆盖到现有版本。

进一步核查发现，名为 `br_v11.2.0_ohos_dev` 的安全存储候选分支返回的 `flutter_secure_storage/pubspec.yaml` 仍声明 `9.2.4` 和 platform_interface `^1.1.2`；不能仅按分支名称当作 11.2.0 接入。
