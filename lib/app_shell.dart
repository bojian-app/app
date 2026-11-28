import 'dart:async';

import 'route_transition_snapshot.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_store.dart';
import 'app_page_bar.dart';
import 'app_icons.dart';
import 'app_tab_bar.dart';
import 'design.dart';
import 'discovery.dart';
import 'account_pages.dart';
import 'membership_page.dart';
import 'messages_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.store});
  final AppStore store;
  static const membershipTab = 1;
  static const messagesTab = 2;
  static const profileTab = 3;

  /// The bar's tabs from left to right, either side of the publish button.
  static const _bar = <(int, String, String)>[
    (0, 'home', '首页'),
    (membershipTab, 'membership', '成为会员'),
    (messagesTab, 'messages', '消息'),
    (profileTab, 'profile', '我的'),
  ];
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
  Timer? prewarmTimer;
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
      if (!mounted) return;
      prewarmTimer = Timer(const Duration(milliseconds: 800), () {
        if (widget.store.isAuthenticated) {
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
      // Pages travel the same way as the bar's selection.
      final side = Offset(displayed < previous! ? -1 : 1, 0);
      entering = Tween(begin: side, end: Offset.zero).animate(progress);
      leaving = Tween(begin: Offset.zero, end: -side).animate(progress);
    }
  }

  void select(int index) {
    dismissKeyboard();
    if (selected == index) return;
    // The retained page loads itself once; later visits refresh the inbox.
    if (index == AppShell.messagesTab &&
        visited.contains(index) &&
        widget.store.isAuthenticated) {
      unawaited(widget.store.load('messages'));
    }
    final startSlide = !reducedMotion && !transition.isAnimating;
    setState(() {
      final existing = _history.indexOf(index);
      if (existing != -1) {
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

  void publish() {
    dismissKeyboard();
    if (!widget.store.isAuthenticated) {
      widget.store.endSession();
      return;
    }
    if (ModalRoute.of(context)?.isCurrent != true) return;
    openPage(context, StoryComposer(store: widget.store));
  }

  @override
  void dispose() {
    prewarmTimer?.cancel();
    transition.removeStatusListener(transitionFinished);
    transition.dispose();
    super.dispose();
  }

  Widget page(int index) => switch (index) {
    0 => DiscoveryPage(store: widget.store),
    AppShell.membershipTab =>
      widget.store.isAuthenticated
          ? MembershipPage(
              key: ValueKey('membership-${widget.store.userID}'),
              store: widget.store,
              embedded: true,
            )
          : guestPage('会员中心'),
    AppShell.messagesTab =>
      widget.store.isAuthenticated
          ? MessagesPage(
              key: ValueKey('messages-${widget.store.epoch}'),
              store: widget.store,
              standalone: true,
            )
          : guestPage('消息'),
    _ => ProfilePage(store: widget.store),
  };

  Widget guestPage(String title) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: appSystemUiStyle(context),
    child: Scaffold(
      appBar: AppPageBar(title: Text(title)),
      body: DataStatus(store: widget.store, section: 'profile', empty: false),
    ),
  );

  Widget tabBar() => ListenableBuilder(
    listenable: Listenable.merge([widget.store, widget.store.appearance]),
    builder: (context, _) => AppTabBar(
      style: widget.store.appearance.value.tabBar,
      items: [
        for (final (tab, name, label) in AppShell._bar)
          (
            key: ValueKey('app-tab-$name'),
            label: label,
            icon: switch (tab) {
              0 => AppIcons.tabHome,
              AppShell.membershipTab => AppIcons.tabMembership,
              AppShell.messagesTab => AppIcons.tabMessages,
              _ => AppIcons.tabProfile,
            },
          ),
      ],
      unread: {
        AppShell._bar.indexWhere((item) => item.$1 == AppShell.messagesTab):
            widget.store.unread,
      },
      updateAt: AppShell._bar.indexWhere(
        (item) => item.$1 == AppShell.profileTab,
      ),
      selected: AppShell._bar.indexWhere((item) => item.$1 == selected),
      onSelect: (index) => select(AppShell._bar[index].$1),
      action: (
        key: const ValueKey('app-tab-publish'),
        label: '发布新动态',
        icon: AppIcons.add,
      ),
      onAction: publish,
    ),
  );

  @override
  Widget build(BuildContext context) => RouteTransitionSnapshot(
    child: Scaffold(
      // Pages run beneath the bar and end their scrolling above it: the
      // Scaffold reports the bar's height as their bottom padding.
      extendBody: true,
      bottomNavigationBar: tabBar(),
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
                      bottom: false,
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

  bool get handlesBack => widget.active && widget.index != 0;

  @override
  void dispose() {
    widget.store.removeListener(invalidate);
    super.dispose();
  }
}
