import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'app_store.dart';
import 'confirmation_dialog.dart';
import 'design.dart';
import 'developer_verification_controller.dart';
import 'identity_verification_pages.dart';
import 'photo_source_sheet.dart';

class DeveloperVerificationPage extends StatefulWidget {
  const DeveloperVerificationPage({
    super.key,
    required this.store,
    this.pickPhoto,
  });
  final AppStore store;
  final VerificationPhotoPicker? pickPhoto;

  @override
  State<DeveloperVerificationPage> createState() =>
      _DeveloperVerificationPageState();
}

class _DeveloperVerificationPageState extends State<DeveloperVerificationPage> {
  late final DeveloperVerificationController controller =
      DeveloperVerificationController(
        store: widget.store,
        pickPhoto:
            widget.pickPhoto ??
            () => pickAppPhoto(
              context,
              isCurrent: () => controller.sessionCurrent,
            ),
      );

  Color get accent => context.colors.accent;

  void showHelp() => showAppConfirmation(
    context,
    title: '证件拍摄须知',
    content: const Text(
      '请使用本人有效的二代身份证。\n\n将证件置于纯色背景上，保持四角完整、文字清晰，避免倾斜、遮挡和强光反射。\n\n支持 JPG、PNG、WebP 图片，单张不超过 8 MB。',
    ),
    confirmLabel: '知道了',
    cancelLabel: null,
  );

  void showUsage() => showAppConfirmation(
    context,
    title: '身份信息使用说明',
    content: const Text(
      '证件照片、姓名和身份证号码属于敏感个人信息，用于开发者实名认证。\n\n勾选同意并点击下一步后，证件正反面照片将经博简服务端发送至百度智能云进行身份证识别。博简不将证件照片写入文件存储；识别信息在服务端加密临时保存 15 分钟。\n\n您确认识别信息并另行同意后，才会打开百度原生 SDK 进行人脸活体核验。核验会话最长保留 2 小时，通过后博简加密保存姓名、身份证号、有效期及核验状态，用于认证管理。核验 SDK 会处理现场人脸和必要的设备、网络信息以完成安全风控。SDK 仅在您主动开始核验后调用，不录制音频或保存人脸视频。\n\n照片预览在离开本页后清除。识别错误时请返回重新拍摄，勿使用他人证件。',
    ),
    confirmLabel: '知道了',
    cancelLabel: null,
  );

  Future<void> next() async {
    if (!controller.canContinue) return;
    if (!await controller.recognize() ||
        !mounted ||
        !controller.sessionCurrent) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => IdentityConfirmationPage(controller: controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Scaffold(
      key: const ValueKey('developer-verification-page'),
      backgroundColor: context.colors.inset,
      appBar: AppBar(
        title: const Text('开发者认证'),
        centerTitle: false,
        backgroundColor: context.colors.surface,
      ),
      body: !controller.sessionCurrent
          ? const Center(child: Text('登录状态已变化，请返回后重试'))
          : SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: ListView(
                    key: const ValueKey('developer-verification-scroll'),
                    padding: const EdgeInsets.only(bottom: 32),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Text(
                                  '本人实名认证',
                                  style: TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '开发者身份',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: accent,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '请上传身份证人像面与国徽面照片',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.colors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ColoredBox(
                        color: context.colors.surface,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final stacked =
                                      constraints.maxWidth < 280 ||
                                      MediaQuery.textScalerOf(context)
                                              .scale(13) >
                                          21;
                                  final width = stacked
                                      ? constraints.maxWidth
                                      : (constraints.maxWidth - 12) / 2;
                                  return Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      for (final side
                                          in VerificationPhotoSide.values)
                                        SizedBox(
                                          width: width,
                                          child: _PhotoTile(
                                            side: side,
                                            photo: controller.photo(side),
                                            accent: accent,
                                            onTap: controller.busy
                                                ? null
                                                : () => controller.selectPhoto(
                                                    side,
                                                  ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                              if (controller.busy) ...[
                                const SizedBox(height: 12),
                                const LinearProgressIndicator(minHeight: 2),
                              ],
                              if (controller.error != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  controller.error!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              Material(
                                color: accent.withValues(alpha: .07),
                                borderRadius: BorderRadius.circular(4),
                                child: InkWell(
                                  onTap: showHelp,
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        AppIcon(
                                          AppIcons.about,
                                          size: 15,
                                          color: accent,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '请上传本人有效的二代身份证',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: accent,
                                            ),
                                          ),
                                        ),
                                        AppIcon(
                                          AppIcons.forward,
                                          size: 14,
                                          color: accent,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 20, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 32,
                              height: 44,
                              child: Checkbox(
                                key: const ValueKey(
                                  'developer-verification-consent',
                                ),
                                value: controller.agreed,
                                activeColor: accent,
                                shape: const CircleBorder(),
                                side: BorderSide(color: accent, width: 1.2),
                                semanticLabel: '同意身份信息使用说明',
                                onChanged: controller.busy
                                    ? null
                                    : (value) =>
                                          controller.setAgreed(value ?? false),
                              ),
                            ),
                            Expanded(
                              child: Wrap(
                                key: const ValueKey(
                                  'developer-verification-consent-label',
                                ),
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    '请仔细阅读并同意',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.colors.muted,
                                    ),
                                  ),
                                  Semantics(
                                    link: true,
                                    child: InkWell(
                                      key: const ValueKey(
                                        'developer-verification-usage',
                                      ),
                                      onTap: showUsage,
                                      child: Text(
                                        '《身份信息使用说明》',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: accent,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: FilledButton(
                          key: const ValueKey('developer-verification-next'),
                          onPressed: controller.canContinue ? next : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: context.isDark
                                ? context.colors.canvas
                                : Colors.white,
                            disabledBackgroundColor: context.isDark
                                ? context.colors.border
                                : const Color(0xFFD2D4D8),
                            disabledForegroundColor: context.isDark
                                ? context.colors.muted
                                : Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 20,
                            ),
                            shape: const StadiumBorder(),
                          ),
                          child: const Text(
                            '完成，下一步',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 48, 12, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '上传须知',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: context.colors.ink,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: showHelp,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '更多帮助',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: context.colors.muted,
                                    ),
                                  ),
                                  AppIcon(
                                    AppIcons.forward,
                                    size: 12,
                                    color: context.colors.muted,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _PhotoExamples(accent: accent),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    ),
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.side,
    required this.photo,
    required this.accent,
    required this.onTap,
  });
  final VerificationPhotoSide side;
  final ui.Image? photo;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final back = side == VerificationPhotoSide.emblem;
    final label = back ? '国徽面' : '人像面';
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: '${photo == null ? '上传' : '重新选择'}$label',
      excludeSemantics: true,
      child: Material(
        color: context.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: accent.withValues(alpha: .22)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('developer-photo-${side.name}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              children: [
                SizedBox(
                  height: 82,
                  width: double.infinity,
                  child: photo != null
                      ? RawImage(image: photo, fit: BoxFit.contain)
                      : Stack(
                          alignment: Alignment.center,
                          children: [
                            Opacity(
                              opacity: .25,
                              child: _IdentityArtwork(
                                back: back,
                                color: accent,
                              ),
                            ),
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withValues(alpha: .18),
                                    blurRadius: 10,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: AppIcon(
                                  AppIcons.avatarUpload,
                                  size: 20,
                                  color: context.isDark
                                      ? context.colors.canvas
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${photo == null ? '上传' : '重新选择'}$label',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: accent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoExamples extends StatelessWidget {
  const _PhotoExamples({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth < 290 ||
              MediaQuery.textScalerOf(context).scale(11) > 17
          ? 2
          : 4;
      final width = (constraints.maxWidth - 10 * (columns - 1)) / columns;
      const labels = ['标准拍摄', '边框缺失', '照片模糊', '闪光强烈'];
      return Wrap(
        spacing: 10,
        runSpacing: 16,
        children: [
          for (var i = 0; i < labels.length; i++)
            SizedBox(
              width: width,
              child: Column(
                children: [
                  Container(
                    height: 62,
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Transform.translate(
                              offset: i == 1
                                  ? const Offset(17, 0)
                                  : Offset.zero,
                              child: ImageFiltered(
                                imageFilter: ui.ImageFilter.blur(
                                  sigmaX: i == 2 ? 2 : 0,
                                  sigmaY: i == 2 ? 2 : 0,
                                ),
                                child: _IdentityArtwork(
                                  color: context.colors.muted.withValues(
                                    alpha: .65,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (i == 3)
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  colors: [
                                    context.colors.surface,
                                    context.colors.surface.withValues(alpha: 0),
                                  ],
                                  radius: .8,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: AppIcon(
                          i == 0 ? AppIcons.confirm : AppIcons.close,
                          size: 11,
                          color: i == 0
                              ? accent
                              : Theme.of(context).colorScheme.error
                                    .withValues(alpha: .6),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          labels[i],
                          style: TextStyle(
                            fontSize: 10,
                            color: context.colors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

class _IdentityArtwork extends StatelessWidget {
  const _IdentityArtwork({required this.color, this.back = false});
  final Color color;
  final bool back;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _IdentityPainter(color, back),
    child: const SizedBox.expand(),
  );
}

class _IdentityPainter extends CustomPainter {
  const _IdentityPainter(this.color, this.back);
  final Color color;
  final bool back;

  @override
  void paint(Canvas canvas, Size size) {
    final width = math.min(size.width, size.height * 1.58);
    final height = width / 1.58;
    canvas.save();
    canvas.translate((size.width - width) / 2, (size.height - height) / 2);
    canvas.scale(width / 158, height / 100);
    final paint = Paint()..color = color;
    final bounds = RRect.fromRectAndRadius(
      const Rect.fromLTWH(1, 1, 156, 98),
      const Radius.circular(5),
    );
    canvas.drawRRect(bounds, Paint()..color = color.withValues(alpha: .06));
    canvas.drawRRect(
      bounds,
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    paint.style = PaintingStyle.fill;
    if (back) {
      canvas.drawCircle(const Offset(79, 25), 10, paint);
      for (final (x, y, w) in [
        (45.0, 44.0, 68.0),
        (34.0, 57.0, 90.0),
        (34.0, 72.0, 90.0),
      ]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, w, 4),
            const Radius.circular(2),
          ),
          paint,
        );
      }
    } else {
      canvas.drawCircle(const Offset(123, 32), 11, paint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(106, 46, 34, 24),
          const Radius.circular(8),
        ),
        paint,
      );
      for (final (y, w) in [
        (20.0, 40.0),
        (34.0, 62.0),
        (48.0, 47.0),
        (62.0, 65.0),
        (81.0, 116.0),
      ]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(17, y, w, 4),
            const Radius.circular(2),
          ),
          paint,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IdentityPainter oldDelegate) =>
      color != oldDelegate.color || back != oldDelegate.back;
}
