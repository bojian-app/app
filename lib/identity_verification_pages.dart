import 'package:flutter/material.dart';

import 'design.dart';
import 'developer_verification_controller.dart';
import 'identity_verification_service.dart';

class IdentityConfirmationPage extends StatefulWidget {
  const IdentityConfirmationPage({super.key, required this.controller});
  final DeveloperVerificationController controller;

  @override
  State<IdentityConfirmationPage> createState() =>
      _IdentityConfirmationPageState();
}

class _IdentityConfirmationPageState extends State<IdentityConfirmationPage> {
  bool agreed = false;

  Future<void> start() async {
    if (!agreed ||
        !await widget.controller.startFace() ||
        !mounted ||
        !widget.controller.sessionCurrent) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => IdentityFacePage(controller: widget.controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final identity = controller.sessionCurrent ? controller.identity : null;
      return _IdentityScaffold(
        title: '确认身份信息',
        children: identity == null
            ? [const Text('识别信息已失效，请返回重新识别')]
            : [
                const Text(
                  '请核对身份证识别结果',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Text(
                  '人脸核验将使用以下身份信息。',
                  style: TextStyle(color: context.colors.muted),
                ),
                const SizedBox(height: 24),
                _IdentityField(label: '姓名', value: identity.name),
                _IdentityField(label: '身份证号', value: identity.maskedNumber),
                _IdentityField(
                  label: '证件有效期',
                  value:
                      '${identity.validFrom} 至 ${identity.longTerm ? '长期' : identity.validUntil}',
                ),
                const SizedBox(height: 20),
                _FaceConsent(
                  key: const ValueKey('identity-face-consent'),
                  value: agreed,
                  onChanged: controller.busy
                      ? null
                      : (value) => setState(() => agreed = value ?? false),
                ),
                const SizedBox(height: 12),
                if (controller.error != null) _IdentityError(controller.error!),
                FilledButton(
                  key: const ValueKey('identity-start-face'),
                  style: FilledButton.styleFrom(
                    backgroundColor: context.colors.accent,
                    foregroundColor: context.isDark
                        ? context.colors.canvas
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                  onPressed: agreed && !controller.busy ? start : null,
                  child: Text(controller.progress ?? '确认并开始人脸核验'),
                ),
                TextButton(
                  onPressed: controller.busy
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('信息有误，返回重新上传'),
                ),
              ],
      );
    },
  );
}

class _FaceConsent extends StatelessWidget {
  const _FaceConsent({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style
        .merge(const TextStyle(fontSize: 13, height: 1.6));
    final line = TextPainter(
      text: TextSpan(text: '我', style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
    )..layout();
    final lineHeight = line.height;
    line.dispose();
    return MergeSemantics(
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 48,
                height: lineHeight,
                child: Checkbox(
                  value: value,
                  onChanged: onChanged,
                  activeColor: context.colors.accent,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '我确认上述信息属于本人，并同意将姓名、身份证号提供给百度智能云，并由百度原生 SDK 采集现场人脸及必要的设备、网络信息，用于活体检测、身份一致性核验和安全风控。',
                  key: const ValueKey('identity-face-consent-text'),
                  style: style,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class IdentityFacePage extends StatefulWidget {
  const IdentityFacePage({super.key, required this.controller});
  final DeveloperVerificationController controller;

  @override
  State<IdentityFacePage> createState() => _IdentityFacePageState();
}

class _IdentityFacePageState extends State<IdentityFacePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) startNative();
    });
  }

  @override
  void dispose() {
    widget.controller.cancelFace();
    super.dispose();
  }

  Future<void> startNative() => widget.controller.runFace(
    accentColor: context.colors.accent.toARGB32(),
    dark: context.isDark,
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final session = controller.sessionCurrent ? controller.faceSession : null;
      final status = session?.status;
      final expired =
          status == IdentityFaceStatus.expired ||
          (status == IdentityFaceStatus.pending &&
              !session!.expiresAt.isAfter(DateTime.now()));
      final verified = status == IdentityFaceStatus.verified;
      final pending = status == IdentityFaceStatus.pending && !expired;
      return _IdentityScaffold(
        title: '人脸核验',
        children: session == null
            ? [const Text('登录状态已变化，请返回后重试')]
            : [
                Icon(
                  verified ? Icons.verified_user_outlined : Icons.face_outlined,
                  size: 72,
                  color: context.colors.accent,
                ),
                const SizedBox(height: 24),
                Text(
                  verified
                      ? '实名认证已通过'
                      : expired
                      ? '核验已过期'
                      : pending
                      ? '完成本人活体核验'
                      : '人脸核验未通过',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  verified
                      ? '身份信息和人脸核验结果已由服务端确认。'
                      : expired
                      ? '请返回重新识别身份证并发起核验。'
                      : pending
                      ? '请按照原生核验页面的指引，将本人面部置于框内并完成活体检测。完成后会自动查询核验结果。'
                      : (session.reason ?? '请确认使用本人有效证件后重新认证。'),
                  style: TextStyle(color: context.colors.muted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                if (pending) ...[
                  FilledButton(
                    key: const ValueKey('identity-open-native'),
                    style: FilledButton.styleFrom(
                      backgroundColor: context.colors.accent,
                      foregroundColor: context.isDark
                          ? context.colors.canvas
                          : Colors.white,
                    ),
                    onPressed: controller.busy ? null : startNative,
                    child: Text(controller.busy ? '正在核验…' : '开始人脸核验'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    key: const ValueKey('identity-refresh-face'),
                    onPressed: controller.busy ? null : controller.refreshFace,
                    child: Text(controller.busy ? '正在查询…' : '查看核验结果'),
                  ),
                  if (session.reason != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        session.reason!,
                        style: TextStyle(color: context.colors.muted),
                      ),
                    ),
                ] else
                  FilledButton(
                    onPressed: () {
                      if (verified) {
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      } else {
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                      }
                    },
                    child: Text(verified ? '完成' : '返回重新识别'),
                  ),
                if (controller.error != null) _IdentityError(controller.error!),
              ],
      );
    },
  );
}

class _IdentityScaffold extends StatelessWidget {
  const _IdentityScaffold({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.inset,
    appBar: AppBar(
      title: Text(title),
      centerTitle: false,
      backgroundColor: context.colors.surface,
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: children,
          ),
        ),
      ),
    ),
  );
}

class _IdentityField extends StatelessWidget {
  const _IdentityField({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.colors.muted),
        ),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontSize: 17)),
      ],
    ),
  );
}

class _IdentityError extends StatelessWidget {
  const _IdentityError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}
