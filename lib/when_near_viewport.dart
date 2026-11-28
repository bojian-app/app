import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Calls [onNear] once, when [child] is within a screen of being scrolled into
/// view, so a long page fetches its pictures as the reader gets to them.
/// Outside a scrolling page that is straight away.
class WhenNearViewport extends StatefulWidget {
  const WhenNearViewport({
    super.key,
    required this.onNear,
    required this.child,
  });
  final VoidCallback onNear;
  final Widget child;

  @override
  State<WhenNearViewport> createState() => _WhenNearViewportState();
}

class _WhenNearViewportState extends State<WhenNearViewport> {
  bool near = false;

  @override
  void initState() {
    super.initState();
    wait();
  }

  /// Looks again after the next frame. This asks for no frame of its own, and
  /// both scrolling and pictures above settling into place draw one.
  void wait() => WidgetsBinding.instance.addPostFrameCallback((_) => check());

  void check() {
    if (!mounted || near) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return wait();
    final viewport = RenderAbstractViewport.maybeOf(box);
    final position = Scrollable.maybeOf(context)?.position;
    if (viewport != null && position != null) {
      if (!position.hasPixels || !position.hasViewportDimension) return wait();
      final top = viewport.getOffsetToReveal(box, 0).offset;
      final screen = position.viewportDimension;
      if (top > position.pixels + 2 * screen ||
          top + box.size.height < position.pixels - screen) {
        return wait();
      }
    }
    near = true;
    widget.onNear();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
