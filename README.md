# 博简手机 App

本仓库仅维护手机端 App：Android、iOS，以及正在适配的鸿蒙工程。共享业务代码使用 Flutter；后端服务与管理端在各自项目中维护。

## 工程目录

| 目录 | 用途 |
| --- | --- |
| `lib/` | Flutter 业务代码、HTTP 客户端和生成的认证消息类型 |
| `android/` | Android 原生宿主、文件收发和系统设置通道 |
| `ios/` | iOS 原生宿主、签名配置和关联域名配置副本 |
| `ohos/` | 鸿蒙接入工程，尚不可运行或发布，详见 [接入说明](ohos/README.md) |
| `assets/` | App 图标、字体及许可证、简历模板渲染资源 |
| `api/proto/auth.proto` | 客户端使用的认证消息协议 |
| `test/` | 单元测试与 Widget 测试 |
| `integration_test/`、`test_driver/` | 真机联通性与性能验证 |
| `scripts/`、`tool/` | 手机构建、资源生成和诊断工具 |

应用包名统一为 `cn.kelance.bojian`。Android 当前使用调试证书签名，正式发布前需配置发布证书。iOS 使用 Xcode 配置对应的开发团队和签名。

## 开发与验证

使用满足 `pubspec.yaml` 中 Dart SDK 约束的 Flutter 工具链，依赖版本以 `pubspec.lock` 为准。

```sh
flutter pub get
flutter analyze
flutter test
flutter run --release -d <手机设备ID>
```

默认服务地址为 `https://bojian.kelance.cn/api/v1`。可在运行或构建时覆盖：

```sh
flutter run --release -d <手机设备ID> --dart-define=BOJIAN_API_BASE_URL=https://your-server.example/api/v1
```

地址必须使用 HTTPS 并包含 `/api/v1` 前缀。认证凭证保存在系统安全存储中；测试响应位于 `test/support/`。

## Android 构建

```sh
sh scripts/build_android_release.sh
```

可通过 `FLUTTER_BIN` 指定 Flutter 可执行文件。脚本按 `armeabi-v7a`、`arm64-v8a`、`x86_64` 分别生成 APK，并把安装包和配套 Dart 调试符号归档到 `artifacts/android/<UTC时间>/`。

手机只安装匹配其处理器架构的 APK。发布时应一起备份 APK 和调试符号；构建脚本保留 `pubspec.yaml` 的版本号，正式升级前需递增构建号。

## iOS 构建与关联域名

在安装 Xcode 和 iOS SDK 的 macOS 上构建：

```sh
flutter build ios --release --no-codesign
```

该命令用于验证未签名构建，安装或发布需在 Xcode 中完成签名、归档和导出。

`ios/Runner/Runner.entitlements` 声明关联域名。对应的 [apple-app-site-association](ios/universal-links/apple-app-site-association) 是服务器配置副本，部署至关联域名的 `/.well-known/apple-app-site-association`；它不会随 App 构建自动部署。变更开发团队或 Bundle ID 时，需要同步核对该文件的 `appID`。

## 鸿蒙构建

保留 `ohos/` 和 `scripts/harmonyos_profile_info.py`。目前 SDK/Dart 版本、插件与原生通道仍有适配阻塞，不能使用普通 Flutter 的 Android 构建结果代替鸿蒙 HAP。环境准备、隔离工具链和验收步骤见 [鸿蒙接入说明](ohos/README.md)。

## 资源与工具

- `swift scripts/generate_app_icons.swift`：在 macOS 上从 `assets/branding/app_icon.png` 生成 Android/iOS 图标及商店图标预览。鸿蒙资源由其宿主工程维护。
- `sh scripts/generate_rpc.sh`：使用 `protoc` 和 `protoc_plugin`，从认证协议更新 `lib/api/generated/auth.pb.dart`。业务接口使用 HTTP JSON。
- `tool/api_probe.dart`：服务连通性诊断工具。
- `tool/verify_resume_native_export.py`：检查测试生成的 PDF/Word 原生文字及可编辑性。
- `scripts/harmonyos_profile_info.py`：从鸿蒙签名 Profile 提取公开的应用登记字段。

简历支持 PDF、DOC、DOCX 导入，大小上限 20 MB；校对后保存。Android 支持从微信通过“用其他应用打开”接收文件；iOS 可先保存到“文件”再选择。简历预览和 PDF/Word 导出共用排版结果，PDF 保留可复制文字、Word 保留可编辑文字。字体、模板脚本及许可证属于 App 运行资源，应随仓库保留。

## 本地文件与缓存

`build/`、`.dart_tool/` 等是可重新生成的构建缓存，可通过 `flutter clean` 清理，再执行 `flutter pub get` 恢复依赖配置。

`artifacts/` 是发布归档；`material/`、本机证书及私钥文件是签名材料。这些内容已被 Git 忽略，不作为普通缓存删除，也不能提交凭证。
