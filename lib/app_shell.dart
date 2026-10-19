import 'app_bottom_navigation.dart';

import 'package:flutter/material.dart';

import 'app_store.dart';
import 'design.dart';
import 'discovery.dart';
import 'resume_pages.dart';
import 'account_pages.dart';
import 'points_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.store});
  final AppStore store;
  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  int selected = 0;
  final visited = <int>{0};
  int? previous;
  double direction = 1;
  bool reducedMotion = false;
  late final AnimationController transition;
  late final CurvedAnimation progress;

  @override
  void initState() {
    super.initState();
    transition = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1,
    )..addStatusListener(transitionFinished);
    progress = CurvedAnimation(parent: transition, curve: Curves.easeOutCubic);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (reducedMotion && transition.isAnimating) transition.value = 1;
  }

  void transitionFinished(AnimationStatus status) {
    if (status == AnimationStatus.completed && previous != null && mounted) {
      setState(() => previous = null);
    }
  }

  void select(int index) {
    dismissKeyboard();
    if (selected == index) return;
    if (reducedMotion) transition.value = 1;
    setState(() {
      previous = reducedMotion ? null : selected;
      direction = index > selected ? 1 : -1;
      selected = index;
      visited.add(index);
    });
    if (!reducedMotion) transition.forward(from: 0);
  }

  @override
  void dispose() {
    transition.removeStatusListener(transitionFinished);
    progress.dispose();
    transition.dispose();
    super.dispose();
  }

  Widget page(int index) => switch (index) {
    0 => DiscoveryPage(store: widget.store),
    1 => TemplateMarket(store: widget.store),
    2 => PointsPage(store: widget.store),
    _ => ProfilePage(store: widget.store),
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      top: false,
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            fit: StackFit.expand,
            children: [
              // Keep every page in the same keyed tree, painting the new page last.
              for (final index in [
                ...visited.where((index) => index != selected),
                selected,
              ])
                _RetainedTab(
                  key: ValueKey(index),
                  store: widget.store,
                  index: index,
                  active: selected == index,
                  visible: selected == index || previous == index,
                  motion: selected == index
                      ? progress
                      : const AlwaysStoppedAnimation(1.0),
                  direction: direction,
                  builder: () => page(index),
                ),
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
        ? null
        : AppBottomNavigation(selectedIndex: selected, onSelected: select),
  );
}

// Keep tab state and scroll position, but defer building hidden pages until needed.
class _RetainedTab extends StatefulWidget {
  const _RetainedTab({
    super.key,
    required this.store,
    required this.index,
    required this.active,
    required this.visible,
    required this.motion,
    required this.direction,
    required this.builder,
  });
  final AppStore store;
  final int index;
  final bool active, visible;
  final Animation<double> motion;
  final double direction;
  final Widget Function() builder;
  @override
  State<_RetainedTab> createState() => _RetainedTabState();
}

class _RetainedTabState extends State<_RetainedTab> {
  Widget? content;
  bool dirty = true;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(invalidate);
  }

  void invalidate() {
    dirty = true;
    if (widget.active) setState(() {});
  }

  @override
  void didUpdateWidget(_RetainedTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(invalidate);
      widget.store.addListener(invalidate);
      dirty = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (content == null || (dirty && widget.active)) {
      content = widget.builder();
      dirty = false;
    }
    return Offstage(
      offstage: !widget.visible,
      child: FadeTransition(
        key: ValueKey('tab-fade-${widget.index}'),
        opacity: widget.motion,
        alwaysIncludeSemantics: true,
        child: AnimatedBuilder(
          animation: widget.motion,
          builder: (context, child) => Transform.translate(
            key: ValueKey('tab-offset-${widget.index}'),
            offset: Offset(widget.direction * 6 * (1 - widget.motion.value), 0),
            child: child,
          ),
          child: IgnorePointer(
            ignoring: !widget.active,
            child: ExcludeSemantics(
              excluding: !widget.active,
              child: ExcludeFocus(
                excluding: !widget.active,
                child: TickerMode(
                  enabled: widget.active,
                  child: RepaintBoundary(
                    child: ColoredBox(
                      color: switch (widget.index) {
                        0 => context.colors.surface,
                        2 => PointsPage.headerColor(context),
                        _ => context.colors.canvas,
                      },
                      child: SafeArea(
                        top: widget.index != 3,
                        bottom: false,
                        child: ColoredBox(
                          color: context.colors.canvas,
                          child: content!,
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
    );
  }

  @override
  void dispose() {
    widget.store.removeListener(invalidate);
    super.dispose();
  }
}
