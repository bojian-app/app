import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'api/bojian_api.dart';
import 'confirmation_dialog.dart';
import 'design.dart';
import 'legal_document.dart';
import 'legal_document_page.dart';

/// 首次启动（或协议版本更新后）的隐私政策弹窗。同意前不读取设备信息、
/// 不恢复登录、不初始化任何第三方 SDK；同意结果只保存在本机。
class PrivacyConsent {
  static const storageKey = 'bojian.privacy-consent';

  static String get currentVersion =>
      'terms:${legalAgreementVersions['terms']},privacy:${legalAgreementVersions['privacy']}';

  static Future<bool> accepted(SessionStorage storage) async {
    try {
      return await storage.read(storageKey) == currentVersion;
    } catch (_) {
      return false;
    }
  }

  /// 弹窗直到用户同意才返回。Android 上两次拒绝后退出到桌面；iOS 不主动退出，回到弹窗。
  static Future<void> ensure(
    SessionStorage storage,
    BuildContext Function() context,
  ) async {
    if (await accepted(storage)) return;
    while (true) {
      final agreed = await showAppDialog<bool>(
        context(),
        builder: (_) => const PrivacyConsentDialog(),
      );
      if (agreed == true) break;
      final exit = await showAppDialog<bool>(
        context(),
        builder: (dialogContext) => AppConfirmationDialog(
          title: '温馨提示',
          content: const Text(
            '博简需要您同意《用户协议》和《隐私政策》才能为您提供简历编辑、登录等服务。我们会严格保护您的个人信息，您可以再次查看后决定。',
          ),
          cancelLabel: _canExit ? '不同意并退出' : null,
          cancelKey: const ValueKey('privacy-consent-exit'),
          onCancel: () => Navigator.pop(dialogContext, true),
          confirmLabel: '再次查看',
          confirmKey: const ValueKey('privacy-consent-review'),
          onConfirm: () => Navigator.pop(dialogContext, false),
        ),
      );
      // 安卓上退出只是把应用移到后台，进程仍在；回到应用时继续弹窗，
      // 保证不同意就不会往下初始化。
      if (exit == true && _canExit) await SystemNavigator.pop();
    }
    try {
      await storage.write(storageKey, currentVersion);
    } catch (_) {
      // 写入失败时下次启动再询问，不影响本次使用。
    }
  }

  static bool get _canExit => defaultTargetPlatform == TargetPlatform.android;
}

class PrivacyConsentDialog extends StatefulWidget {
  const PrivacyConsentDialog({super.key});

  @override
  State<PrivacyConsentDialog> createState() => _PrivacyConsentDialogState();
}

class _PrivacyConsentDialogState extends State<PrivacyConsentDialog> {
  final terms = TapGestureRecognizer();
  final privacy = TapGestureRecognizer();

  void open(LegalDocumentKind kind) =>
      openPage<void>(context, LegalDocumentPage(kind: kind));

  @override
  void initState() {
    super.initState();
    terms.onTap = () => open(LegalDocumentKind.userAgreement);
    privacy.onTap = () => open(LegalDocumentKind.privacyPolicy);
  }

  @override
  void dispose() {
    terms.dispose();
    privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final linkStyle = TextStyle(
      color: context.colors.accent,
      fontWeight: FontWeight.w500,
    );
    return AppConfirmationDialog(
      title: '用户协议与隐私政策',
      content: Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: '欢迎使用博简！请您阅读并同意'),
            TextSpan(text: '《用户协议》', style: linkStyle, recognizer: terms),
            const TextSpan(text: '和'),
            TextSpan(text: '《隐私政策》', style: linkStyle, recognizer: privacy),
            const TextSpan(
              text:
                  '。\n\n'
                  '1. 为识别登录设备、保障账号安全，我们会收集设备型号、系统版本和设备标识；\n'
                  '2. 您填写的简历会保存到服务器；使用 AI 功能前，我们会单独征求您的同意，再将相关内容提供给 DeepSeek 处理；\n'
                  '3. 相机、相册权限仅在您拍照、选图或扫码时申请；\n'
                  '4. 免费用户登录后发现页会展示非个性化广告。\n\n'
                  '同意前我们不会收集上述信息，也不会初始化第三方 SDK。',
            ),
          ],
        ),
        textAlign: TextAlign.left,
      ),
      cancelLabel: '不同意',
      cancelKey: const ValueKey('privacy-consent-decline'),
      onCancel: () => Navigator.pop(context, false),
      confirmLabel: '同意',
      confirmKey: const ValueKey('privacy-consent-accept'),
      onConfirm: () => Navigator.pop(context, true),
    );
  }
}
