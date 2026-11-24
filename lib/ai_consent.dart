import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'api/bojian_api.dart';
import 'app_store.dart';
import 'confirmation_dialog.dart';
import 'design.dart';
import 'legal_document.dart';
import 'legal_document_page.dart';

/// 弹窗文案变化（接收方、信息种类、用途）时与服务端 `aiConsentVersion` 一起递增，
/// 已同意的用户会被再次询问。
const aiConsentVersion = '1';

/// 服务端在未同意时拒绝 AI 请求所用的错误码。
const aiConsentRequiredCode = 'AI_CONSENT_REQUIRED';

String aiConsentStorageKey(int user) => 'bojian.ai-consent.$user';

/// 向 DeepSeek 提供个人信息前的单独同意（《个人信息保护法》第二十三条）。
/// 服务端记录同意与撤回并在 AI 接口上校验；本机按账号缓存，避免每次都询问服务端。
class AiConsent {
  /// 本机缓存的结果，不发请求。
  static Future<bool> granted(AppStore store) async {
    try {
      return await store.storage.read(aiConsentStorageKey(store.userID)) ==
          aiConsentVersion;
    } catch (_) {
      return false;
    }
  }

  /// 以服务端为准并更新本机缓存；请求失败时退回本机缓存。
  static Future<bool> refresh(AppStore store) async {
    try {
      final response = await store.request('GetMeAiConsent');
      final granted =
          response.data['granted'] == true &&
          response.data['version'] == aiConsentVersion;
      await _cache(store, granted);
      return granted;
    } on ApiFailure {
      return granted(store);
    }
  }

  /// 已同意时直接返回 true；否则弹窗询问，用户拒绝或记录失败时返回 false。
  static Future<bool> ensure(BuildContext context, AppStore store) async {
    if (await granted(store)) return true;
    // 重装或换设备后本机没有缓存，先确认服务端是否已同意过。
    if (await refresh(store)) return true;
    if (!context.mounted) return false;
    final agreed = await showAppDialog<bool>(
      context,
      builder: (_) => const AiConsentDialog(),
    );
    if (agreed != true) return false;
    try {
      await store.request(
        'PutMeAiConsent',
        body: const {'version': aiConsentVersion},
      );
    } on ApiFailure catch (error) {
      if (context.mounted) toast(context, error.message);
      return false;
    }
    await remember(store);
    return true;
  }

  /// 只写本机缓存；服务端记录由 [ensure] 完成，测试用它预置已同意状态。
  static Future<void> remember(AppStore store) => _cache(store, true);

  static Future<void> withdraw(AppStore store) async {
    await store.request('DeleteMeAiConsent');
    await _cache(store, false);
  }

  static Future<void> _cache(AppStore store, bool granted) async {
    try {
      await store.storage.write(
        aiConsentStorageKey(store.userID),
        granted ? aiConsentVersion : null,
      );
    } catch (_) {
      // 缓存只省去一次查询，写入失败时下次再向服务端确认。
    }
  }
}

class AiConsentDialog extends StatefulWidget {
  const AiConsentDialog({super.key});

  @override
  State<AiConsentDialog> createState() => _AiConsentDialogState();
}

class _AiConsentDialogState extends State<AiConsentDialog> {
  final privacy = TapGestureRecognizer();

  @override
  void initState() {
    super.initState();
    privacy.onTap = () => openPage<void>(
      context,
      const LegalDocumentPage(kind: LegalDocumentKind.privacyPolicy),
    );
  }

  @override
  void dispose() {
    privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strong = const TextStyle(fontWeight: FontWeight.w600);
    return AppConfirmationDialog(
      title: '使用 AI 功能前请确认',
      content: Text.rich(
        TextSpan(
          children: [
            const TextSpan(
              text: '使用 AI 简历生成、AI 简历优化、单段生成和简历文件导入时，我们需要将相关内容提供给第三方处理：\n\n',
            ),
            TextSpan(text: '接收方：', style: strong),
            const TextSpan(text: '杭州深度求索人工智能基础技术研究有限公司（DeepSeek 开放平台）\n'),
            TextSpan(text: '联系方式：', style: strong),
            const TextSpan(text: 'api-service@deepseek.com\n'),
            TextSpan(text: '目的：', style: strong),
            const TextSpan(text: '生成、优化或解析简历内容\n'),
            TextSpan(text: '提供的信息：', style: strong),
            const TextSpan(
              text: '您填写的生成要求，简历中的经历文本、公司与项目名称、职位等；导入简历时还包括文件中的文字和扫描页图像，可能含姓名、联系方式和照片\n',
            ),
            TextSpan(text: '方式：', style: strong),
            const TextSpan(text: '通过加密接口传输\n\n'),
            TextSpan(
              text: '根据 DeepSeek 的隐私政策，对方可能在加密和去标识化后将上述内容用于模型训练和改进。\n\n',
              style: strong,
            ),
            const TextSpan(
              text: '您可以不同意，不同意只影响 AI 功能，其他功能照常使用；同意后可在“设置—AI 功能授权”中随时撤回。详见',
            ),
            TextSpan(
              text: '《隐私政策》',
              style: TextStyle(
                color: context.colors.accent,
                fontWeight: FontWeight.w500,
              ),
              recognizer: privacy,
            ),
            const TextSpan(text: '。'),
          ],
        ),
        textAlign: TextAlign.left,
      ),
      cancelLabel: '不同意',
      cancelKey: const ValueKey('ai-consent-decline'),
      onCancel: () => Navigator.pop(context, false),
      confirmLabel: '同意',
      confirmKey: const ValueKey('ai-consent-accept'),
      onConfirm: () => Navigator.pop(context, true),
    );
  }
}
