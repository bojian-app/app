import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'confirmation_dialog.dart';
import 'design.dart';

class AgreementDialog extends StatefulWidget {
  const AgreementDialog({
    super.key,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  @override
  State<AgreementDialog> createState() => _AgreementDialogState();
}

class _AgreementDialogState extends State<AgreementDialog> {
  final terms = TapGestureRecognizer();
  final privacy = TapGestureRecognizer();

  @override
  Widget build(BuildContext context) {
    terms.onTap = widget.onOpenTerms;
    privacy.onTap = widget.onOpenPrivacy;
    final linkStyle = TextStyle(
      color: context.colors.accent,
      fontWeight: FontWeight.w500,
    );
    return AppConfirmationDialog(
      title: '用户协议与隐私政策',
      content: Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: '欢迎使用博简。请阅读'),
            TextSpan(text: '《用户协议》', style: linkStyle, recognizer: terms),
            const TextSpan(text: '和'),
            TextSpan(text: '《隐私政策》', style: linkStyle, recognizer: privacy),
            const TextSpan(text: '，了解服务规则及个人信息处理方式。'),
          ],
        ),
      ),
      cancelLabel: '暂不同意',
      confirmLabel: '同意并继续',
      confirmKey: const ValueKey('auth-agree-continue'),
      onCancel: () => Navigator.pop(context, false),
      onConfirm: () => Navigator.pop(context, true),
    );
  }

  @override
  void dispose() {
    terms.dispose();
    privacy.dispose();
    super.dispose();
  }
}
