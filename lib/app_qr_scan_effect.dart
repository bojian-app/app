import 'package:flutter/material.dart';

/// Decorative scan band; recognition still uses the full camera image.
class AppQRScanEffect extends StatefulWidget {
  const AppQRScanEffect({
    super.key,
    required this.color,
    required this.enabled,
  });

  final Color color;
  final bool enabled;

  @override
  State<AppQRScanEffect> createState() => _AppQRScanEffectState();
}

class _AppQRScanEffectState extends State<AppQRScanEffect>
    with SingleTickerProviderStateMixin {
  late final motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
    value: .5,
  );

  void syncMotion() {
    if (widget.enabled &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled) {
      if (!motion.isAnimating) motion.repeat(reverse: true);
    } else {
      motion.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncMotion();
  }

  @override
  void didUpdateWidget(covariant AppQRScanEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncMotion();
  }

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.enabled
      ? RepaintBoundary(
          child: CustomPaint(painter: _ScanBandPainter(motion, widget.color)),
        )
      : const SizedBox.shrink();
}

class _ScanBandPainter extends CustomPainter {
  _ScanBandPainter(this.motion, this.color) : super(repaint: motion);

  final Animation<double> motion;
  final Color color;
  Path? _dots;
  Size? _cachedSize;

  @override
  void paint(Canvas canvas, Size size) {
    final bandHeight = (size.height * .20).clamp(80.0, 160.0);
    if (_cachedSize != size) {
      _cachedSize = size;
      final dots = Path();
      for (double y = 0; y < bandHeight; y += 4) {
        for (double x = 0; x < size.width; x += 4) {
          dots.addRect(Rect.fromLTWH(x, y, 2, 2));
        }
      }
      _dots = dots;
    }
    final center =
        size.height * (.32 + .28 * Curves.easeInOut.transform(motion.value));
    final shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withValues(alpha: 0),
        color.withValues(alpha: .25),
        color.withValues(alpha: .7),
        color.withValues(alpha: .25),
        color.withValues(alpha: 0),
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, bandHeight));
    canvas.save();
    canvas.translate(0, center - bandHeight / 2);
    canvas.drawPath(_dots!, Paint()..shader = shader);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScanBandPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.motion != motion;
}
