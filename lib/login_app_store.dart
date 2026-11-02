import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api/bojian_api.dart';

enum LoginApp {
  wechat('微信', 'com.tencent.mm', '414478124', 'https://weixin.qq.com/'),
  douyin(
    '抖音',
    'com.ss.android.ugc.aweme',
    '1142110895',
    'https://www.douyin.com/downloadpage/app',
  );

  const LoginApp(
    this.label,
    this.androidPackage,
    this.appleId,
    this.downloadUrl,
  );

  final String label;
  final String androidPackage;
  final String appleId;
  final String downloadUrl;
}

/// Opens installation without continuing the current authorization attempt.
Future<void> openLoginAppStore(LoginApp app) async {
  final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
  final urls = [
    if (isIOS)
      'itms-apps://itunes.apple.com/app/id${app.appleId}'
    else
      'market://details?id=${app.androidPackage}',
    if (isIOS)
      'https://apps.apple.com/app/id${app.appleId}'
    else
      app.downloadUrl,
  ];
  for (final url in urls) {
    try {
      // Launch directly: package-visibility checks can incorrectly report that
      // a store is unavailable even when it can handle this URL.
      if (await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } on PlatformException {
      // Try the web download page if the store cannot be opened.
    } on MissingPluginException {
      // Keep failure actionable on hosts without an external URL handler.
    }
  }
  throw ApiFailure('无法打开下载页面，请在应用市场搜索“${app.label}”安装后重试');
}
