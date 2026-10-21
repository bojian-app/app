/// 穿山甲广告位配置。
///
/// 这里的 ID 来自穿山甲后台「应用管理 → 博简 → 广告位」列表：
/// - 应用 ID 同时是 SDK 初始化时传入的 appId。
/// - 开屏 / Banner 用的是 **广告位 ID（unitId）**，不是瀑布流里的代码位 ID。
///
/// 当前应用属性是「测试」，请求广告不计费，只用于联调；
/// 转正式应用后如果重新建了广告位，改这里的两个常量即可。
class AdsConfig {
  AdsConfig._();

  /// 博简（应用 ID 5898107）。
  static const String appId = '5898107';

  /// 博简-开屏。
  static const String splashSlotId = '104711277';

  /// 博简-Banner（代码位尺寸 300x150 dp）。
  static const String bannerSlotId = '104712824';

  /// Banner 的尺寸必须与后台代码位尺寸一致，否则会被判为无效曝光。
  static const double bannerWidth = 300;
  static const double bannerHeight = 150;

  /// 开屏拉取超时，超时直接进入应用。
  static const int splashTimeoutMs = 3000;

  /// 仅 debug 生效：不登录也初始化并展示广告，方便联调。
  /// 正式包必须依赖用户同意协议（当前实现为已登录）才初始化。
  static const bool debugTestWithoutLogin = true;

  /// 构建期开关：`--dart-define=ADS_FORCE=true` 时，广告不再等登录，启动即初始化并展示。
  /// 只用于联调包，正式包不要带这个参数。
  static const bool forceEnabled = bool.fromEnvironment('ADS_FORCE');

  /// 构建期开关：`--dart-define=GUEST_FORCE=true` 时，未登录自动以游客身份进入。
  /// 用于「完全不想登录、只想看广告位」的联调场景。
  static const bool forceGuest = bool.fromEnvironment('GUEST_FORCE');

  /// 总开关：调试时可单独关掉，避免影响本地启动速度。
  static const bool enabled = true;
}
