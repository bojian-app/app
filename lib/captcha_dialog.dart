import 'app_icons.dart';

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'api/bojian_api.dart';
import 'api/generated/auth.pb.dart' as auth;
import 'app_store.dart';
import 'design.dart';

class SmsRequestOutcome {
  const SmsRequestOutcome.accepted(auth.SMSResponse value)
    : response = value,
      error = null;
  const SmsRequestOutcome.failed(Object value) : error = value, response = null;

  final auth.SMSResponse? response;
  final Object? error;
}

class CaptchaDialog extends StatefulWidget {
  const CaptchaDialog({
    super.key,
    required this.store,
    required this.challenge,
    required this.phone,
    this.onSendSMS,
  });
  final AppStore store;
  final CaptchaChallenge challenge;
  final String phone;
  final Future<auth.SMSResponse> Function(String captchaToken)? onSendSMS;
  @override
  State<CaptchaDialog> createState() => _CaptchaDialogState();
}

typedef PuzzlePictures = ({
  Uint8List master,
  Uint8List piece,
  double width,
  double height,
  double pieceWidth,
  double pieceHeight,
});

class _CaptchaDialogState extends State<CaptchaDialog> {
  late final int accountEpoch;
  late CaptchaChallenge challenge = widget.challenge;
  double position = 0;
  bool busy = false;
  String? error;
  late Future<PuzzlePictures> pictures = decode();
  bool get current => mounted && widget.store.epoch == accountEpoch;

  @override
  void initState() {
    super.initState();
    accountEpoch = widget.store.epoch;
  }

  Future<PuzzlePictures> decode() async {
    final master = UriData.parse(challenge.masterImageDataUrl).contentAsBytes();
    final piece = UriData.parse(challenge.thumbImageDataUrl).contentAsBytes();
    final m = await ui.instantiateImageCodec(master);
    try {
      final t = await ui.instantiateImageCodec(piece);
      try {
        final mi = (await m.getNextFrame()).image;
        try {
          final ti = (await t.getNextFrame()).image;
          try {
            return (
              master: master,
              piece: piece,
              width: mi.width.toDouble(),
              height: mi.height.toDouble(),
              pieceWidth: ti.width.toDouble(),
              pieceHeight: ti.height.toDouble(),
            );
          } finally {
            ti.dispose();
          }
        } finally {
          mi.dispose();
        }
      } finally {
        t.dispose();
      }
    } finally {
      m.dispose();
    }
  }

  Future<void> reload({bool preserveError = false}) async {
    if (!current) return;
    setState(() {
      busy = true;
      if (!preserveError) error = null;
    });
    try {
      final next = await widget.store.api.createCaptcha(widget.store.headers);
      if (!current) return;
      setState(() {
        challenge = next;
        position = 0;
        pictures = decode();
      });
    } catch (e) {
      if (current) setState(() => error = '$e');
    } finally {
      if (current) setState(() => busy = false);
    }
  }

  Future<void> verify() async {
    if (busy || position <= 0 || !current) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final v = await widget.store.api.verifyCaptcha(
        challenge.id,
        position.round(),
        widget.store.headers,
      );
      if (!mounted || widget.store.epoch != accountEpoch) return;
      try {
        final result =
            await (widget.onSendSMS?.call(v.captchaToken) ??
                widget.store.api.sendSMS(
                  widget.phone,
                  v.captchaToken,
                  widget.store.headers,
                ));
        if (mounted && current) {
          Navigator.pop(context, SmsRequestOutcome.accepted(result));
        }
      } catch (e) {
        if (mounted && current) {
          Navigator.pop(context, SmsRequestOutcome.failed(e));
        }
      }
    } catch (e) {
      if (!current) return;
      setState(
        () => error = e is ApiFailure && e.code == 'CAPTCHA_INVALID'
            ? '还差一点，请重新拖动拼图'
            : '$e',
      );
      // Challenges are consumed once, so a failed attempt needs a fresh puzzle.
      await reload(preserveError: true);
    } finally {
      if (current) setState(() => busy = false);
    }
  }

  Widget puzzle(PuzzlePictures p, double maxHeight) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = math.min(
        constraints.maxWidth / p.width,
        maxHeight / p.height,
      );
      return Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            key: const ValueKey('captcha-image'),
            width: p.width * scale,
            height: p.height * scale,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.memory(
                    p.master,
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                  ),
                ),
                Positioned(
                  left: position * scale,
                  top: challenge.pieceY * scale,
                  child: Image.memory(
                    p.piece,
                    width: p.pieceWidth * scale,
                    height: p.pieceHeight * scale,
                    gaplessPlayback: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget controls({required bool compact}) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (compact) ...[
        Text(
          '拖动滑块，将拼图移到缺口处',
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: context.colors.muted,
          ),
        ),
        const SizedBox(height: 12),
      ],
      Semantics(
        label: '拖动滑块完成拼图',
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 36,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 20),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
            activeTrackColor: blue.withValues(alpha: .15),
            inactiveTrackColor: (context.isDark
                ? context.colors.accentSoft
                : const Color(0xFFF0F3F8)),
            thumbColor: blue,
          ),
          child: Slider(
            key: const ValueKey('captcha-slider'),
            value: position,
            max: challenge.maxX.toDouble(),
            onChanged: busy ? null : (v) => setState(() => position = v),
            onChangeEnd: busy ? null : (_) => verify(),
          ),
        ),
      ),
      const SizedBox(height: 8),
      if (busy)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text(
              '正在验证…',
              style: TextStyle(fontSize: 12, color: context.colors.muted),
            ),
          ],
        )
      else
        Text(
          '对齐后松开滑块，即可获取验证码',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            height: 1.5,
            color: context.colors.muted,
          ),
        ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            error!,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.orientationOf(context) == Orientation.landscape &&
        MediaQuery.sizeOf(context).width >= 600;
    return PopScope(
      canPop: !busy,
      child: Dialog(
        backgroundColor: context.colors.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: 24,
          vertical: compact ? 12 : 24,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SizedBox(
          width: compact ? 640 : 368,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxImageHeight = compact
                  ? math.max(80.0, constraints.maxHeight - 92)
                  : 220.0;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '安全验证',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: context.colors.ink,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '换一张',
                          onPressed: busy ? null : reload,
                          icon: const AppIcon(AppIcons.refresh),
                        ),
                        TextButton(
                          onPressed: busy ? null : () => Navigator.pop(context),
                          child: const Text('取消'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<PuzzlePictures>(
                      future: pictures,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('图片加载失败，请点击右上角换一张'),
                          );
                        }
                        final p = snapshot.data;
                        if (p == null) {
                          return SizedBox(
                            height: math.min(160, maxImageHeight),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        if (compact) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 3,
                                child: puzzle(p, maxImageHeight),
                              ),
                              const SizedBox(width: 24),
                              Expanded(flex: 2, child: controls(compact: true)),
                            ],
                          );
                        }
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '拖动滑块，将拼图移到缺口处',
                              style: TextStyle(
                                fontSize: 13,
                                color: context.colors.muted,
                              ),
                            ),
                            const SizedBox(height: 16),
                            puzzle(p, maxImageHeight),
                            const SizedBox(height: 12),
                            controls(compact: false),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
