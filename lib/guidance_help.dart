import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_store.dart';
import 'design.dart';

const guidanceTourIds = [
  'reviewer',
  'author-detail',
  'participants',
  'review',
  'share',
  'friends',
  'comments',
  'owner-comments',
  'rewrite',
  'feedback',
];

String guidanceTourStorageKey(int user, String tour) =>
    'bojian.guidance-tour.v2.$user.$tour';

class GuidanceStep {
  const GuidanceStep(
    this.target,
    this.title,
    this.description, {
    this.prefix = false,
  });
  final String target, title, description;
  final bool prefix;

  bool matches(Widget widget) {
    final key = widget.key;
    return key is ValueKey<String> &&
        (prefix ? key.value.startsWith(target) : key.value == target);
  }
}

/// An automatic, contextual tour. It only points at controls that exist in this
/// subtree, and never activates those controls or submits example data.
class GuidanceWalkthrough extends StatefulWidget {
  const GuidanceWalkthrough({
    super.key,
    required this.store,
    required this.id,
    required this.steps,
    required this.child,
    this.ready = true,
  });
  final AppStore store;
  final String id;
  final List<GuidanceStep> steps;
  final Widget child;
  final bool ready;

  @override
  State<GuidanceWalkthrough> createState() => _GuidanceWalkthroughState();
}

class _GuidanceWalkthroughState extends State<GuidanceWalkthrough> {
  bool checked = false;
  Animation<double>? openingAnimation;
  Completer<void>? openingComplete;

  void checkOpening(AnimationStatus status) {
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed) {
      if (openingComplete?.isCompleted == false) openingComplete!.complete();
    }
  }

  Future<void> waitForOpening() async {
    openingAnimation = ModalRoute.of(context)?.animation;
    if (openingAnimation == null ||
        openingAnimation!.status == AnimationStatus.completed) {
      return;
    }
    openingComplete = Completer<void>();
    openingAnimation!.addStatusListener(checkOpening);
    await openingComplete!.future;
    openingAnimation?.removeStatusListener(checkOpening);
    openingAnimation = null;
  }

  @override
  void dispose() {
    openingAnimation?.removeStatusListener(checkOpening);
    openingAnimation = null;
    if (openingComplete?.isCompleted == false) openingComplete!.complete();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    schedule();
  }

  @override
  void didUpdateWidget(GuidanceWalkthrough oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) checked = false;
    schedule();
  }

  void schedule() {
    if (checked || !widget.ready) return;
    checked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => start());
  }

  List<Element> targets(GuidanceStep step) {
    final found = <Element>[];
    void visit(Element element) {
      if (step.matches(element.widget)) found.add(element);
      element.visitChildren(visit);
    }

    if (mounted) context.visitChildElements(visit);
    return found;
  }

  Future<void> start() async {
    if (!mounted) return;
    final id = widget.id;
    final storage = widget.store.storage;
    final key = guidanceTourStorageKey(widget.store.userID, id);
    try {
      if (await storage.read(key) == 'seen') return;
    } catch (_) {
      // A local storage failure must not prevent the user from using the page.
    }
    if (!mounted ||
        id != widget.id ||
        !widget.ready ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    // A bottom sheet is translated while opening. Wait for its final layout
    // before measuring controls so the spotlight cannot lag behind the sheet.
    await waitForOpening();
    if (!mounted ||
        id != widget.id ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final steps = widget.steps
        .where((step) => targets(step).isNotEmpty)
        .toList();
    if (steps.isEmpty) return;
    final finished = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      pageBuilder: (_, _, _) =>
          _GuidanceOverlay(steps: steps, targets: targets),
    );
    // Back/interruption leaves the tour eligible for the next visit. Explicit
    // skip and completion both count as acknowledgement for this context only.
    if (finished == true) {
      try {
        await storage.write(key, 'seen');
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _GuidanceOverlay extends StatefulWidget {
  const _GuidanceOverlay({required this.steps, required this.targets});
  final List<GuidanceStep> steps;
  final List<Element> Function(GuidanceStep) targets;

  @override
  State<_GuidanceOverlay> createState() => _GuidanceOverlayState();
}

class _GuidanceOverlayState extends State<_GuidanceOverlay> {
  int index = 0;
  Element? target;
  bool moving = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => locate());
  }

  Rect? bounds(Element element) {
    if (!element.mounted) return null;
    final render = element.findRenderObject();
    if (render is! RenderBox || !render.attached || !render.hasSize) {
      return null;
    }
    final overlay = context.findRenderObject();
    if (overlay is! RenderBox || !overlay.hasSize) return null;
    return MatrixUtils.transformRect(
      render.getTransformTo(overlay),
      Offset.zero & render.size,
    );
  }

  Future<void> locate() async {
    final candidates = widget.targets(widget.steps[index]);
    final screen = Offset.zero & MediaQuery.sizeOf(context);
    target =
        candidates.where((element) {
          final rect = bounds(element);
          return rect != null && screen.overlaps(rect);
        }).firstOrNull ??
        candidates.firstOrNull;
    if (target == null) {
      if (index + 1 < widget.steps.length) {
        index++;
        await locate();
      } else if (mounted) {
        Navigator.pop(context, false);
      }
      return;
    }
    // Bring offscreen controls into view without tapping them or changing data.
    await Scrollable.ensureVisible(
      target!,
      alignment: .35,
      duration: Duration.zero,
    );
    if (mounted) setState(() => moving = false);
  }

  Future<void> next() async {
    if (index == widget.steps.length - 1) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      index++;
      moving = true;
    });
    await locate();
  }

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final screen = Offset.zero & constraints.biggest;
        final safeTop = media.padding.top + 12;
        final safeBottom =
            constraints.maxHeight -
            math.max(media.padding.bottom, media.viewInsets.bottom) -
            12;
        final raw = target == null ? null : bounds(target!);
        final rect = raw?.inflate(6).intersect(screen);
        final above =
            rect != null && rect.center.dy > (safeTop + safeBottom) / 2;
        final available = rect == null
            ? 0.0
            : above
            ? rect.top - safeTop - 14
            : safeBottom - rect.bottom - 14;
        // For a full-page document the card occupies one edge; for controls it
        // stays outside the spotlight. Long text scrolls within the card.
        final separated = available >= 220;
        final cardHeight = math.min(
          separated ? available : (safeBottom - safeTop) * .52,
          350.0,
        );
        final step = widget.steps[index];
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _SpotlightPainter(rect)),
            ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
              ),
            ),
            if (!moving)
              Positioned(
                left: 16,
                right: 16,
                top: above
                    ? (separated
                          ? math.max(safeTop, rect.top - cardHeight - 14)
                          : safeTop)
                    : separated
                    ? rect!.bottom + 14
                    : null,
                bottom: above || separated
                    ? null
                    : constraints.maxHeight - safeBottom,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 460,
                      maxHeight: math.max(120, cardHeight),
                    ),
                    child: Material(
                      key: const ValueKey('guidance-coach-card'),
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  above
                                      ? Icons.south_rounded
                                      : Icons.north_rounded,
                                  color: blue,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${index + 1} / ${widget.steps.length}',
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('跳过'),
                                ),
                              ],
                            ),
                            Flexible(
                              child: SingleChildScrollView(
                                child: Semantics(
                                  liveRegion: true,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        step.title,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        step.description,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.6,
                                          color: muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: next,
                                child: Text(
                                  index == widget.steps.length - 1
                                      ? '完成，开始操作'
                                      : '下一步',
                                ),
                              ),
                            ),
                          ],
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

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter(this.rect);
  final Rect? rect;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    if (rect != null && !rect!.isEmpty) {
      path.addRRect(RRect.fromRectAndRadius(rect!, const Radius.circular(10)));
    }
    canvas.drawPath(path, Paint()..color = const Color(0xB3000000));
    if (rect != null && !rect!.isEmpty) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect!, const Radius.circular(10)),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) => oldDelegate.rect != rect;
}
