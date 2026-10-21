import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 穿山甲（GroMore）广告的原生桥接层。
///
/// 这一层只做「传参 + 拿结果」，业务判断（何时初始化、何时展示）放在应用侧。
class PangleAds {
  PangleAds._();

  static const MethodChannel _channel = MethodChannel(
    'cn.kelance.bojian/pangle_ads',
  );

  /// 当前平台是否已经接了原生实现。鸿蒙/桌面端直接返回 false。
  static bool get isSupported => Platform.isAndroid || Platform.isIOS;

  /// 初始化 SDK。必须在用户同意隐私政策之后调用。
  static Future<bool> initialize({
    required String appId,
    bool debug = false,
    bool personalized = true,
  }) async {
    if (!isSupported) return false;
    try {
      final result = await _channel.invokeMethod<bool>('init', {
        'appId': appId,
        'debug': debug,
        'personalized': personalized,
      });
      return result ?? false;
    } on PlatformException catch (error) {
      debugPrint('穿山甲初始化失败: ${error.code} ${error.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> isInitialized() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('isInitialized') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 展示开屏广告。返回 false 表示没广告可放，调用方直接进入应用即可。
  static Future<bool> showSplash({
    required String slotId,
    int timeoutMs = 3000,
  }) async {
    if (!isSupported || slotId.isEmpty) return false;
    try {
      final result = await _channel.invokeMethod<bool>('showSplash', {
        'slotId': slotId,
        'timeoutMs': timeoutMs,
      });
      return result ?? false;
    } on PlatformException catch (error) {
      debugPrint('开屏展示失败: ${error.code} ${error.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

/// Banner 广告视图。宽高需与穿山甲后台「代码位尺寸」一致（dp/pt）。
class PangleBannerView extends StatelessWidget {
  const PangleBannerView({
    super.key,
    required this.slotId,
    this.width = 300,
    this.height = 150,
    this.debugLabel = false,
  });

  final String slotId;
  final double width;
  final double height;

  /// 联调模式下在广告位里显示加载状态/失败错误码，省去抓 logcat。
  final bool debugLabel;

  static const String _viewType = 'cn.kelance.bojian/pangle_banner';

  @override
  Widget build(BuildContext context) {
    if (!PangleAds.isSupported || slotId.isEmpty) {
      return const SizedBox.shrink();
    }
    final params = <String, dynamic>{
      'slotId': slotId,
      'width': width,
      'height': height,
      'debugLabel': debugLabel,
    };
    if (Platform.isAndroid) {
      return SizedBox(
        width: width,
        height: height,
        child: AndroidView(
          viewType: _viewType,
          creationParams: params,
          creationParamsCodec: const StandardMessageCodec(),
        ),
      );
    }
    return SizedBox(
      width: width,
      height: height,
      child: UiKitView(
        viewType: _viewType,
        creationParams: params,
        creationParamsCodec: const StandardMessageCodec(),
      ),
    );
  }
}
