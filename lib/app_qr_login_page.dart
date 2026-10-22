import 'dart:async';

import 'package:flutter/material.dart';

import 'app_qr_scanner.dart';

import 'app_store.dart';
import 'app_qr_login_controller.dart';
import 'app_qr_login_service.dart';
import 'app_theme.dart';
import 'profile_avatar.dart';
import 'user_display_name.dart';

// Injectable camera surface keeps platform capture separate from authorization.
typedef QRScannerBuilder = Widget Function(
  BuildContext context,
  ValueChanged<String> onCode,
);

class AppQRLoginPage extends StatefulWidget {
  const AppQRLoginPage({super.key, required this.store, this.scannerBuilder});
  final AppStore store;
  final QRScannerBuilder? scannerBuilder;
  @override
  State<AppQRLoginPage> createState() => _AppQRLoginPageState();
}

class _AppQRLoginPageState extends State<AppQRLoginPage> {
  late final controller = AppQRLoginController(AppQRLoginService(widget.store));
  bool _closing = false;
  Key _scannerKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    controller.addListener(_phaseChanged);
  }

  void _phaseChanged() {
    if (controller.phase == AppQRLoginPhase.expired) {
      // A fast expiry response may arrive before the stopped camera unmounts.
      _scannerKey = UniqueKey();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || controller.phase != AppQRLoginPhase.expired) return;
        controller.rescan();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('请扫描新的登录二维码')));
      });
      return;
    }
    if (_closing || controller.phase != AppQRLoginPhase.success) return;
    _closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || controller.phase != AppQRLoginPhase.success) return;
      final route = ModalRoute.of(context);
      if (route?.isCurrent == true && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    controller.removeListener(_phaseChanged);
    controller.dispose();
    super.dispose();
  }

  Widget _camera(BuildContext context) {
    void detect(String value) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      unawaited(controller.scan(value));
    }

    if (widget.scannerBuilder case final builder?) {
      return builder(context, detect);
    }
    return AppQRScanner(onCode: detect);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      // Expiry returns directly to capture while the listener resets the session.
      final phase = controller.phase == AppQRLoginPhase.expired
          ? AppQRLoginPhase.scanning
          : controller.phase;
      final authorizing =
          phase == AppQRLoginPhase.confirmation ||
          phase == AppQRLoginPhase.confirming ||
          phase == AppQRLoginPhase.canceling;
      return Scaffold(
        key: const ValueKey('app-qr-login-page'),
        backgroundColor: authorizing ? context.colors.surface : null,
        appBar: AppBar(
          backgroundColor: authorizing ? context.colors.surface : null,
          surfaceTintColor: authorizing ? Colors.transparent : null,
          automaticallyImplyLeading: !authorizing,
          title: authorizing
              ? TextButton(
                  key: const ValueKey('app-qr-close'),
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.ink,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('关闭'),
                )
              : Text(phase == AppQRLoginPhase.scanning ? '扫一扫' : '官网登录'),
          titleSpacing: authorizing ? 8 : null,
          centerTitle: authorizing ? false : null,
        ),
        body: SafeArea(
          child: authorizing
              ? _authorization(context)
              : phase == AppQRLoginPhase.scanning
              ? Column(
                  children: [
                    Expanded(
                      child: KeyedSubtree(
                        key: _scannerKey,
                        child: _camera(context),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        '扫描博简官网的 App 登录二维码',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                )
              : Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (controller.busy)
                            const Center(child: CircularProgressIndicator()),
                          const SizedBox(height: 24),
                          Text(
                            switch (phase) {
                              AppQRLoginPhase.loading => '正在识别官网登录请求',
                              AppQRLoginPhase.confirmation ||
                              AppQRLoginPhase.confirming ||
                              AppQRLoginPhase.canceling => '确认登录博简官网',
                              AppQRLoginPhase.success => '已授权官网登录',
                              AppQRLoginPhase.canceled => '已取消登录',
                              AppQRLoginPhase.sessionChanged => '登录状态已变化',
                              _ => '无法使用此二维码',
                            },
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (controller.session != null) ...[
                            const SizedBox(height: 24),
                            const Text(
                              appQRWebsite,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              controller.session!.clientName,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '使用账号：${userDisplayName(widget.store.name)}',
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 16),
                          Text(
                            phase == AppQRLoginPhase.success
                                ? '请返回电脑上的博简官网继续使用'
                                : '仅在您本人正在登录官网时确认',
                            textAlign: TextAlign.center,
                          ),
                          if (controller.error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(
                                controller.error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          const SizedBox(height: 28),
                          if (!controller.busy) ...[
                            if (phase != AppQRLoginPhase.sessionChanged)
                              FilledButton(
                                onPressed: controller.rescan,
                                child: const Text('重新扫码'),
                              ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('返回'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      );
    },
  );

  Widget _authorization(BuildContext context) {
    final colors = context.colors;
    final secondary = TextStyle(fontSize: 14, height: 1.5, color: colors.muted);
    final buttonStyle = FilledButton.styleFrom(
      backgroundColor: colors.accent,
      foregroundColor: context.isDark ? colors.canvas : Colors.white,
      minimumSize: const Size.fromHeight(48),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      textStyle: Theme.of(context).textTheme.labelLarge
          ?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
    );
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 20,
                          color: colors.accent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '博简官网 申请登录',
                            style: TextStyle(fontSize: 13, color: colors.ink),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '使用你的博简账号\n登录官网',
                      style: TextStyle(
                        fontSize: 24,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text('使用以下账号登录', style: secondary),
                    const SizedBox(height: 12),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.symmetric(
                          horizontal: BorderSide(color: colors.border),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          children: [
                            ProfileAvatar(
                              seed: profileAvatarSeed(widget.store),
                              url: widget.store.avatarURL,
                              size: 48,
                              borderRadius: 6,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userDisplayName(widget.store.name),
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: colors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('当前博简账号', style: secondary),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.check,
                              color: colors.accent,
                              size: 22,
                              semanticLabel: '已选中',
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (controller.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          controller.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 32),
                    const Spacer(),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FilledButton(
                              key: const ValueKey('app-qr-confirm'),
                              style: buttonStyle,
                              onPressed: controller.canConfirm
                                  ? controller.confirm
                                  : null,
                              child: Text(
                                controller.phase == AppQRLoginPhase.confirming
                                    ? '正在授权…'
                                    : '同意',
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              key: const ValueKey('app-qr-cancel'),
                              style: buttonStyle.copyWith(
                                backgroundColor: WidgetStatePropertyAll(
                                  colors.inset,
                                ),
                                foregroundColor:
                                    WidgetStateProperty.resolveWith(
                                      (states) =>
                                          states.contains(WidgetState.disabled)
                                          ? colors.muted
                                          : colors.accent,
                                    ),
                              ),
                              onPressed: controller.busy
                                  ? null
                                  : controller.cancel,
                              child: Text(
                                controller.phase == AppQRLoginPhase.canceling
                                    ? '正在拒绝…'
                                    : '拒绝',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
