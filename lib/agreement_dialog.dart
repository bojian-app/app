import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

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
    const linkStyle = TextStyle(color: blue, fontWeight: FontWeight.w500);
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                namesRoute: true,
                child: const Text(
                  '用户协议与隐私政策',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: ink,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: '欢迎使用博简。请阅读'),
                    TextSpan(
                      text: '《用户协议》',
                      style: linkStyle,
                      recognizer: terms,
                    ),
                    const TextSpan(text: '和'),
                    TextSpan(
                      text: '《隐私政策》',
                      style: linkStyle,
                      recognizer: privacy,
                    ),
                    const TextSpan(text: '，了解服务规则及个人信息处理方式。'),
                  ],
                ),
                style: const TextStyle(fontSize: 14, height: 1.8, color: ink),
              ),
              const SizedBox(height: 12),
              const Text(
                '同意后将继续进行安全验证，验证通过后发送短信验证码。',
                style: TextStyle(fontSize: 12, height: 1.7, color: muted),
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const ValueKey('auth-agree-continue'),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('同意并继续'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(
                  foregroundColor: muted,
                  minimumSize: const Size(0, 44),
                ),
                child: const Text('暂不同意'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    terms.dispose();
    privacy.dispose();
    super.dispose();
  }
}
