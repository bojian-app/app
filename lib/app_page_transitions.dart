import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

const appPageTransitionDuration = Duration(milliseconds: 260);
const appPageTransitionCurve = Curves.easeOutCubic;

class AppPageRoute<T> extends MaterialPageRoute<T> {
  AppPageRoute({required super.builder, super.settings});

  @override
  Duration get transitionDuration =>
      MediaQuery.disableAnimationsOf(navigator!.context)
      ? Duration.zero
      : appPageTransitionDuration;

  @override
  Duration get reverseTransitionDuration => transitionDuration;
}

class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  @override
  Duration get transitionDuration => appPageTransitionDuration;

  @override
  Duration get reverseTransitionDuration => appPageTransitionDuration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final slide = _RouteSlide(
      primary: reduced ? kAlwaysCompleteAnimation : animation,
      secondary: reduced ? kAlwaysDismissedAnimation : secondaryAnimation,
      interactive: route.popGestureInProgress,
      child: child,
    );
    final platform = Theme.of(context).platform;
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
      // Keep Flutter's edge-back recognizer. The slides paint both pages.
      return const CupertinoPageTransitionsBuilder().buildTransitions(
        route,
        context,
        kAlwaysCompleteAnimation,
        kAlwaysDismissedAnimation,
        slide,
      );
    }
    return slide;
  }
}

final _enter = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero);
final _leave = Tween<Offset>(begin: Offset.zero, end: const Offset(-1, 0));

class _RouteSlide extends StatefulWidget {
  const _RouteSlide({
    required this.primary,
    required this.secondary,
    required this.interactive,
    required this.child,
  });
  final Animation<double> primary, secondary;
  final bool interactive;
  final Widget child;

  @override
  State<_RouteSlide> createState() => _RouteSlideState();
}

class _RouteSlideState extends State<_RouteSlide> {
  CurvedAnimation curve(Animation<double> parent) => CurvedAnimation(
    parent: parent,
    curve: appPageTransitionCurve,
    reverseCurve: appPageTransitionCurve.flipped,
  );

  late CurvedAnimation primary = curve(widget.primary);
  late CurvedAnimation secondary = curve(widget.secondary);

  @override
  void didUpdateWidget(_RouteSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.primary != widget.primary) {
      primary.dispose();
      primary = curve(widget.primary);
    }
    if (oldWidget.secondary != widget.secondary) {
      secondary.dispose();
      secondary = curve(widget.secondary);
    }
  }

  @override
  void dispose() {
    primary.dispose();
    secondary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SlideTransition(
    position: _enter.animate(widget.interactive ? widget.primary : primary),
    child: SlideTransition(
      position: _leave.animate(
        widget.interactive ? widget.secondary : secondary,
      ),
      child: widget.child,
    ),
  );
}

/// Transitions between whole screens that share a route, such as help and chat.
class AppPageSwitcher extends StatefulWidget {
  const AppPageSwitcher({super.key, required this.depth, required this.child});
  final int depth;
  final Widget child;

  @override
  State<AppPageSwitcher> createState() => _AppPageSwitcherState();
}

class _PageStage {
  _PageStage(this.depth, this.child);
  final int depth;
  Widget child;

  bool matches(AppPageSwitcher page) =>
      depth == page.depth && Widget.canUpdate(child, page.child);
}

class _AppPageSwitcherState extends State<AppPageSwitcher>
    with SingleTickerProviderStateMixin {
  late _PageStage current = _PageStage(widget.depth, widget.child);
  _PageStage? previous;
  late final controller = AnimationController(
    vsync: this,
    duration: appPageTransitionDuration,
    value: 1,
  )..addStatusListener(finish);
  late final progress = controller.drive(
    CurveTween(curve: appPageTransitionCurve),
  );
  bool movingBack = false;
  bool retracing = false;
  bool reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced) sync();
  }

  @override
  void didUpdateWidget(AppPageSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    sync();
  }

  void sync() {
    if (reduced) {
      if (!current.matches(widget)) {
        current = previous?.matches(widget) == true
            ? previous!
            : _PageStage(widget.depth, widget.child);
      }
      current.child = widget.child;
      previous = null;
      retracing = false;
      controller.value = 1;
    } else if (current.matches(widget)) {
      current.child = widget.child;
      if (retracing) {
        retracing = false;
        controller.forward();
      }
    } else if (previous != null) {
      if (previous!.matches(widget)) {
        previous!.child = widget.child;
        if (!retracing) {
          retracing = true;
          controller.reverse();
        }
      }
      // A third destination waits for the two visible pages to finish.
    } else {
      previous = current;
      movingBack = widget.depth < current.depth;
      retracing = false;
      current = _PageStage(widget.depth, widget.child);
      controller.forward(from: 0);
    }
  }

  void finish(AnimationStatus status) {
    if (previous == null) return;
    if (status != AnimationStatus.completed &&
        !(status == AnimationStatus.dismissed && retracing)) {
      return;
    }
    setState(() {
      if (status == AnimationStatus.dismissed) current = previous!;
      previous = null;
      retracing = false;
      sync();
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Widget page(_PageStage stage, {required bool landing}) {
    final interactive = landing != retracing && stage.matches(widget);
    final side = Offset(movingBack ? -1 : 1, 0);
    final position = landing
        ? Tween<Offset>(begin: side, end: Offset.zero)
        : Tween<Offset>(begin: Offset.zero, end: -side);
    return ExcludeFocus(
      key: ObjectKey(stage),
      excluding: !interactive,
      child: ExcludeSemantics(
        excluding: !interactive,
        child: IgnorePointer(
          ignoring: !interactive,
          child: SlideTransition(
            position: previous == null
                ? const AlwaysStoppedAnimation(Offset.zero)
                : position.animate(progress),
            child: stage.child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (previous != null) page(previous!, landing: false),
        page(current, landing: true),
      ],
    ),
  );
}
