import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_store.dart';
import 'design.dart';
import 'discovery.dart';
import 'profile_identity.dart';
import 'public_profile_controller.dart';

Future<void> openUserProfile(
  BuildContext context, {
  required AppStore store,
  required int userID,
}) async {
  if (userID <= 0 ||
      !context.mounted ||
      ModalRoute.of(context)?.isCurrent == false) {
    return;
  }
  await openPage<void>(context, UserProfilePage(store: store, userID: userID));
}

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key, required this.store, required this.userID});
  final AppStore store;
  final int userID;

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage>
    with SingleTickerProviderStateMixin {
  late PublicProfileController publicProfile;
  ProfileIdentityData? get profile => publicProfile.profile;
  List<Story> get articles => publicProfile.articles;
  bool get loading => publicProfile.loading;
  String? get profileError => publicProfile.profileError;
  String? get articleError => publicProfile.articleError;
  final scroll = ScrollController();
  final headerKey = GlobalKey();
  final nameKey = GlobalKey();
  final surfaceKey = GlobalKey();
  final viewportKey = GlobalKey();
  late final pull = AnimationController(vsync: this);
  double headerHeight = 400, collapseExtent = 174;
  double pullDistance = 0;
  bool measuring = false, openingDetails = false;
  bool pulling = false, pullFromHeader = false, compact = false;
  int? headerPointer;
  PageRoute<void>? detailsRoute;

  @override
  void initState() {
    super.initState();
    configureProfile();
    scroll.addListener(scrolled);
  }

  void configureProfile() {
    publicProfile = PublicProfileController(
      store: widget.store,
      userID: widget.userID,
    )..addListener(profileChanged);
    unawaited(load());
  }

  @override
  void didUpdateWidget(UserProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userID != widget.userID || oldWidget.store != widget.store) {
      publicProfile.dispose();
      if (scroll.hasClients) scroll.jumpTo(0);
      configureProfile();
    }
  }

  void profileChanged() {
    if (!mounted) return;
    if (profile == null && detailsRoute?.isCurrent == true) {
      final route = detailsRoute;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && route?.isCurrent == true) Navigator.of(context).pop();
      });
    }
    setState(() {});
    measureHeader();
  }

  Future<void> load() => publicProfile.load();

  void scrolled() {
    final next = scroll.hasClients && scroll.offset > collapseExtent * .5;
    if (next != compact && mounted) setState(() => compact = next);
    measureHeader();
  }

  void measureHeader() {
    if (measuring) return;
    measuring = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      measuring = false;
      if (!mounted || !scroll.hasClients) return;
      final header = headerKey.currentContext?.findRenderObject();
      final name = nameKey.currentContext?.findRenderObject();
      final viewport = viewportKey.currentContext?.findRenderObject();
      if (header is RenderBox && header.hasSize) {
        final height =
            header.size.height - pull.value * ProfileHeader.pullExtent;
        if ((height - headerHeight).abs() > .1) {
          setState(() => headerHeight = height);
        }
      }
      if (name is RenderBox && viewport is RenderBox && name.hasSize) {
        collapseExtent =
            name.localToGlobal(Offset.zero, ancestor: viewport).dy +
            scroll.offset -
            MediaQuery.paddingOf(context).top;
      }
    });
  }

  void settlePull() {
    if (!mounted) return;
    pull.animateBack(
      0,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  bool onScroll(ScrollNotification notification) {
    if (notification.depth != 0 || openingDetails) return false;
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      pulling =
          notification.metrics.pixels <=
          notification.metrics.minScrollExtent + .5;
      pullFromHeader = headerPointer != null;
      pullDistance = 0;
    } else if (pulling &&
        notification is OverscrollNotification &&
        notification.dragDetails != null &&
        notification.overscroll < 0) {
      pullDistance = (pullDistance - notification.overscroll).clamp(0, 240);
      if (pullFromHeader) pull.value = (pullDistance / 120).clamp(0, 1);
    } else if (pulling &&
        notification is ScrollUpdateNotification &&
        notification.metrics.pixels >
            notification.metrics.minScrollExtent + .5) {
      pulling = false;
      settlePull();
    } else if (notification is ScrollEndNotification && pulling) {
      pulling = false;
      final details = pullFromHeader && pullDistance >= 120;
      final refresh = pullDistance >= 48;
      pullDistance = 0;
      if (!details) settlePull();
      if (refresh && !loading) unawaited(load());
      if (details) unawaited(showDetails());
    }
    return false;
  }

  Future<void> showDetails() async {
    if (openingDetails ||
        profile == null ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final box = headerKey.currentContext?.findRenderObject();
    final navigator = Navigator.of(context).context.findRenderObject();
    if (box is! RenderBox || navigator is! RenderBox) return;
    openingDetails = true;
    pull.stop();
    final identity = profile!;
    final initialScrollOffset = scroll.offset;
    final initialPull = pull.value;
    final origin =
        box.localToGlobal(Offset.zero, ancestor: navigator) & box.size;
    final surface = surfaceKey.currentContext?.findRenderObject();
    final reduced = MediaQuery.disableAnimationsOf(context);
    final route = PageRouteBuilder<void>(
      transitionDuration: reduced
          ? Duration.zero
          : const Duration(milliseconds: 380),
      reverseTransitionDuration: reduced
          ? Duration.zero
          : const Duration(milliseconds: 320),
      pageBuilder: (context, animation, secondaryAnimation) =>
          ProfileDetailsPage(
            store: widget.store,
            identity: identity,
            origin: origin,
            returnOrigin: Rect.fromLTWH(
              origin.left,
              origin.top,
              origin.width,
              origin.height - initialPull * ProfileHeader.pullExtent,
            ),
            initialPull: initialPull,
            initialScrollOffset: initialScrollOffset,
            initialCollapse: Curves.easeInOutCubic.transform(
              (initialScrollOffset / collapseExtent.clamp(1, double.infinity))
                  .clamp(0, 1),
            ),
            initialSurfaceHeight: surface is RenderBox && surface.hasSize
                ? surface.size.height
                : 0,
            expansion: animation,
            onEdit: (_) async {},
            onAvatar: (_) async {},
          ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          child,
    );
    void prepareReturn(AnimationStatus status) {
      if (status == AnimationStatus.completed && mounted) pull.value = 0;
    }

    detailsRoute = route;
    final navigation = Navigator.of(context).push(route);
    route.animation!.addStatusListener(prepareReturn);
    prepareReturn(route.animation!.status);
    try {
      await navigation;
      await route.completed;
    } finally {
      route.animation!.removeStatusListener(prepareReturn);
      detailsRoute = null;
      openingDetails = false;
      if (mounted && pull.value > 0) settlePull();
    }
  }

  Widget status(String message, {bool retry = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
    child: Column(
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.6,
            color: context.colors.muted,
          ),
        ),
        if (retry) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: loading ? null : load,
            child: const Text('重新加载'),
          ),
        ],
      ],
    ),
  );

  @override
  void dispose() {
    publicProfile.dispose();
    scroll.dispose();
    pull.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    measureHeader();
    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('个人主页')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : Center(child: status(profileError ?? '该用户主页暂不可见', retry: true)),
      );
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: compact
          ? appSystemUiStyle(context)
          : appSystemUiStyle(context).copyWith(
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
              systemStatusBarContrastEnforced: false,
            ),
      child: Scaffold(
        backgroundColor: context.colors.surface,
        body: DefaultTabController(
          length: 1,
          child: Listener(
            onPointerUp: (_) => headerPointer = null,
            onPointerCancel: (_) {
              headerPointer = null;
              pulling = false;
              settlePull();
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: onScroll,
              child: SizedBox.expand(
                key: viewportKey,
                child: CustomScrollView(
                  key: const ValueKey('public-profile-scroll'),
                  controller: scroll,
                  physics: const ClampingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    AnimatedBuilder(
                      animation: pull,
                      builder: (context, _) => SliverPersistentHeader(
                        pinned: true,
                        delegate: ProfileHeaderSliver(
                          expandedHeight:
                              headerHeight +
                              pull.value * ProfileHeader.pullExtent,
                          collapsedHeight:
                              ProfileHeader.toolbarHeight(context) +
                              MediaQuery.paddingOf(context).top,
                          collapseExtent: collapseExtent,
                          headerBuilder: (offset, progress) => Listener(
                            behavior: HitTestBehavior.translucent,
                            onPointerDown: (event) =>
                                headerPointer = event.pointer,
                            child: ProfileHeader(
                              key: headerKey,
                              nameKey: nameKey,
                              surfaceKey: surfaceKey,
                              store: widget.store,
                              identity: profile,
                              pullProgress: pull.value,
                              scrollOffset: offset,
                              collapseProgress: progress,
                              onMenu: () => Navigator.of(context).maybePop(),
                              onEdit: () {},
                              onAvatar: showDetails,
                              onDetails: showDetails,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverAppBar(
                      primary: false,
                      pinned: true,
                      toolbarHeight: 0,
                      automaticallyImplyLeading: false,
                      backgroundColor: context.colors.surface,
                      elevation: 0,
                      scrolledUnderElevation: 0,
                      surfaceTintColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      bottom: const ProfileContentTabs(
                        tabs: [
                          Tab(
                            key: ValueKey('profile-tab-articles'),
                            text: '动态',
                            height: 36,
                          ),
                        ],
                      ),
                    ),
                    if (profileError != null)
                      SliverToBoxAdapter(
                        child: status(profileError!, retry: true),
                      ),
                    SliverList.builder(
                      itemCount: articles.length,
                      itemBuilder: (context, index) => KeyedSubtree(
                        key: ValueKey('public-article-${articles[index].id}'),
                        child: ColoredBox(
                          color: context.colors.canvas,
                          child: Container(
                            color: context.colors.surface,
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 600,
                                ),
                                child: StoryCard(
                                  story: articles[index],
                                  store: widget.store,
                                  flat: true,
                                  compactTypography: true,
                                  authorNavigationEnabled: false,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (articleError != null)
                      SliverToBoxAdapter(
                        child: status(articleError!, retry: true),
                      ),
                    if (articles.isEmpty && articleError == null)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: status(loading ? '正在加载动态…' : '暂时没有公开动态'),
                      ),
                    SliverLayoutBuilder(
                      builder: (context, constraints) => SliverToBoxAdapter(
                        // Short or empty feeds still allow the shared header
                        // to collapse, without adding a whole empty screen.
                        child: SizedBox(
                          height:
                              (constraints.viewportMainAxisExtent -
                                      ProfileHeader.toolbarHeight(context) -
                                      MediaQuery.paddingOf(context).top +
                                      headerHeight +
                                      pull.value * ProfileHeader.pullExtent -
                                      constraints.precedingScrollExtent)
                                  .clamp(28.0, double.infinity),
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
    );
  }
}
