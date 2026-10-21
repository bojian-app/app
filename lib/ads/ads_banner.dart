import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:pangle_ads/pangle_ads.dart';

import 'ads_config.dart';
import 'ads_service.dart';

/// 页面内嵌 Banner。
///
/// 没有广告、SDK 未就绪、平台不支持或可用宽度不足时返回空盒：
/// 不占位、不留白块，也不会把 300dp 宽的广告塞进更窄的容器里。
class AdsBanner extends StatelessWidget {
  const AdsBanner({
    super.key,
    this.enabled = true,
    this.padding = const EdgeInsets.only(top: 12),
  });

  /// 业务是否允许展示（本站用「已登录」作为同意协议的等价条件）。
  /// 联调包（`ADS_FORCE=true`）会忽略这个开关。
  final bool enabled;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (!AdsConfig.enabled || !AdsService.isReady) {
      return const SizedBox.shrink();
    }
    if (!enabled && !AdsConfig.forceEnabled) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < AdsConfig.bannerWidth) {
            return const SizedBox.shrink();
          }
          return Center(
            child: PangleBannerView(
              slotId: AdsConfig.bannerSlotId,
              width: AdsConfig.bannerWidth,
              height: AdsConfig.bannerHeight,
              debugLabel: AdsConfig.forceEnabled || kDebugMode,
            ),
          );
        },
      ),
    );
  }
}
