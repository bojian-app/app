# iOS 发现页横幅广告

本地 Pod `BojianPangleAds` 使用用户提供的穿山甲融合 SDK 7.9.0.0。完整下载包从 `~/Downloads/union_platform_iOS_7.9.0.0` 移至 `vendor/union_platform_iOS_7.9.0.0`，保留原始 SDK、示例和适配器。二进制下载包被 Git 忽略；其他开发机需把相同版本的完整包放到该目录后运行 `pod install`。

App 链接 `BUAdSDK.xcframework`、`CSJMediation.xcframework` 和 `CSJAdSDK.bundle`；不打包演示程序、广告测试工具、直播扩展和未配置的第三方广告网络适配器。若后台瀑布流配置了其他广告网络，还需安装相应网络 SDK 和适配器。

## 应用配置

用户已通过后台截图确认当前应用为测试应用，平台说明测试应用不区分 Android/iOS、转正式后才区分。因此 iOS 当前复用测试应用 `5898107` 和横幅广告位 `104712824`，使用 GroMore。

转正式或替换广告位时，通过 Flutter 构建参数设置对应 iOS 应用的参数：

```sh
flutter build ios --release \
  --dart-define=PANGLE_IOS_APP_ID=<iOS应用ID> \
  --dart-define=PANGLE_IOS_BANNER_ID=<iOS横幅广告位ID> \
  --dart-define=PANGLE_IOS_USE_MEDIATION=true
```

`PANGLE_IOS_USE_MEDIATION` 默认为 `true`，普通穿山甲代码位设为 `false`。任意一个 iOS ID 显式设置为空时不创建广告视图，也不初始化 SDK。正式应用需使用平台对应的配置，不能继续假设测试应用的跨平台规则适用。

## 展示行为

- 仅登录后、欢迎动画完成且发现页可见时首次加载。SDK 注册视图工厂时不会初始化。
- 使用 SDK 渲染的 300×150 横幅，实际高度通过原生回调传给 Flutter；不支持后台将自渲染信息流混入此广告位。
- 加载期间不占页面空间；初始化最多 8 秒，初始化与加载合计最多 12 秒。失败、关闭及无填充后收起，不展示模拟广告。
- 切换页面或进入后台隐藏已有广告；注销、更换会话或销毁视图时释放。SDK 关闭按钮与点击由 SDK 处理。
- 关闭位置、Wi-Fi BSSID、传感器采集、IDFA 和聚合个性化开关；不请求跟踪权限。
- 原生诊断日志前缀为 `BojianBannerAds`。启动广告仍保持移除状态。

代码编译和安装成功不代表平台已填充广告。人工验收需使用正确的 iOS 应用/横幅 ID，检查展示、关闭、点击返回、切换标签、后台返回和退出登录。
