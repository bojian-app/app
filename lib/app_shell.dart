import 'dart:async';

import 'route_transition_snapshot.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_store.dart';
import 'app_page_bar.dart';
import 'design.dart';
import 'discovery.dart';
import 'account_pages.dart';
import 'membership_page.dart';
import 'customer_service_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.store});
  final AppStore store;
  static const membershipTab = 1;
  static const serviceTab = 2;
  static const profileTab = 3;
  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  final _history = <int>[0];
  int get selected => _history.last;
  final visited = <int>{0};
  int displayed = 0;
  int? previous;
  bool selectedFromHistory = false;
  bool reducedMotion = false;
  late final AnimationController transition;
  late final Animation<double> progress;
  Animation<Offset> entering = const AlwaysStoppedAnimation(Offset.zero);
  Animation<Offset> leaving = const AlwaysStoppedAnimation(Offset.zero);

  @override
  void initState() {
    super.initState();
    transition = AnimationController(
      vsync: this,
      duration: appPageTransitionDuration,
      value: 1,
    )..addStatusListener(transitionFinished);
    progress = transition.drive(CurveTween(curve: appPageTransitionCurve));
    // Lay the profile's resume covers out while the home page is idle, so the
    // first visit to the profile tab does not hitch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 800), () {
        if (mounted && widget.store.isAuthenticated) {
          unawaited(ProfilePage.prewarm(widget.store));
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (reducedMotion && transition.isAnimating) transition.value = 1;
  }

  void transitionFinished(AnimationStatus status) {
    if (status == AnimationStatus.completed && previous != null && mounted) {
      // Finish the current slide before showing a newer selection.
      final showNext = !reducedMotion && displayed != selected;
      setState(() => displaySelection(animate: showNext));
      if (showNext) transition.forward(from: 0);
    }
  }

  void displaySelection({required bool animate}) {
    previous = animate ? displayed : null;
    displayed = selected;
    if (animate) {
      final side = Offset(selectedFromHistory ? -1 : 1, 0);
      entering = Tween(begin: side, end: Offset.zero).animate(progress);
      leaving = Tween(begin: Offset.zero, end: -side).animate(progress);
    }
  }

  void select(int index) {
    dismissKeyboard();
    if (selected == index) return;
    final startSlide = !reducedMotion && !transition.isAnimating;
    setState(() {
      final existing = _history.indexOf(index);
      selectedFromHistory = existing != -1;
      if (selectedFromHistory) {
        _history.removeRange(existing + 1, _history.length);
      } else {
        _history.add(index);
      }
      visited.add(index);
      if (startSlide || reducedMotion) {
        displaySelection(animate: startSlide);
      }
    });
    if (startSlide) transition.forward(from: 0);
  }

  void goBack() {
    if (_history.length > 1) select(_history[_history.length - 2]);
  }

  @override
  void dispose() {
    transition.removeStatusListener(transitionFinished);
    transition.dispose();
    super.dispose();
  }

  Widget page(int index) => switch (index) {
    0 => DiscoveryPage(
      store: widget.store,
      onOpenMembership: () => select(AppShell.membershipTab),
      onOpenService: () => select(AppShell.serviceTab),
      onOpenProfile: () => select(AppShell.profileTab),
    ),
    AppShell.membershipTab =>
      widget.store.isAuthenticated
          ? MembershipPage(
              key: ValueKey('membership-${widget.store.userID}'),
              store: widget.store,
              embedded: true,
              onExit: goBack,
            )
          : guestPage('会员中心'),
    AppShell.serviceTab =>
      widget.store.isAuthenticated
          ? CustomerServicePage(
              key: ValueKey(widget.store.epoch),
              onExit: goBack,
              store: widget.store,
              embedded: true,
            )
          : guestPage('在线客服'),
    _ => ProfilePage(store: widget.store, onExit: goBack),
  };

  Widget guestPage(String title) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: appSystemUiStyle(context),
    child: Scaffold(
      appBar: AppPageBar(
        leading: BackButton(onPressed: goBack),
        title: Text(title),
      ),
      body: DataStatus(store: widget.store, section: 'profile', empty: false),
    ),
  );

  @override
  Widget build(BuildContext context) => RouteTransitionSnapshot(
    child: Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Keep every page in the same keyed tree, painting the new page last.
                  for (final index in [
                    ...visited.where((index) => index != displayed),
                    displayed,
                  ])
                    _RetainedTab(
                      key: ValueKey(index),
                      store: widget.store,
                      index: index,
                      active: displayed == index,
                      visible: displayed == index || previous == index,
                      position: displayed == index
                          ? entering
                          : previous == index
                          ? leaving
                          : const AlwaysStoppedAnimation(Offset.zero),
                      builder: () => page(index),
                      onBack: goBack,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
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
    required this.position,
    required this.builder,
    required this.onBack,
  });
  final AppStore store;
  final int index;
  final bool active, visible;
  final Animation<Offset> position;
  final Widget Function() builder;
  final VoidCallback onBack;
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
      child: SlideTransition(
        position: widget.position,
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
                      AppShell.membershipTab =>
                        widget.store.isAuthenticated
                            ? MembershipPage.backgroundColor(context)
                            : context.colors.surface,
                      _ => context.colors.canvas,
                    },
                    child: SafeArea(
                      top: widget.index < AppShell.membershipTab,
                      bottom: widget.index != AppShell.serviceTab,
                      child: ColoredBox(
                        color: context.colors.canvas,
                        child: PopScope(
                          canPop: !handlesBack,
                          onPopInvokedWithResult: (didPop, _) {
                            if (!didPop && handlesBack) widget.onBack();
                          },
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

  // The signed-in service page handles returning from a chat before exiting.
  bool get handlesBack =>
      widget.active &&
      widget.index != 0 &&
      (widget.index != AppShell.serviceTab || !widget.store.isAuthenticated);

  @override
  void dispose() {
    widget.store.removeListener(invalidate);
    super.dispose();
  }
}
