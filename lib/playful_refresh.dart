import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design.dart';

/// Keeps Flutter's edge detection and refresh gestures, with a small paper flight.
class PlayfulRefresh extends StatefulWidget {
  const PlayfulRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.hasError,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final bool Function()? hasError;

  @override
  State<PlayfulRefresh> createState() => _PlayfulRefreshState();
}

class _PlayfulRefreshState extends State<PlayfulRefresh>
    with TickerProviderStateMixin {
  late final _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final _flight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final _landing = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  RefreshIndicatorStatus? _status;
  Timer? _dismiss;
  double _drag = 0;
  bool _failed = false;
  bool _visible = false;
  int? _pointer;
  bool _ownsScroll = false;
  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    _reveal.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && mounted && _visible) {
        setState(() => _visible = false);
      }
    });
  }

  @override
  void dispose() {
    _dismiss?.cancel();
    _flight.dispose();
    _landing.dispose();
    _reveal.dispose();
    super.dispose();
  }

  void _change(RefreshIndicatorStatus? status) {
    if (!mounted) return;
    if (status == RefreshIndicatorStatus.drag) {
      _dismiss?.cancel();
      _drag = 0;
      _failed = false;
      _flight.stop();
      _flight.value = 0;
      _landing.value = 0;
      _reveal.value = 0;
    } else if (status == RefreshIndicatorStatus.armed) {
      HapticFeedback.selectionClick();
    } else if (status == RefreshIndicatorStatus.snap) {
      _reveal.animateTo(
        1,
        duration: Duration(milliseconds: _reduceMotion ? 0 : 150),
      );
    } else if (status == RefreshIndicatorStatus.done) {
      _flight.stop();
      if (_reduceMotion) {
        _landing.value = 1;
      } else {
        _landing.forward(from: 0);
      }
      _dismiss?.cancel();
      _dismiss = Timer(const Duration(milliseconds: 320), _hide);
    } else if (status == RefreshIndicatorStatus.canceled) {
      _hide();
    }
    setState(() => _status = status);
  }

  void _hide() {
    if (!mounted) return;
    _reveal.animateBack(
      0,
      duration: Duration(milliseconds: _reduceMotion ? 0 : 360),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _status = RefreshIndicatorStatus.refresh);
    if (!_reduceMotion) _flight.repeat();
    final elapsed = Stopwatch()..start();
    try {
      await widget.onRefresh();
      if (mounted) setState(() => _failed = widget.hasError?.call() ?? false);
    } catch (_) {
      // Keep the gesture usable after a failed request; never expose raw URLs.
      if (mounted) setState(() => _failed = true);
    }
    // Data is already applied. Let a fast response finish the short launch
    // before landing, rather than cutting the scene off on its first frame.
    if (mounted && !_reduceMotion && elapsed.elapsedMilliseconds < 360) {
      await Future<void>.delayed(
        Duration(milliseconds: 360 - elapsed.elapsedMilliseconds),
      );
    }
  }

  bool _accept(ScrollNotification notification) {
    if (notification.depth != 0 ||
        axisDirectionToAxis(notification.metrics.axisDirection) !=
            Axis.vertical ||
        !TickerMode.valuesOf(context).enabled) {
      return false;
    }
    if (notification is ScrollStartNotification) {
      // NestedScrollView also notifies other attached tab positions.
      _ownsScroll = notification.dragDetails != null && _pointer != null;
    }
    return _ownsScroll;
  }

  void _endPointer(PointerEvent event) {
    if (_pointer == event.pointer) _pointer = null;
    // Keep ownership through ScrollEndNotification, which follows pointer-up.
  }

  bool _scroll(ScrollNotification notification) {
    if (notification.depth != 0 ||
        axisDirectionToAxis(notification.metrics.axisDirection) !=
            Axis.vertical) {
      return false;
    }
    if (notification is ScrollEndNotification) {
      _ownsScroll = false;
      return false;
    }
    if (!_ownsScroll) return false;
    final bottom = notification.metrics.axisDirection == AxisDirection.up;
    if (_status != RefreshIndicatorStatus.drag &&
        _status != RefreshIndicatorStatus.armed) {
      return false;
    }
    final sign = bottom ? 1.0 : -1.0;
    if (notification is ScrollUpdateNotification) {
      _drag += sign * (notification.scrollDelta ?? 0);
    }
    if (notification is OverscrollNotification) {
      _drag += sign * notification.overscroll;
    }
    final threshold = notification.metrics.viewportDimension / 6;
    if (threshold > 0) {
      final progress = (_drag / threshold).clamp(0.0, 1.0);
      if (progress > 0 && !_visible) setState(() => _visible = true);
      _reveal.value = progress;
    }
    return false;
  }

  String get _label => switch (_status) {
    RefreshIndicatorStatus.armed || RefreshIndicatorStatus.snap => '松开刷新',
    RefreshIndicatorStatus.refresh => '正在刷新',
    RefreshIndicatorStatus.done => _failed ? '刷新失败' : '已更新',
    _ => '下拉刷新',
  };

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (event) => _pointer ??= event.pointer,
    onPointerUp: _endPointer,
    onPointerCancel: _endPointer,
    child: NotificationListener<ScrollNotification>(
      onNotification: _scroll,
      child: RefreshIndicator.noSpinner(
        onRefresh: _refresh,
        onStatusChange: _change,
        semanticsLabel: '刷新内容',
        notificationPredicate: _accept,
        child: Stack(
          fit: StackFit.passthrough,
          clipBehavior: Clip.hardEdge,
          children: [
            Flow(
              delegate: _RefreshContentFlow(_reveal),
              children: [RepaintBoundary(child: widget.child)],
            ),
            if (_visible)
              Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: RepaintBoundary(
                      child: FadeTransition(
                        opacity: _reveal,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, -.3),
                            end: Offset.zero,
                          ).animate(_reveal),
                          child: Semantics(
                            liveRegion: _status == RefreshIndicatorStatus.done,
                            label: _label,
                            child: ExcludeSemantics(
                              child: CustomPaint(
                                size: const Size(120, 46),
                                painter: _PaperFlight(
                                  _flight,
                                  _reveal,
                                  _landing,
                                  flying:
                                      _status == RefreshIndicatorStatus.refresh,
                                  done: _status == RefreshIndicatorStatus.done,
                                  failed: _failed,
                                  reduceMotion: _reduceMotion,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Moves the cached list display layer in paint, without rebuilding or
/// relaying out the scrollable or its cells on every drag/animation frame.
class _RefreshContentFlow extends FlowDelegate {
  _RefreshContentFlow(this.reveal) : super(repaint: reveal);
  final Animation<double> reveal;

  @override
  void paintChildren(FlowPaintingContext context) {
    context.paintChild(
      0,
      transform: Matrix4.translationValues(
        0,
        58 * Curves.easeOutCubic.transform(reveal.value),
        0,
      ),
    );
  }

  @override
  bool shouldRepaint(_RefreshContentFlow old) => old.reveal != reveal;
}

/// The scene is paint-only and has a dedicated, small repaint boundary.
class _PaperFlight extends CustomPainter {
  _PaperFlight(
    this.flight,
    this.reveal,
    this.landing, {
    required this.flying,
    required this.done,
    required this.failed,
    required this.reduceMotion,
  }) : super(repaint: Listenable.merge([flight, reveal, landing]));
  final Animation<double> flight, reveal, landing;
  final bool flying, done, failed, reduceMotion;

  static const _sheet = [
    Offset(-11, -13),
    Offset(11, -13),
    Offset(11, 13),
    Offset(-11, 13),
  ];
  static const _plane = [
    Offset(-14, -5),
    Offset(15, -12),
    Offset(5, 14),
    Offset(-2, 4),
  ];

  Offset _position(double phase) =>
      Offset(29 * math.sin(phase), -6 * math.sin(phase * 2));

  @override
  void paint(Canvas canvas, Size size) {
    final phase = reduceMotion ? 0.0 : flight.value * math.pi * 2;
    final settle = done ? Curves.easeInOutCubic.transform(landing.value) : 0.0;
    final finishing = done && !failed;
    final paperOpacity = finishing
        ? 1 - Curves.easeInCubic.transform(landing.value)
        : 1.0;
    final fold = finishing
        ? 1.0
        : done
        ? 1 - settle
        : flying
        ? 1.0
        : Curves.easeInOut.transform(reveal.value);
    final position = flying || done
        ? _position(phase) * (1 - settle) +
              (finishing ? Offset(12 * settle, -5 * settle) : Offset.zero)
        : Offset(0, (1 - fold) * 4);
    final heading = flying || done
        ? math.atan2(-12 * math.cos(phase * 2), 29 * math.cos(phase)) + .67
        : .28 * fold;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.translate(size.width / 2, size.height / 2);

    // A soft, short ribbon follows the same continuous curve as the plane.
    if ((flying || done) && !reduceMotion) {
      for (var i = 12; i > 0; i--) {
        final a = _position(phase - i * .075);
        final b = _position(phase - (i - 1) * .075);
        canvas.drawLine(
          a,
          b,
          paint
            ..color = blue.withValues(
              alpha: (.04 + (12 - i) * .011) * (1 - settle),
            )
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
    }

    canvas.save();
    canvas.translate(position.dx, position.dy);
    final shortestHeading = math.atan2(math.sin(heading), math.cos(heading));
    canvas.rotate(shortestHeading * (1 - settle));
    // A 20 dp paper silhouette, rather than a large icon in a badge.
    canvas.scale(.65 * (finishing ? 1 - .12 * settle : 1));
    final points = List.generate(
      4,
      (i) => Offset.lerp(_sheet[i], _plane[i], fold)!,
    );
    final outline = Path()..moveTo(points[0].dx, points[0].dy);
    for (final point in points.skip(1)) {
      outline.lineTo(point.dx, point.dy);
    }
    outline.close();
    canvas.drawPath(
      outline,
      paint
        ..color = blue.withValues(alpha: .07 * paperOpacity)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      outline,
      paint
        ..color = blue.withValues(alpha: paperOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    if (fold > 0) {
      final crease = Path()
        ..moveTo(points[0].dx, points[0].dy)
        ..lineTo(points[3].dx, points[3].dy)
        ..lineTo(points[1].dx, points[1].dy);
      canvas.drawPath(
        crease,
        paint
          ..color = blue.withValues(alpha: fold * paperOpacity)
          ..strokeWidth = 1.5,
      );
    }
    if (done) {
      if (failed) {
        canvas.drawLine(
          const Offset(0, -5),
          const Offset(0, 1),
          paint
            ..color = muted.withValues(alpha: settle)
            ..strokeWidth = 1.8,
        );
        canvas.drawCircle(
          const Offset(0, 5),
          .8,
          paint..style = PaintingStyle.fill,
        );
      }
    } else if (fold < 1) {
      for (var i = 0; i < 3; i++) {
        canvas.drawLine(
          Offset(-6, -5 + i * 5),
          Offset(6, -5 + i * 5),
          paint
            ..color = blue.withValues(alpha: .35 * (1 - fold))
            ..strokeWidth = 1.4,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PaperFlight old) =>
      old.flying != flying ||
      old.done != done ||
      old.failed != failed ||
      old.reduceMotion != reduceMotion;
}
