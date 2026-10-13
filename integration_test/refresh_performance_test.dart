import 'dart:async';
import 'dart:ui' show FrameTiming;
import 'dart:math' as math;

import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/playful_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Compare refresh pull and flight frame times', (tester) async {
    for (final legacy in [true, false]) {
      var calls = 0;
      final list = ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: 50,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('作者', style: TextStyle(fontSize: 11)),
                const SizedBox(height: 12),
                Text(
                  '文章内容 $i',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '这里用于验证列表在下拉刷新时的帧耗时。',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    Icon(Icons.favorite_border),
                    SizedBox(width: 30),
                    Icon(Icons.chat_bubble_outline),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      Future<void> refresh() async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 900));
      }

      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: legacy
                ? LegacyRefresh(onRefresh: refresh, child: list)
                : PlayfulRefresh(onRefresh: refresh, child: list),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await Future<void>.delayed(const Duration(seconds: 2));
      final timings = <FrameTiming>[];
      void collect(List<FrameTiming> frames) => timings.addAll(frames);
      binding.addTimingsCallback(collect);
      try {
        for (var n = 0; n < 5; n++) {
          final gesture = await tester.startGesture(const Offset(180, 260));
          for (var step = 0; step < 24; step++) {
            await gesture.moveBy(const Offset(0, 14));
            await tester.pump(const Duration(milliseconds: 16));
          }
          await gesture.up();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 180));
          for (var frame = 0; frame < 100; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          await tester.pumpAndSettle();
        }
        await Future<void>.delayed(const Duration(seconds: 2));
      } finally {
        binding.removeTimingsCallback(collect);
      }
      expect(timings, isNotEmpty);
      Map<String, Object> summarize(List<double> values) {
        values.sort();
        return {
          'average_ms': values.reduce((a, b) => a + b) / values.length,
          'p90_ms':
              values[(values.length * .9).floor().clamp(0, values.length - 1)],
          'max_ms': values.last,
          'over_8ms': values.where((v) => v > 8.33).length,
          'over_16ms': values.where((v) => v > 16.67).length,
        };
      }

      binding.reportData ??= {};
      binding.reportData![legacy ? 'refresh_before' : 'refresh_after'] = {
        'frames': timings.length,
        'build': summarize(
          timings.map((f) => f.buildDuration.inMicroseconds / 1000).toList(),
        ),
        'raster': summarize(
          timings.map((f) => f.rasterDuration.inMicroseconds / 1000).toList(),
        ),
      };
      expect(calls, 5);
      expect(tester.takeException(), isNull);
    }
  });
}

/// Keeps Flutter's edge detection and refresh gestures, with a small paper flight.
class LegacyRefresh extends StatefulWidget {
  const LegacyRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.hasError,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final bool Function()? hasError;

  @override
  State<LegacyRefresh> createState() => _LegacyRefreshState();
}

class _LegacyRefreshState extends State<LegacyRefresh>
    with TickerProviderStateMixin {
  late final _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final _flight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  RefreshIndicatorStatus? _status;
  Timer? _dismiss;
  double _drag = 0;
  bool _failed = false;
  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  @override
  void dispose() {
    _dismiss?.cancel();
    _flight.dispose();
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
      _dismiss?.cancel();
      _dismiss = Timer(const Duration(milliseconds: 550), _hide);
    } else if (status == RefreshIndicatorStatus.canceled) {
      _hide();
    }
    setState(() => _status = status);
  }

  void _hide() {
    if (!mounted) return;
    _reveal.animateTo(
      0,
      duration: Duration(milliseconds: _reduceMotion ? 0 : 220),
    );
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _status = RefreshIndicatorStatus.refresh);
    if (!_reduceMotion) _flight.repeat();
    try {
      await widget.onRefresh();
      if (mounted) setState(() => _failed = widget.hasError?.call() ?? false);
    } catch (_) {
      // Keep the gesture usable after a failed request; never expose raw URLs.
      if (mounted) setState(() => _failed = true);
    }
  }

  bool _scroll(ScrollNotification notification) {
    if (notification.depth != 0 ||
        axisDirectionToAxis(notification.metrics.axisDirection) !=
            Axis.vertical) {
      return false;
    }
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
    if (threshold > 0) _reveal.value = (_drag / threshold).clamp(0.0, 1.0);
    return false;
  }

  String get _label => switch (_status) {
    RefreshIndicatorStatus.armed || RefreshIndicatorStatus.snap => '松开刷新',
    RefreshIndicatorStatus.refresh => '正在刷新',
    RefreshIndicatorStatus.done => _failed ? '刷新失败' : '已更新',
    _ => '下拉刷新',
  };

  @override
  Widget build(
    BuildContext context,
  ) => NotificationListener<ScrollNotification>(
    onNotification: _scroll,
    child: RefreshIndicator.noSpinner(
      onRefresh: _refresh,
      onStatusChange: _change,
      semanticsLabel: '刷新内容',
      child: AnimatedBuilder(
        animation: _reveal,
        child: RepaintBoundary(child: widget.child),
        builder: (context, child) => Stack(
          fit: StackFit.passthrough,
          clipBehavior: Clip.hardEdge,
          children: [
            Transform.translate(
              offset: Offset(0, 62 * Curves.easeOut.transform(_reveal.value)),
              child: child,
            ),
            if (_reveal.value > 0)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: _reveal.value,
                    child: SizedBox(
                      height: 62,
                      child: Semantics(
                        liveRegion: _status == RefreshIndicatorStatus.done,
                        label: _label,
                        child: ExcludeSemantics(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              RepaintBoundary(
                                child: CustomPaint(
                                  size: const Size(48, 44),
                                  painter: _PaperFlight(
                                    _flight,
                                    progress: _reveal.value,
                                    flying:
                                        _status ==
                                        RefreshIndicatorStatus.refresh,
                                    done:
                                        _status == RefreshIndicatorStatus.done,
                                    failed: _failed,
                                    reduceMotion: _reduceMotion,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _label,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: muted,
                                  fontWeight: FontWeight.w500,
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
        ),
      ),
    ),
  );
}

class _PaperFlight extends CustomPainter {
  _PaperFlight(
    this.flight, {
    required this.progress,
    required this.flying,
    required this.done,
    required this.failed,
    required this.reduceMotion,
  }) : super(repaint: flight);
  final Animation<double> flight;
  final double progress;
  final bool flying, done, failed, reduceMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = reduceMotion ? 0.0 : flight.value * math.pi * 2;
    final paint = Paint()
      ..color = blue
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.translate(size.width / 2, size.height / 2);
    if (done) {
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2.2;
      if (failed) {
        canvas.drawLine(const Offset(0, -7), const Offset(0, 2), paint);
        canvas.drawCircle(const Offset(0, 7), 1, paint);
      } else {
        canvas.drawPath(
          Path()
            ..moveTo(-8, 0)
            ..lineTo(-2, 6)
            ..lineTo(10, -7),
          paint,
        );
        for (var i = 0; i < 4; i++) {
          final angle = i * math.pi / 2 + .3;
          canvas.drawCircle(
            Offset(math.cos(angle) * 18, math.sin(angle) * 16),
            1.3,
            paint..color = blue.withValues(alpha: .35),
          );
        }
      }
      return;
    }
    if (flying) {
      for (var i = 0; i < 3; i++) {
        canvas.drawCircle(
          Offset(-17 - i * 4.0, 5 + math.sin(phase - i * .5) * 2),
          1.3,
          paint..color = blue.withValues(alpha: .3 - i * .07),
        );
      }
    }
    canvas.translate(0, flying ? math.sin(phase) * 3 : (1 - progress) * 5);
    canvas.rotate(flying ? math.sin(phase) * .12 : (1 - progress) * .4);
    final paper = Path()
      ..moveTo(-14, -5)
      ..lineTo(15, -12)
      ..lineTo(5, 14)
      ..lineTo(-2, 4)
      ..close();
    canvas.drawPath(
      paper,
      paint
        ..style = PaintingStyle.fill
        ..color = blue.withValues(alpha: .1),
    );
    canvas.drawPath(
      paper,
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = blue,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-14, -5)
        ..lineTo(-2, 4)
        ..lineTo(15, -12)
        ..moveTo(-2, 4)
        ..lineTo(-3, 11)
        ..lineTo(1, 8),
      paint,
    );
  }

  @override
  bool shouldRepaint(_PaperFlight old) =>
      old.progress != progress ||
      old.flying != flying ||
      old.done != done ||
      old.failed != failed ||
      old.reduceMotion != reduceMotion;
}
