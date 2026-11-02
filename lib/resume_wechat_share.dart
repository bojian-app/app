import 'dart:io';

import 'package:fluwx_no_pay/fluwx_no_pay.dart';
import 'package:share_plus/share_plus.dart';

import 'api/bojian_api.dart';
import 'wechat_login.dart';

/// Use the SDK so WeChat receives our app identity and can return to Bojian.
/// The system ACTION_SEND flow does not establish a WeChat SDK callback.
class ResumeWeChatSharer {
  ResumeWeChatSharer([this._sdk]);

  static final instance = ResumeWeChatSharer();
  Fluwx? _sdk;

  Future<void> share(XFile file) async {
    final source = File(file.path);
    final suffix = file.name.split('.').last.toLowerCase();
    if (!['pdf', 'docx'].contains(suffix) || !await source.exists()) {
      throw const ApiFailure('导出文件已失效，请重新导出');
    }
    final length = await source.length();
    if (length == 0 || length > 30 * 1024 * 1024) {
      throw const ApiFailure('导出文件无效或过大，请重新导出');
    }
    final sdk = _sdk ??= Fluwx();
    if (!await sdk.registerApi(
      appId: NativeWeChatAuthorizer.appID,
      universalLink: NativeWeChatAuthorizer.universalLink,
    )) {
      throw const ApiFailure('微信分享暂不可用，请使用更多分享方式');
    }
    if (!await sdk.isWeChatInstalled) {
      throw const ApiFailure('请先安装微信，或使用更多分享方式');
    }
    final launched = await sdk.share(
      WeChatShareFileModel(
        WeChatFile.file(source, suffix: '.$suffix'),
        title: file.name,
      ),
    );
    if (!launched) {
      throw const ApiFailure('无法打开微信，请重试或使用更多分享方式');
    }
    // This only acknowledges dispatch. Do not report "sent" or hold the sheet
    // busy waiting for a response: the user may cancel or stay in WeChat.
  }
}
