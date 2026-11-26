import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'app_theme.dart';

/// Gently pulses its placeholder [child] while content loads; holds still when
/// the system asks for reduced motion.
class SkeletonPulse extends StatefulWidget {
  const SkeletonPulse({super.key, required this.child});
  final Widget child;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      controller
        ..stop()
        ..value = 1;
    } else if (!controller.isAnimating) {
      controller.repeat(reverse: true);
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: '正在加载',
    container: true,
    child: ExcludeSemantics(
      child: FadeTransition(
        opacity: Tween(
          begin: 0.45,
          end: 1.0,
        ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut)),
        child: widget.child,
      ),
    ),
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

/// One grey placeholder bar or shape.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 4,
  });
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: context.colors.inset,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Placeholder rows for a list that has nothing to show yet.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.count = 4});
  final int count;

  @override
  Widget build(BuildContext context) => SkeletonPulse(
    child: Column(
      key: const ValueKey('list-skeleton'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The rows carry their own bottom gap; keep clear of whatever is above.
        const SizedBox(height: 16),
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: i.isEven ? 160 : 120, height: 16),
                  const SizedBox(height: 10),
                  const SkeletonBox(width: 90, height: 12),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

/// Fills its parent while an image or preview is still arriving.
class SkeletonFill extends StatelessWidget {
  const SkeletonFill({super.key, this.radius = 0, this.color});
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) => SkeletonPulse(
    child: SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color ?? context.colors.inset,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    ),
  );
}

/// A fine dot matrix that breathes around two wandering focal points (after
/// LeiBox's "AI generating" motion). Full-area by default, so a page that has
/// nothing to pull-to-refresh yet is entirely covered by the grid. Full-area
/// loaders stay up for at least [LoadingHold.minimum] (see [LoadingGate]);
/// inline ones ([compact]) only show when the wait is noticeable.
class DotMatrixLoader extends StatefulWidget {
  const DotMatrixLoader({
    super.key,
    this.compact = false,
    this.base,
    this.active,
  });

  /// A band of fixed height inside a page, instead of the whole area.
  final bool compact;

  /// Resting and brightest dot colours; defaults follow the theme.
  final Color? base, active;

  @override
  State<DotMatrixLoader> createState() => _DotMatrixLoaderState();
}

class _DotMatrixLoaderState extends State<DotMatrixLoader>
    with SingleTickerProviderStateMixin {
  final time = ValueNotifier<double>(2200);
  late final Ticker ticker = createTicker(
    (elapsed) => time.value = 2200 + elapsed.inMicroseconds / 1000,
  );
  Timer? _timer;
  bool shown = false;

  @override
  void initState() {
    super.initState();
    // A full-area loader is always on screen (see [LoadingGate]); an inline
    // one only appears when the wait is long enough to need it.
    if (widget.compact) {
      _timer = Timer(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => shown = true);
      });
    } else {
      shown = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      ticker.stop();
    } else if (!ticker.isActive) {
      ticker.start();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    ticker.dispose();
    time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final matrix = Semantics(
      label: '正在加载',
      container: true,
      child: ExcludeSemantics(
        child: AnimatedOpacity(
          opacity: shown ? 1 : 0,
          duration: const Duration(milliseconds: 160),
          child: RepaintBoundary(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.hasBoundedWidth
                    ? constraints.maxWidth
                    : 320.0;
                final height = widget.compact
                    ? 132.0
                    : constraints.hasBoundedHeight
                    ? constraints.maxHeight
                    : 360.0;
                return CustomPaint(
                  key: const ValueKey('dot-matrix-loader'),
                  size: Size(width, height),
                  painter: _DotMatrixPainter(
                    time,
                    widget.base ??
                        (dark
                            ? const Color(0xFF2A313B)
                            : const Color(0xFFE4E4E7)),
                    widget.active ??
                        (dark
                            ? const Color(0xFF8A94A5)
                            : const Color(0xFF989898)),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    return widget.compact
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: matrix,
          )
        : SizedBox.expand(child: matrix);
  }
}

/// Port of the reference's 20x20 grid: dots 4 px at rest, up to ~7.8 px near a
/// focal point, 18 px apart; two focal points sweep ellipses across the area.
class _DotMatrixPainter extends CustomPainter {
  _DotMatrixPainter(this.time, this.base, this.active) : super(repaint: time);
  final ValueListenable<double> time;
  final Color base, active;
  final Paint _paint = Paint();

  static const pitch = 18.0;
  static const influence = 110.0;
  static const dot = 12.0;
  static const restScale = .333;
  static const peakScale = .65;

  @override
  void paint(Canvas canvas, Size size) {
    final s = time.value * .0012;
    final centerX = size.width / 2, centerY = size.height / 2;
    // (x, y, weight) of the two focal points; the second one also breathes.
    final focal = [
      (
        math.sin(s * .7) * size.width * .32,
        math.cos(s * 1.1) * size.height * .22,
        1.0,
      ),
      (
        math.sin(s * -1.2 + 2) * size.width * .26,
        math.cos(s * .8 + 1.5) * size.height * .30,
        (math.sin(s * .35) + 1) / 2,
      ),
    ];
    final cols = math.max(1, (size.width / pitch).floor());
    final rows = math.max(1, (size.height / pitch).floor());
    final startX = (size.width - (cols - 1) * pitch) / 2;
    final startY = (size.height - (rows - 1) * pitch) / 2;
    for (var row = 0; row < rows; row++) {
      final y = startY + row * pitch;
      for (var col = 0; col < cols; col++) {
        final x = startX + col * pitch;
        var e = 0.0;
        for (final (fx, fy, weight) in focal) {
          final dx = centerX + fx - x, dy = centerY + fy - y;
          final distance = math.sqrt(dx * dx + dy * dy);
          if (distance < influence) {
            e += math.pow(1 - distance / influence, 1.4) * weight;
          }
        }
        e = math.min(1, e);
        final scale = e > .01
            ? restScale + (peakScale - restScale) * e
            : restScale;
        _paint.color = e > .01 ? Color.lerp(base, active, e)! : base;
        canvas.drawCircle(Offset(x, y), dot * scale / 2, _paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotMatrixPainter oldDelegate) =>
      oldDelegate.base != base || oldDelegate.active != active;
}

/// Keeps a loading view on screen for at least [minimum], so a quick response
/// never makes it flash.
class LoadingHold {
  LoadingHold(
    this.onChange, {
    this.minimum = const Duration(milliseconds: 300),
  });

  static const defaultMinimum = Duration(milliseconds: 300);

  /// Called when the hold ends and the owner must rebuild.
  final VoidCallback onChange;
  final Duration minimum;
  DateTime? _since;
  Timer? _timer;

  /// Call from `build`: true while [loading], and until [minimum] has passed
  /// since the loading view first appeared.
  bool update(bool loading) {
    if (loading) {
      _since ??= DateTime.now();
      _timer?.cancel();
      _timer = null;
      return true;
    }
    final since = _since;
    if (since == null) return false;
    final left = minimum - DateTime.now().difference(since);
    if (left <= Duration.zero) {
      _since = null;
      return false;
    }
    _timer ??= Timer(left, () {
      _timer = null;
      _since = null;
      onChange();
    });
    return true;
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Shows [loader] while [loading] and for at least 0.3 s after it first
/// appeared, then [builder].
class LoadingGate extends StatefulWidget {
  const LoadingGate({
    super.key,
    required this.loading,
    required this.builder,
    this.loader = const DotMatrixLoader(),
  });
  final bool loading;
  final WidgetBuilder builder;
  final Widget loader;

  @override
  State<LoadingGate> createState() => _LoadingGateState();
}

class _LoadingGateState extends State<LoadingGate> {
  late final hold = LoadingHold(() {
    if (mounted) setState(() {});
  });

  @override
  void dispose() {
    hold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      hold.update(widget.loading) ? widget.loader : widget.builder(context);
}

/// For a page's State: lets the page extend its loading view behind the app
/// bar for as long as [holdLoading] reports true.
mixin LoadingHoldState<T extends StatefulWidget> on State<T> {
  late final LoadingHold loadingHold = LoadingHold(() {
    if (mounted) setState(() {});
  });

  bool holdLoading(bool loading) => loadingHold.update(loading);

  @override
  void dispose() {
    loadingHold.dispose();
    super.dispose();
  }
}
