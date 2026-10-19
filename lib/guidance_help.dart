import 'dart:async';

import 'package:flutter/material.dart';

import 'app_store.dart';
import 'guidance_coach.dart';
import 'guidance_flow.dart';

export 'guidance_flow.dart';

const guidanceTourIds = ['reviewer', 'review-save', 'rewrite-preview'];

String guidanceTourStorageKey(int user, String tour) =>
    'bojian.guidance-tour.v4.$user.$tour';

/// Only one scene speaks at a time. A new route suspends the previous scene;
/// returning to it resumes any steps that still need an actual user action.
class _SceneCoordinator {
  static final scenes = <_GuidanceWalkthroughState>{};
  static _GuidanceWalkthroughState? owner;

  static bool claim(_GuidanceWalkthroughState scene) {
    if (owner != null && owner != scene) {
      if (owner!.eligible) return false;
      owner!.hide();
    }
    owner = scene;
    return true;
  }

  static void release(_GuidanceWalkthroughState scene) {
    if (owner != scene) return;
    owner = null;
    for (final other in scenes.toList()) {
      if (other != scene) other.schedule();
    }
  }
}

class GuidanceWalkthrough extends StatefulWidget {
  const GuidanceWalkthrough({
    super.key,
    required this.store,
    required this.id,
    required this.steps,
    required this.child,
    this.controller,
    this.ready = true,
  });
  final AppStore store;
  final String id;
  final List<GuidanceStep> steps;
  final Widget child;
  final GuidanceFlowController? controller;
  final bool ready;

  @override
  State<GuidanceWalkthrough> createState() => _GuidanceWalkthroughState();
}

class _GuidanceWalkthroughState extends State<GuidanceWalkthrough>
    with WidgetsBindingObserver {
  final acknowledged = <String>{};
  final scrollLocked = ValueNotifier(false);
  final scrollHolds = <ScrollPosition, ScrollHoldController>{};
  OverlayEntry? entry;
  OverlayState? overlay;
  ModalRoute<dynamic>? route;
  GuidanceStep? current;
  Element? target;
  String? checkedKey, locatedStep;
  bool loaded = false, seen = false, scheduled = false, busy = false;
  bool dirty = false, repaintQueued = false;
  int generation = 0;
  Animation<double>? opening;
  Completer<void>? openingComplete;

  bool get eligible =>
      mounted && widget.ready && !seen && route?.isCurrent == true;

  bool done(GuidanceStep step) =>
      acknowledged.contains(step.id) ||
      (step.event != null && widget.controller?.contains(step.event!) == true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _SceneCoordinator.scenes.add(this);
    widget.controller?.bindAccount(widget.store.userID);
    widget.controller?.addListener(onAction);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    route = ModalRoute.of(context);
    schedule();
  }

  @override
  void didUpdateWidget(GuidanceWalkthrough oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(onAction);
      widget.controller?.addListener(onAction);
    }
    widget.controller?.bindAccount(widget.store.userID);
    schedule();
  }

  @override
  void dispose() {
    generation++;
    WidgetsBinding.instance.removeObserver(this);
    widget.controller?.removeListener(onAction);
    opening?.removeStatusListener(checkOpening);
    if (openingComplete?.isCompleted == false) openingComplete!.complete();
    _SceneCoordinator.scenes.remove(this);
    hide();
    scrollLocked.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() => repaint();

  void checkOpening(AnimationStatus status) {
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed) {
      if (openingComplete?.isCompleted == false) openingComplete!.complete();
    }
  }

  Future<void> waitForOpening() async {
    opening = route?.animation;
    if (opening == null || opening!.status == AnimationStatus.completed) return;
    openingComplete = Completer<void>();
    opening!.addStatusListener(checkOpening);
    await openingComplete!.future;
    opening?.removeStatusListener(checkOpening);
    opening = null;
  }

  void hide() {
    entry?.remove();
    entry?.dispose();
    entry = null;
    setScrollLocked(false);
    _SceneCoordinator.release(this);
  }

  void setScrollLocked(bool locked) {
    if (scrollLocked.value == locked) return;
    scrollLocked.value = locked;
    if (locked) {
      holdScrollables();
      // Changing physics may replace a ScrollPosition in the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && scrollLocked.value) holdScrollables();
      });
    } else {
      final holds = scrollHolds.values.toList();
      scrollHolds.clear();
      for (final hold in holds) {
        hold.cancel();
      }
    }
  }

  void holdScrollables() {
    void visit(Element element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final position = (element.state as ScrollableState).position;
        if (position.hasPixels && !scrollHolds.containsKey(position)) {
          scrollHolds[position] = position.hold(() {
            scrollHolds.remove(position);
          });
        }
      }
      element.visitChildren(visit);
    }

    context.visitChildElements(visit);
  }

  void finish(String status) {
    if (!mounted || seen) return;
    seen = true;
    hide();
    final storage = widget.store.storage;
    final key = guidanceTourStorageKey(widget.store.userID, widget.id);
    unawaited(() async {
      try {
        await storage.write(key, status);
      } catch (_) {}
    }());
  }

  void onAction() {
    // A final event may close its sheet in the same frame. Persist before that
    // disposal, rather than requiring an extra acknowledgement screen.
    if (widget.ready &&
        widget.steps.isNotEmpty &&
        widget.steps.every((step) => done(step) || step.optional) &&
        widget.steps.any(done)) {
      finish('seen');
    } else {
      schedule();
    }
  }

  void acknowledge() {
    if (current == null) return;
    acknowledged.add(current!.id);
    onAction();
  }

  void schedule({bool ensureFrame = true}) {
    if (!mounted) return;
    if (busy) {
      dirty = true;
      return;
    }
    if (scheduled) return;
    scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scheduled = false;
      if (mounted) unawaited(sync());
    });
    if (ensureFrame) WidgetsBinding.instance.ensureVisualUpdate();
  }

  List<Element> targets(GuidanceStep step) {
    final result = <Element>[];
    void visit(Element element) {
      if (step.matches(element.widget)) result.add(element);
      element.visitChildren(visit);
    }

    context.visitChildElements(visit);
    return result;
  }

  Rect? bounds(Element? element) {
    if (element?.mounted != true) return null;
    final render = element!.findRenderObject();
    final base = overlay?.context.findRenderObject();
    if (render is! RenderBox ||
        !render.attached ||
        !render.hasSize ||
        base is! RenderBox ||
        !base.attached ||
        !base.hasSize) {
      return null;
    }
    return MatrixUtils.transformRect(
      render.getTransformTo(base),
      Offset.zero & render.size,
    );
  }

  Future<void> sync() async {
    if (!mounted) return;
    busy = true;
    try {
      widget.controller?.bindAccount(widget.store.userID);
      final key = guidanceTourStorageKey(widget.store.userID, widget.id);
      if (checkedKey != key) {
        generation++;
        hide();
        checkedKey = key;
        loaded = seen = false;
        acknowledged.clear();
        locatedStep = null;
      }
      final token = generation;
      if (!loaded) {
        String? status;
        try {
          status = await widget.store.storage.read(key);
        } catch (_) {}
        if (!mounted ||
            token != generation ||
            key != guidanceTourStorageKey(widget.store.userID, widget.id)) {
          return;
        }
        seen = status == 'seen' || status == 'skipped';
        loaded = true;
      }
      if (!eligible) {
        hide();
        return;
      }
      await waitForOpening();
      if (!mounted || token != generation || !eligible) return;
      final next = widget.steps.where((step) => !done(step)).firstOrNull;
      if (next == null) {
        if (widget.steps.isNotEmpty) {
          finish('seen');
        } else {
          hide();
        }
        return;
      }
      overlay = Overlay.of(context, rootOverlay: true);
      final screen = Offset.zero & MediaQuery.sizeOf(context);
      final candidates = targets(next);
      final nextTarget =
          candidates
              .where((element) => bounds(element)?.overlaps(screen) == true)
              .firstOrNull ??
          candidates.firstOrNull;
      if (nextTarget == null) {
        hide();
        // A document can finish rendering in a descendant's later frame.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) schedule();
        });
        return;
      }
      if (!_SceneCoordinator.claim(this)) return;
      current = next;
      target = nextTarget;
      if (locatedStep != next.id) {
        locatedStep = next.id;
        await Scrollable.ensureVisible(
          nextTarget,
          alignment: .65,
          duration:
              MediaQuery.disableAnimationsOf(context) ||
                  MediaQuery.accessibleNavigationOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 280),
        );
      }
      if (!mounted || token != generation || !eligible) return;
      if (entry == null) {
        entry = OverlayEntry(builder: buildCoach);
        overlay!.insert(entry!);
        setScrollLocked(true);
      } else {
        entry!.markNeedsBuild();
      }
    } finally {
      busy = false;
      if (dirty) {
        dirty = false;
        schedule();
      }
    }
  }

  Widget buildCoach(BuildContext context) {
    final step = current;
    final rect = bounds(target);
    if (!eligible || step == null || rect == null || rect.isEmpty) {
      return const SizedBox.shrink();
    }
    return GuidanceCoach(
      key: ValueKey(widget.id),
      step: step,
      rect: rect,
      editingRect: editingBounds(),
      index: widget.steps.indexOf(step),
      total: widget.steps.length,
      onSkip: () => finish('skipped'),
      onAcknowledge: step.event == null || step.optional ? acknowledge : null,
      onVisibilityChanged: (visible) {
        if (mounted && entry != null) setScrollLocked(visible);
      },
    );
  }

  Rect? editingBounds() {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused is! Element) return null;
    Element? field;
    focused.visitAncestorElements((element) {
      if (element.widget is TextField) {
        field = element;
        return false;
      }
      return true;
    });
    return bounds(field);
  }

  void repaint() {
    if (entry == null || repaintQueued) return;
    repaintQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      repaintQueued = false;
      if (mounted) entry?.markNeedsBuild();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to the source route, not a new tutorial route.
    ModalRoute.isCurrentOf(context);
    schedule();
    return ValueListenableBuilder<bool>(
      valueListenable: scrollLocked,
      child: widget.child,
      builder: (context, locked, child) => GuidanceScrollLock(
        locked: locked,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            physics: locked ? const NeverScrollableScrollPhysics() : null,
          ),
          child: NotificationListener<ScrollNotification>(
            onNotification: (_) {
              repaint();
              return false;
            },
            child: Listener(
              onPointerMove: (_) => repaint(),
              onPointerUp: (_) => repaint(),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
