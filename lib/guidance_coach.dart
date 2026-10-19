import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'design.dart';
import 'guidance_flow.dart';

/// Taps and holds reach real controls; background dragging and wheel scrolling
/// are blocked while the caption is visible.
class GuidanceCoach extends StatefulWidget {
  const GuidanceCoach({
    super.key,
    required this.step,
    required this.rect,
    required this.index,
    required this.total,
    required this.onSkip,
    this.editingRect,
    this.onAcknowledge,
    this.onVisibilityChanged,
  });
  final GuidanceStep step;
  final Rect rect;
  final Rect? editingRect;
  final int index, total;
  final VoidCallback onSkip;
  final VoidCallback? onAcknowledge;
  final ValueChanged<bool>? onVisibilityChanged;

  @override
  State<GuidanceCoach> createState() => _GuidanceCoachState();
}

class _GuidanceCoachState extends State<GuidanceCoach>
    with SingleTickerProviderStateMixin {
  late final cue = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  bool? captionVisible;

  void reportVisibility(bool visible) {
    if (captionVisible == visible) return;
    captionVisible = visible;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && captionVisible == visible) {
        widget.onVisibilityChanged?.call(visible);
      }
    });
  }

  bool get reduceMotion =>
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion) {
      cue.stop();
      cue.value = 1;
    } else if (cue.value == 0) {
      cue.forward();
    }
  }

  @override
  void didUpdateWidget(GuidanceCoach oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step.id != widget.step.id) {
      if (reduceMotion) {
        cue.value = 1;
      } else {
        cue.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    cue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final screen = Offset.zero & constraints.biggest;
        final safeTop = media.padding.top + 10;
        final safeBottom = math.max(
          safeTop + 1,
          screen.height -
              math.max(media.viewInsets.bottom, media.padding.bottom) -
              10,
        );
        final rect = widget.rect.inflate(5).intersect(screen);
        final editingRect = widget.editingRect?.inflate(5).intersect(screen);
        final protected = editingRect == null || editingRect.isEmpty
            ? rect
            : rect.expandToInclude(editingRect);
        final before = math.max(0.0, protected.top - safeTop - 12);
        final after = math.max(0.0, safeBottom - protected.bottom - 12);
        final above = before > after;
        final room = math.max(before, after);
        final cardHeight = math.min(
          260.0,
          editingRect != null ||
                  widget.step.gesture != GuidanceGesture.read ||
                  room >= 108
              ? room
              : (safeBottom - safeTop) * .5,
        );
        // Let the real editor use the viewport when the keyboard leaves no
        // space for a legible caption. It reappears when space is available.
        reportVisibility(cardHeight >= 48);
        if (cardHeight < 48) return const SizedBox.shrink();
        final compact = cardHeight < 150;
        final cardTop =
            (above ? protected.top - cardHeight - 12 : protected.bottom + 12)
                .clamp(safeTop, math.max(safeTop, safeBottom - cardHeight))
                .toDouble();
        final duration = reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 300);
        return Stack(
          children: [
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    GestureBinding.instance.pointerSignalResolver.register(
                      event,
                      (_) {},
                    );
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanUpdate: (_) {},
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: TweenAnimationBuilder<Rect?>(
                  tween: RectTween(begin: rect, end: rect),
                  duration: duration,
                  curve: Curves.easeInOutCubic,
                  builder: (_, value, _) => Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        painter: GuidanceSpotlightPainter(
                          value ?? rect,
                          editingRect: editingRect,
                        ),
                      ),
                      if (!reduceMotion &&
                          widget.step.gesture != GuidanceGesture.read)
                        AnimatedBuilder(
                          animation: cue,
                          builder: (_, _) => CustomPaint(
                            painter: _GesturePainter(
                              value ?? rect,
                              widget.step.gesture,
                              cue.value,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: duration,
              curve: Curves.easeInOutCubic,
              left: 14,
              right: 14,
              top: cardTop,
              child: Align(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 460,
                    maxHeight: math.max(1, cardHeight),
                  ),
                  child: Material(
                    key: const ValueKey('guidance-coach-card'),
                    elevation: 5,
                    shadowColor: const Color(0x22202C41),
                    borderRadius: BorderRadius.circular(18),
                    color: context.colors.surface,
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                      child: Semantics(
                        liveRegion: true,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!compact)
                              Row(
                                children: [
                                  AnimatedBuilder(
                                    animation: cue,
                                    builder: (_, _) => Transform.rotate(
                                      angle: reduceMotion
                                          ? 0
                                          : math.sin(cue.value * math.pi * 2) *
                                                .1,
                                      child: const CustomPaint(
                                        size: Size.square(30),
                                        painter: _PaperPainter(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.total == 1
                                          ? '操作提示'
                                          : '操作提示 ${widget.index + 1}/${widget.total}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: (context.isDark
                                            ? context.colors.muted
                                            : Color(0xFF63718A)),
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: widget.onSkip,
                                    child: const Text('暂不提示'),
                                  ),
                                ],
                              ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (compact)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          widget.step.title,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: context.colors.ink,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: '暂不提示',
                                        onPressed: widget.onSkip,
                                        icon: const Icon(Icons.close, size: 18),
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ],
                                  )
                                else
                                  Text(
                                    widget.step.title,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: context.colors.ink,
                                    ),
                                  ),
                                if (!compact) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    widget.step.description,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.6,
                                      color: (context.isDark
                                          ? context.colors.muted
                                          : Color(0xFF53627A)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (!compact || widget.onAcknowledge != null)
                              const SizedBox(height: 6),
                            if (widget.onAcknowledge != null)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: widget.onAcknowledge,
                                  child: Text(
                                    widget.step.acknowledgeLabel ??
                                        (widget.step.optional ? '暂不填写' : '知道了'),
                                  ),
                                ),
                              )
                            else if (!compact)
                              Text(
                                switch (widget.step.gesture) {
                                  GuidanceGesture.type => '直接在当前输入框填写，提示会自动继续',
                                  GuidanceGesture.hold => '按住高亮文字，对照后松开',
                                  _ => '直接操作高亮处，提示会自动继续',
                                },
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.colors.accent,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class GuidanceSpotlightPainter extends CustomPainter {
  const GuidanceSpotlightPainter(this.rect, {this.editingRect});
  final Rect rect;
  final Rect? editingRect;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    var cutout = Path();
    if (!rect.isEmpty) {
      cutout.addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(11)));
    }
    if (editingRect != null && !editingRect!.isEmpty) {
      cutout = Path.combine(
        PathOperation.union,
        cutout,
        Path()..addRRect(
          RRect.fromRectAndRadius(editingRect!, const Radius.circular(11)),
        ),
      );
    }
    path.addPath(cutout, Offset.zero);
    canvas.drawPath(path, Paint()..color = const Color(0x450F2345));
    if (!rect.isEmpty) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(11)),
        Paint()
          ..color = blue.withValues(alpha: .65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(GuidanceSpotlightPainter oldDelegate) =>
      oldDelegate.rect != rect || oldDelegate.editingRect != editingRect;
}

class _GesturePainter extends CustomPainter {
  const _GesturePainter(this.rect, this.gesture, this.t);
  final Rect rect;
  final GuidanceGesture gesture;
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1 || rect.isEmpty) return;
    final end = gesture == GuidanceGesture.type
        ? Offset(rect.left + math.min(40, rect.width / 2), rect.center.dy)
        : rect.center;
    final position = Offset.lerp(
      end.translate(15, 18),
      end,
      Curves.easeOutCubic.transform((t * 3).clamp(0, 1)),
    )!;
    final pulse = ((t - .3) / .7).clamp(0.0, 1.0);
    final pressing = (t > .3 && t < .8) ? 2.0 : 0.0;
    canvas.drawCircle(
      position,
      9 + pulse * 22,
      Paint()
        ..color = blue.withValues(alpha: (1 - pulse) * .4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    if (gesture == GuidanceGesture.hold) {
      canvas.drawArc(
        Rect.fromCircle(center: position, radius: 18),
        -math.pi / 2,
        pulse * math.pi * 2,
        false,
        Paint()
          ..color = blue
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 3,
      );
    } else if (gesture == GuidanceGesture.type) {
      // Three light keystrokes explain typing without inserting sample text.
      for (var index = 0; index < 3; index++) {
        final progress = (pulse * 3 - index).clamp(0.0, 1.0);
        canvas.drawCircle(
          position.translate(18 + index * 9, -10),
          2,
          Paint()..color = blue.withValues(alpha: progress * (1 - pulse)),
        );
      }
    }
    canvas.drawCircle(position, 7, Paint()..color = Colors.white);
    canvas.drawCircle(position, 4, Paint()..color = blue);
    canvas.save();
    canvas.translate(position.dx, position.dy + 2 + pressing);
    final hand = Path()
      ..moveTo(-3, 18)
      ..lineTo(-3, 3)
      ..cubicTo(-3, -2, 4, -2, 4, 3)
      ..lineTo(4, 12)
      ..cubicTo(4, 8, 11, 9, 11, 13)
      ..cubicTo(11, 10, 18, 11, 18, 15)
      ..cubicTo(18, 12, 24, 14, 24, 18)
      ..lineTo(24, 25)
      ..quadraticBezierTo(24, 36, 12, 37)
      ..quadraticBezierTo(7, 36, 3, 31)
      ..lineTo(-6, 22)
      ..quadraticBezierTo(-10, 17, -6, 15)
      ..quadraticBezierTo(-4, 14, -3, 18)
      ..close();
    canvas.drawPath(hand, Paint()..color = const Color(0xFFFFE0BA));
    canvas.drawPath(
      hand,
      Paint()
        ..color = const Color(0xFFB88750)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GesturePainter oldDelegate) =>
      oldDelegate.rect != rect ||
      oldDelegate.t != t ||
      oldDelegate.gesture != gesture;
}

class _PaperPainter extends CustomPainter {
  const _PaperPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 40);
    final p = Paint();
    canvas.drawCircle(
      const Offset(20, 20),
      20,
      p..color = const Color(0xFFE5EDFF),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(10, 5, 23, 30),
        const Radius.circular(5),
      ),
      p..color = Colors.white,
    );
    canvas.drawCircle(const Offset(17, 18), 1.5, p..color = blue);
    canvas.drawCircle(const Offset(26, 18), 1.5, p);
    canvas.drawArc(
      const Rect.fromLTWH(17, 21, 9, 6),
      0,
      math.pi,
      false,
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7,
    );
  }

  @override
  bool shouldRepaint(_PaperPainter oldDelegate) => false;
}
