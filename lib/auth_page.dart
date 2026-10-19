import 'agreement_dialog.dart';
import 'legal_document.dart';
import 'legal_document_page.dart';
import 'confirmation_dialog.dart';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'app_store.dart';
import 'design.dart';
import 'login_widgets.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.store});
  final AppStore store;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  @override
  void initState() {
    super.initState();
    widget.store.addListener(refreshState);
  }

  void refreshState() {
    if (mounted) setState(() {});
  }

  bool agreed = false;
  String? signingInWith;
  bool get submitting => signingInWith != null;
  String? error;

  void changeAgreement(bool? value) => setState(() {
    agreed = value ?? false;
    error = null;
  });

  Future<bool> confirmAgreement() async {
    if (agreed) return true;
    final accepted = await showAppDialog<bool>(
      context,
      barrierDismissible: true,
      builder: (_) => AgreementDialog(
        onOpenTerms: () => legal(false),
        onOpenPrivacy: () => legal(true),
      ),
    );
    if (!mounted || accepted != true) return false;
    setState(() {
      agreed = true;
      error = null;
    });
    return true;
  }

  Future<void> signIn({bool douyin = false}) async {
    if (submitting || widget.store.restoring) return;
    final provider = douyin ? '抖音' : '微信';
    dismissKeyboard();
    setState(() {
      signingInWith = provider;
      error = null;
    });
    try {
      if (!await confirmAgreement() || !mounted) return;
      if (douyin) {
        await widget.store.signInWithDouyin(
          confirmRegistration: confirmRegistration,
        );
      } else {
        await widget.store.signInWithWeChat(
          confirmRegistration: confirmRegistration,
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => signingInWith = null);
    }
  }

  Future<bool> confirmRegistration() async {
    if (!mounted) return false;
    return await showAppConfirmation(
          context,
          dialogKey: const ValueKey('auth-registration-dialog'),
          barrierDismissible: false,
          title: '该账号尚未注册',
          content: const Text('是否创建博简账号并完成登录？'),
          cancelLabel: '暂不注册',
          cancelKey: const ValueKey('auth-registration-cancel'),
          confirmLabel: '确认注册并登录',
          confirmKey: const ValueKey('auth-registration-confirm'),
        ) ??
        false;
  }

  Future<void> legal(bool privacy) async {
    await openPage<void>(
      context,
      LegalDocumentPage(
        kind: privacy
            ? LegalDocumentKind.privacyPolicy
            : LegalDocumentKind.userAgreement,
      ),
    );
  }

  Widget alternativeLogin({
    required String keyName,
    required String label,
    required String semanticsLabel,
    required String asset,
    required VoidCallback onTap,
  }) => Semantics(
    label: semanticsLabel,
    button: true,
    enabled: !submitting && !widget.store.restoring,
    child: OutlinedButton.icon(
      key: ValueKey(keyName),
      onPressed: submitting || widget.store.restoring ? null : onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: context.loginInk,
        backgroundColor: context.colors.surface,
        minimumSize: const Size(0, 54),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        side: BorderSide(color: context.loginLine),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: Theme.of(context).textTheme.labelLarge
            ?.copyWith(fontSize: 13, fontWeight: FontWeight.w500),
      ).withoutHover(),
      icon: LoginAppIcon(asset: asset),
      label: Text(label, textAlign: TextAlign.center),
    ),
  );

  Widget buildIllustration() => SizedBox(
    height: 180,
    child: SvgPicture.asset(
      'assets/login/reading.svg',
      key: const ValueKey('auth-illustration'),
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      colorFilter: context.isDark
          ? ColorFilter.mode(context.colors.ink, BlendMode.srcIn)
          : null,
    ),
  );

  Widget buildForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          key: const ValueKey('auth-wechat'),
          onPressed: submitting || widget.store.restoring
              ? null
              : () => signIn(),
          style: loginPrimaryButtonStyle(context),
          icon: const LoginAppIcon(asset: 'assets/login/wechat.jpg'),
          label: Text(signingInWith == '微信' ? '正在等待微信授权…' : '微信登录'),
        ),
      ),
      const SizedBox(height: 12),
      alternativeLogin(
        keyName: 'auth-douyin',
        label: signingInWith == '抖音' ? '正在等待抖音授权…' : '抖音登录',
        semanticsLabel: '抖音登录',
        asset: 'assets/login/douyin.jpg',
        onTap: () => signIn(douyin: true),
      ),
      if (error != null) ...[
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Text(
            error!,
            key: const ValueKey('auth-error'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ),
      ],
      const SizedBox(height: 24),
      LoginConsent(
        agreed: agreed,
        onChanged: submitting ? null : changeAgreement,
        onOpenTerms: () => legal(false),
        onOpenPrivacy: () => legal(true),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.loginCanvas,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final landscape =
              MediaQuery.orientationOf(context) == Orientation.landscape &&
              constraints.maxWidth >= 600;
          final padding = EdgeInsets.symmetric(
            horizontal: landscape ? 32 : 28,
            vertical: 24,
          );
          final contentHeight = (constraints.maxHeight - padding.vertical)
              .clamp(0.0, double.infinity)
              .toDouble();
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: landscape ? 880 : 420),
              child: SingleChildScrollView(
                padding: padding,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: contentHeight),
                  child: landscape
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(flex: 4, child: buildIllustration()),
                            const SizedBox(width: 40),
                            Expanded(flex: 5, child: buildForm()),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            buildIllustration(),
                            const SizedBox(height: 40),
                            buildForm(),
                          ],
                        ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  @override
  void dispose() {
    widget.store.removeListener(refreshState);
    super.dispose();
  }
}
