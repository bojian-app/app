import 'dart:async';

import 'user_display_name.dart';
export 'settings_page.dart' show SettingsPage;
import 'settings_page.dart';
export 'messages_page.dart' show MessagesPage;
import 'app_icons.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';

import 'app_store.dart';
import 'app_photo_picker.dart';
import 'developer_verification_page.dart';
import 'app_qr_login_page.dart';
import 'design.dart';
import 'my_articles_page.dart';
import 'saved_articles_page.dart';
import 'resume_pages.dart';
import 'profile_avatar.dart';
import 'profile_identity.dart';
import 'profile_edit_actions.dart';
import 'points_page.dart';
import 'profile_editor_views.dart';
import 'resume_photo.dart';
import 'resume_photo_crop.dart';
import 'sign_out_dialog.dart';

class AddFriendSheet extends StatefulWidget {
  const AddFriendSheet({super.key, required this.store});
  final AppStore store;
  @override
  State<AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends State<AddFriendSheet> {
  final query = TextEditingController();
  List<Map<String, dynamic>> results = [];
  bool loading = false, searched = false;
  String? error;
  Future<void> search() async {
    if (query.text.trim().isEmpty) return;
    dismissKeyboard();
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await widget.store.request(
        'GetUsersSearch',
        query: {'query': query.text.trim()},
      );
      if (mounted) {
        setState(() {
          results = items(response.data);
          searched = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      24,
      8,
      24,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '找到一起进步的人',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: query,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => search(),
          decoration: InputDecoration(
            hintText: '搜索昵称或博简 ID',
            suffixIcon: IconButton(
              onPressed: loading ? null : search,
              tooltip: '搜索用户',
              icon: const AppIcon(AppIcons.search),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (loading) const Center(child: CircularProgressIndicator()),
        if (error != null)
          Text(error!, style: TextStyle(color: context.colors.muted)),
        if (searched && results.isEmpty && error == null)
          Text('没有找到匹配的用户。', style: TextStyle(color: context.colors.muted)),
        for (final user in results)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(userDisplayName(user['display_name'])),
            subtitle: Text('${user['public_id'] ?? ''}'),
            trailing: TextButton(
              onPressed: user['relationship'] != 'NONE'
                  ? null
                  : () async {
                      final sent = await runRequest(context, () async {
                        await widget.store.request(
                          'PostFriendRequests',
                          body: {
                            'addressee_id': integer(user['id']),
                            'message': '',
                          },
                        );
                      });
                      if (sent && mounted) {
                        setState(() => user['relationship'] = 'OUTGOING');
                      }
                    },
              child: Text(
                user['relationship'] == 'FRIEND'
                    ? '已是好友'
                    : user['relationship'] == 'OUTGOING'
                    ? '已申请'
                    : '添加',
              ),
            ),
          ),
      ],
    ),
  );
  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }
}

enum _ProfileMenuPage { drafts, settings, points, developerVerification, scan }

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.store});
  final AppStore store;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

Future<void> _editProfile(
  BuildContext context,
  AppStore store, {
  ProfileEditAction? directAction,
}) async {
  if (!store.isAuthenticated ||
      ModalRoute.of(context)?.isCurrent != true ||
      !TickerMode.valuesOf(context).enabled) {
    return;
  }
  final epoch = store.epoch;
  final action = directAction ?? await showProfileEditActions(context);
  if (action == null ||
      !context.mounted ||
      !store.isAuthenticated ||
      store.epoch != epoch ||
      ModalRoute.of(context)?.isCurrent != true ||
      !TickerMode.valuesOf(context).enabled) {
    return;
  }
  await openPage(context, ProfileEditor(store: store, action: action));
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  final scroll = ScrollController();
  final nameMarker = GlobalKey();
  final headerMarker = GlobalKey();
  final headerSurfaceMarker = GlobalKey();
  bool openingMenu = false;
  final viewportMarker = GlobalKey();
  final headerOverlap = SliverOverlapAbsorberHandle();
  late final pull = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  AppStore get store => widget.store;
  double pullDistance = 0;
  bool pullingFromTop = false, openingDetails = false;
  bool compactHeader = false, measuringName = false;
  double? nameContentTop;
  double headerHeight = 400;
  int pullGeneration = 0;
  int? headerPointer;
  static const detailsThreshold = 120.0, refreshThreshold = 48.0;

  @override
  void initState() {
    super.initState();
    scroll.addListener(profileScrolled);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    scheduleNameMeasurement();
  }

  void profileScrolled() {
    updateCompactHeader();
    scheduleNameMeasurement();
  }

  void updateCompactHeader() {
    if (!mounted) return;
    final top = nameContentTop;
    final show =
        store.isAuthenticated &&
        scroll.hasClients &&
        top != null &&
        scroll.offset > top * .5 + .001;
    if (show != compactHeader) setState(() => compactHeader = show);
  }

  void scheduleNameMeasurement() {
    if (measuringName) return;
    measuringName = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      measuringName = false;
      if (!mounted || !scroll.hasClients) return;
      final headerBox = headerMarker.currentContext?.findRenderObject();
      if (headerBox is RenderBox && headerBox.hasSize) {
        final restingHeight =
            headerBox.size.height - pull.value * ProfileHeader.pullExtent;
        if ((restingHeight - headerHeight).abs() > .1) {
          setState(() => headerHeight = restingHeight);
        }
      }
      final nameBox = nameMarker.currentContext?.findRenderObject();
      final viewport = viewportMarker.currentContext?.findRenderObject();
      if (nameBox is RenderBox &&
          nameBox.hasSize &&
          viewport is RenderBox &&
          viewport.hasSize) {
        nameContentTop =
            nameBox.localToGlobal(Offset.zero, ancestor: viewport).dy +
            scroll.offset -
            MediaQuery.paddingOf(context).top;
      }
      updateCompactHeader();
    });
  }

  @override
  void dispose() {
    pull.dispose();
    scroll.dispose();
    headerOverlap.dispose();
    super.dispose();
  }

  void settlePull() {
    pull.animateBack(
      0,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void cancelPull() {
    if (!mounted) return;
    pullGeneration++;
    pullingFromTop = false;
    pullDistance = 0;
    settlePull();
  }

  void releasePull() {
    if (!pullingFromTop && pull.value == 0) return;
    final generation = pullGeneration;
    final epoch = store.epoch;
    final expand = pullingFromTop && pullDistance >= detailsThreshold;
    final refresh = pullingFromTop && pullDistance >= refreshThreshold;
    pullingFromTop = false;
    pullDistance = 0;
    if (!expand) settlePull();
    if (!refresh || !store.isAuthenticated) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != pullGeneration ||
          epoch != store.epoch ||
          !store.isAuthenticated ||
          ModalRoute.of(context)?.isCurrent != true ||
          !TickerMode.valuesOf(context).enabled) {
        if (mounted && generation == pullGeneration) settlePull();
        return;
      }
      unawaited(store.load('profile'));
      if (expand) unawaited(showDetails());
    });
  }

  bool onScroll(ScrollNotification notification) {
    // NestedScrollView sends outer notifications at 0 and tab-list notifications at 2.
    if (!mounted ||
        (notification.depth != 0 && notification.depth != 2) ||
        axisDirectionToAxis(notification.metrics.axisDirection) !=
            Axis.vertical) {
      return false;
    }
    final source = notification.context;
    if (notification.depth == 2 &&
        (source == null ||
            !source.mounted ||
            !TickerMode.valuesOf(source).enabled)) {
      return false;
    }
    if (notification is ScrollStartNotification &&
        notification.depth == 0 &&
        notification.dragDetails != null) {
      pullGeneration++;
      pullingFromTop =
          headerPointer != null &&
          store.isAuthenticated &&
          !openingDetails &&
          scroll.hasClients &&
          scroll.offset <= scroll.position.minScrollExtent + .5 &&
          notification.metrics.pixels <=
              notification.metrics.minScrollExtent + .5;
      pullDistance = 0;
    } else if (pullingFromTop &&
        notification is OverscrollNotification &&
        notification.dragDetails != null &&
        notification.overscroll < 0) {
      final wasArmed = pullDistance >= detailsThreshold;
      pullDistance = (pullDistance - notification.overscroll)
          .clamp(0.0, 240.0)
          .toDouble();
      pull.value = (pullDistance / detailsThreshold).clamp(0.0, 1.0);
      if (!wasArmed && pullDistance >= detailsThreshold) {
        HapticFeedback.selectionClick();
      }
    } else if (pullingFromTop &&
        notification is ScrollUpdateNotification &&
        notification.metrics.pixels >
            notification.metrics.minScrollExtent + .5) {
      cancelPull();
    } else if (notification is ScrollEndNotification) {
      releasePull();
    }
    return false;
  }

  Future<void> showDetails() async {
    if (openingDetails ||
        !store.isAuthenticated ||
        ModalRoute.of(context)?.isCurrent != true ||
        !TickerMode.valuesOf(context).enabled) {
      return;
    }
    openingDetails = true;
    final currentStore = store;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final box = headerMarker.currentContext?.findRenderObject();
    final navigatorBox = Navigator.of(context).context.findRenderObject();
    if (box is! RenderBox || navigatorBox is! RenderBox) {
      openingDetails = false;
      settlePull();
      return;
    }
    pull.stop();
    final origin =
        box.localToGlobal(Offset.zero, ancestor: navigatorBox) & box.size;
    final initialPull = pull.value;
    final initialScrollOffset = scroll.offset;
    final initialCollapse = Curves.easeInOutCubic.transform(
      (initialScrollOffset / (nameContentTop ?? 174)).clamp(0, 1),
    );
    final surfaceBox = headerSurfaceMarker.currentContext?.findRenderObject();
    final initialSurfaceHeight = surfaceBox is RenderBox && surfaceBox.hasSize
        ? surfaceBox.size.height
        : 0.0;
    final returnOrigin = Rect.fromLTWH(
      origin.left,
      origin.top,
      origin.width,
      origin.height - initialPull * ProfileHeader.pullExtent,
    );
    final route = PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          ProfileDetailsPage(
            store: currentStore,
            origin: origin,
            returnOrigin: returnOrigin,
            initialPull: initialPull,
            initialScrollOffset: initialScrollOffset,
            initialCollapse: initialCollapse,
            initialSurfaceHeight: initialSurfaceHeight,
            expansion: animation,
            onEdit: (context) => _editProfile(context, currentStore),
            onAvatar: (context) => _editProfile(
              context,
              currentStore,
              directAction: ProfileEditAction.avatar,
            ),
          ),
      transitionDuration: reduced
          ? Duration.zero
          : const Duration(milliseconds: 380),
      reverseTransitionDuration: reduced
          ? Duration.zero
          : const Duration(milliseconds: 320),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          child,
    );
    void prepareRestingHeader(AnimationStatus status) {
      if (status == AnimationStatus.completed && mounted) {
        // The opaque details now cover the source. Restore its layout before
        // the return Hero measures it, rather than springing back after pop.
        pull.value = 0;
      }
    }

    final navigation = Navigator.of(context).push<void>(route);
    final animation = route.animation!;
    animation.addStatusListener(prepareRestingHeader);
    prepareRestingHeader(animation.status);
    try {
      await navigation;
      // push() completes at the start of pop; keep the source stable and block
      // another open until the reverse transition actually removes its overlay.
      await route.completed;
    } finally {
      animation.removeStatusListener(prepareRestingHeader);
      openingDetails = false;
      if (mounted && pull.value > 0) settlePull();
    }
  }

  Future<void> editAvatar() async {
    if (openingDetails ||
        openingMenu ||
        !store.isAuthenticated ||
        ModalRoute.of(context)?.isCurrent != true ||
        !TickerMode.valuesOf(context).enabled) {
      return;
    }
    cancelPull();
    await _editProfile(context, store, directAction: ProfileEditAction.avatar);
  }

  Future<void> openMenu() async {
    if (openingMenu ||
        !store.isAuthenticated ||
        ModalRoute.of(context)?.isCurrent != true ||
        !TickerMode.valuesOf(context).enabled) {
      return;
    }
    cancelPull();
    openingMenu = true;
    unawaited(store.load('identity'));
    final epoch = store.epoch;
    final reduced = MediaQuery.disableAnimationsOf(context);
    bool closing = false, openingDestination = false;
    Future<void> openDestination(
      BuildContext menuContext,
      _ProfileMenuPage destination,
    ) async {
      if (openingDestination ||
          !menuContext.mounted ||
          !store.isAuthenticated ||
          store.epoch != epoch ||
          ModalRoute.of(menuContext)?.isCurrent != true) {
        return;
      }
      openingDestination = true;
      try {
        await openPage<void>(menuContext, switch (destination) {
          _ProfileMenuPage.drafts => MyArticlesPage(
            store: store,
            draftsOnly: true,
          ),
          _ProfileMenuPage.settings => SettingsPage(store: store),
          _ProfileMenuPage.scan => AppQRLoginPage(store: store),
          _ProfileMenuPage.developerVerification => DeveloperVerificationPage(
            store: store,
          ),
          _ProfileMenuPage.points => Scaffold(
            appBar: AppBar(title: const Text('我的积分')),
            body: PointsPage(store: store),
          ),
        });
      } finally {
        openingDestination = false;
      }
    }

    try {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: MaterialLocalizations.of(context)
            .modalBarrierDismissLabel,
        transitionDuration: reduced
            ? Duration.zero
            : const Duration(milliseconds: 240),
        pageBuilder: (menuContext, animation, secondaryAnimation) =>
            ListenableBuilder(
              listenable: store,
              builder: (context, _) {
                if (!store.isAuthenticated || store.epoch != epoch) {
                  if (!closing) {
                    closing = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!menuContext.mounted) return;
                      final route = ModalRoute.of(menuContext);
                      if (route == null || !route.isActive) return;
                      final navigator = Navigator.of(menuContext);
                      if (route.isCurrent) {
                        navigator.pop();
                      } else {
                        navigator.removeRoute(route);
                      }
                    });
                  }
                  return const SizedBox.shrink();
                }
                return AnnotatedRegion<SystemUiOverlayStyle>(
                  value: appSystemUiStyle(context),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Drawer(
                      key: const ValueKey('profile-drawer'),
                      width: (MediaQuery.sizeOf(context).width * .8).clamp(
                        0.0,
                        280.0,
                      ),
                      backgroundColor: context.colors.surface,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadiusDirectional.horizontal(
                          end: Radius.circular(12),
                        ),
                      ),
                      child: SafeArea(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                              child: Row(
                                children: [
                                  Semantics(
                                    label: '关闭菜单',
                                    button: true,
                                    excludeSemantics: true,
                                    onTap: () =>
                                        Navigator.of(menuContext).pop(),
                                    child: IconButton(
                                      key: const ValueKey('profile-menu-close'),
                                      tooltip: '关闭菜单',
                                      style: IconButton.styleFrom(
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      constraints:
                                          const BoxConstraints.tightFor(
                                            width: 44,
                                            height: 44,
                                          ),
                                      onPressed: () =>
                                          Navigator.of(menuContext).pop(),
                                      icon: const AppIcon(
                                        AppIcons.close,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Semantics(
                                    label: '扫一扫',
                                    button: true,
                                    enabled: true,
                                    excludeSemantics: true,
                                    onTap: () => openDestination(
                                      menuContext,
                                      _ProfileMenuPage.scan,
                                    ),
                                    child: IconButton(
                                      key: const ValueKey('profile-menu-scan'),
                                      style: IconButton.styleFrom(
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      constraints:
                                          const BoxConstraints.tightFor(
                                            width: 44,
                                            height: 44,
                                          ),
                                      onPressed: () => openDestination(
                                        menuContext,
                                        _ProfileMenuPage.scan,
                                      ),
                                      icon: const AppIcon(
                                        AppIcons.scan,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  4,
                                  12,
                                  12,
                                ),
                                children: [
                                  _ProfileMenuIdentity(
                                    store: store,
                                    onPoints: () => openDestination(
                                      menuContext,
                                      _ProfileMenuPage.points,
                                    ),
                                  ),
                                  _menu(
                                    context,
                                    '草稿箱',
                                    AppIcons.folder,
                                    () => openDestination(
                                      menuContext,
                                      _ProfileMenuPage.drafts,
                                    ),
                                  ),
                                  _menu(
                                    context,
                                    '隐私与设置',
                                    AppIcons.settings,
                                    () => openDestination(
                                      menuContext,
                                      _ProfileMenuPage.settings,
                                    ),
                                  ),
                                  if (store.canApplyDeveloperVerification)
                                    _menu(
                                      context,
                                      '申请开发者认证',
                                      AppIcons.identityVerification,
                                      () => openDestination(
                                        menuContext,
                                        _ProfileMenuPage.developerVerification,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              child: _SignOutButton(store: store),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        transitionBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
              position: Tween(begin: const Offset(-1, 0), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeOutCubic))
                  .animate(animation),
              child: child,
            ),
      );
    } finally {
      openingMenu = false;
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      scheduleNameMeasurement();
      const contentTabs = ProfileContentTabs();

      final collapsedHeight =
          ProfileHeader.toolbarHeight(context) +
          MediaQuery.paddingOf(context).top;
      return AnnotatedRegion<SystemUiOverlayStyle>(
        key: const ValueKey('profile-system-ui'),
        value: compactHeader || !store.isAuthenticated
            ? appSystemUiStyle(context)
            : appSystemUiStyle(context).copyWith(
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.dark,
                systemStatusBarContrastEnforced: false,
              ),
        child: ColoredBox(
          color: context.colors.surface,
          child: !store.isAuthenticated
              ? SafeArea(
                  bottom: false,
                  child: DataStatus(
                    store: store,
                    section: 'profile',
                    empty: false,
                  ),
                )
              : DefaultTabController(
                  length: 3,
                  child: Listener(
                    onPointerUp: (event) {
                      if (headerPointer == event.pointer) headerPointer = null;
                    },
                    onPointerCancel: (event) {
                      if (headerPointer == event.pointer) headerPointer = null;
                      cancelPull();
                    },
                    child: NotificationListener<ScrollNotification>(
                      onNotification: onScroll,
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context)
                            .copyWith(overscroll: false),
                        child: SizedBox.expand(
                          key: viewportMarker,
                          child: NestedScrollView(
                            key: const ValueKey('profile-scroll'),
                            controller: scroll,
                            physics: const ClampingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            headerSliverBuilder: (context, innerScrolled) => [
                              SliverOverlapAbsorber(
                                handle: headerOverlap,
                                sliver: AnimatedBuilder(
                                  animation: pull,
                                  builder: (context, _) {
                                    scheduleNameMeasurement();
                                    return SliverPersistentHeader(
                                      pinned: true,
                                      delegate: ProfileHeaderSliver(
                                        expandedHeight:
                                            headerHeight +
                                            pull.value *
                                                ProfileHeader.pullExtent,
                                        collapsedHeight: collapsedHeight,
                                        collapseExtent: nameContentTop ?? 174,
                                        headerBuilder: (offset, progress) =>
                                            Listener(
                                              behavior:
                                                  HitTestBehavior.translucent,
                                              onPointerDown: (event) =>
                                                  headerPointer ??=
                                                      event.pointer,
                                              child: ProfileHeader(
                                                key: headerMarker,
                                                store: store,
                                                nameKey: nameMarker,
                                                surfaceKey: headerSurfaceMarker,
                                                pullProgress: pull.value,
                                                scrollOffset: offset,
                                                collapseProgress: progress,
                                                onEdit: () => _editProfile(
                                                  context,
                                                  store,
                                                ),
                                                onAvatar: editAvatar,
                                                onMenu: openMenu,
                                                onDetails: () {
                                                  cancelPull();
                                                  unawaited(showDetails());
                                                },
                                              ),
                                            ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              SliverOverlapAbsorber(
                                handle:
                                    NestedScrollView.sliverOverlapAbsorberHandleFor(
                                      context,
                                    ),
                                sliver: SliverAppBar(
                                  primary: false,
                                  pinned: true,
                                  toolbarHeight: 0,
                                  automaticallyImplyLeading: false,
                                  backgroundColor: context.colors.surface,
                                  elevation: 0,
                                  scrolledUnderElevation: 0,
                                  surfaceTintColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  bottom: contentTabs,
                                ),
                              ),
                            ],
                            body: Padding(
                              padding: EdgeInsets.only(
                                top:
                                    collapsedHeight +
                                    contentTabs.preferredSize.height,
                              ),
                              child: TabBarView(
                                key: const ValueKey('profile-pages'),
                                children: [
                                  _ProfileContentTab(
                                    index: 0,
                                    child: MyArticlesPage(
                                      store: store,
                                      embedded: true,
                                      publishedOnly: true,
                                    ),
                                  ),
                                  _ProfileContentTab(
                                    index: 1,
                                    child: SavedArticlesPage(
                                      store: store,
                                      embedded: true,
                                    ),
                                  ),
                                  _ProfileContentTab(
                                    index: 2,
                                    child: ResumeLibrary(
                                      store: store,
                                      embedded: true,
                                    ),
                                  ),
                                ],
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
    },
  );

  Widget _menu(
    BuildContext context,
    String label,
    AppIconData icon,
    VoidCallback onTap,
  ) => Material(
    color: Colors.transparent,
    child: ListTile(
      minTileHeight: 48,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      horizontalTitleGap: 12,
      minLeadingWidth: 20,
      leading: AppIcon(icon, size: 20, color: context.colors.ink),
      title: Text(label, style: const TextStyle(fontSize: 13)),
      trailing: AppIcon(
        AppIcons.forward,
        size: 14,
        color: context.colors.muted,
      ),
      onTap: onTap,
    ),
  );
}

class _ProfileMenuIdentity extends StatelessWidget {
  const _ProfileMenuIdentity({required this.store, required this.onPoints});
  final AppStore store;
  final VoidCallback onPoints;

  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey('profile-menu-identity'),
    padding: const EdgeInsets.fromLTRB(8, 12, 8, 20),
    child: Row(
      children: [
        ProfileAvatar(
          seed: profileAvatarSeed(store),
          url: store.avatarURL,
          size: 44,
          borderRadius: 22,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userDisplayName(store.name),
                key: const ValueKey('profile-menu-name'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              InkWell(
                key: const ValueKey('profile-menu-points'),
                onTap: onPoints,
                child: Text(
                  '积分余额：${store.points ?? '—'}',
                  key: const ValueKey('profile-menu-balance'),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: context.colors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ProfileSurface extends StatelessWidget {
  const _ProfileSurface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: context.colors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: context.colors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

class _ProfileContentTab extends StatefulWidget {
  const _ProfileContentTab({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<_ProfileContentTab> createState() => _ProfileContentTabState();
}

class _ProfileContentTabState extends State<_ProfileContentTab>
    with AutomaticKeepAliveClientMixin {
  TabController? tabs;
  ScrollPosition? position;
  double? savedOffset;
  bool active = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = DefaultTabController.of(context);
    if (tabs != controller) {
      tabs?.removeListener(tabChanged);
      tabs = controller..addListener(tabChanged);
    }
    active = controller.index == widget.index;
  }

  void tabChanged() {
    final next = tabs!.index == widget.index;
    if (active == next) return;
    if (active) savedOffset = position?.pixels;
    setState(() => active = next);
    if (next && savedOffset != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            !active ||
            position == null ||
            !position!.hasContentDimensions) {
          return;
        }
        final offset = savedOffset!
            .clamp(position!.minScrollExtent, position!.maxScrollExtent)
            .toDouble();
        if ((position!.pixels - offset).abs() > .01) position!.jumpTo(offset);
      });
    }
  }

  @override
  void dispose() {
    tabs?.removeListener(tabChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.depth == 0 &&
            notification.metrics.axis == Axis.vertical &&
            notification.context != null) {
          position = Scrollable.maybeOf(
            notification.context!,
            axis: Axis.vertical,
          )?.position;
        }
        return false;
      },
      // A nested coordinator can move retained lists when another tab focuses
      // its search field. Restore the offset captured when this tab was left.
      child: FocusScope(
        canRequestFocus: active,
        child: TickerMode(enabled: active, child: widget.child),
      ),
    );
  }
}

class _SignOutButton extends StatefulWidget {
  const _SignOutButton({required this.store});
  final AppStore store;
  @override
  State<_SignOutButton> createState() => _SignOutButtonState();
}

class _SignOutButtonState extends State<_SignOutButton> {
  bool busy = false;
  @override
  Widget build(BuildContext context) => OutlinedButton(
    key: const ValueKey('account-sign-out'),
    style: OutlinedButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.error,
      backgroundColor: context.colors.surface,
      side: BorderSide(color: context.colors.border),
      minimumSize: const Size.fromHeight(44),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ).withoutHover(),
    onPressed: busy
        ? null
        : () async {
            final confirmed = await showSignOutDialog(context);
            if (!context.mounted || confirmed != true) return;
            setState(() => busy = true);
            await runRequest(context, widget.store.endSession);
            if (mounted) setState(() => busy = false);
          },
    child: Text(busy ? '正在退出…' : '退出登录'),
  );
}

class ProfileEditor extends StatefulWidget {
  const ProfileEditor({
    super.key,
    required this.store,
    this.action = ProfileEditAction.settings,
  });
  final AppStore store;
  final ProfileEditAction action;
  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  late final name = TextEditingController(text: widget.store.name);
  late final bio = TextEditingController(text: widget.store.bio);
  bool saving = false, choosing = false;
  int? selectedAvatar;
  XFile? selectedPhoto;
  String get avatarSeed => profileAvatarSeed(widget.store);
  int? get currentSystemAvatar =>
      selectedAvatar ??
      (selectedPhoto != null
          ? null
          : storedSystemAvatar(widget.store.avatarURL) ??
                (widget.store.avatarURL.isEmpty
                    ? assignedAvatar(avatarSeed)
                    : null));

  Future<void> chooseAvatar() async {
    if (saving || choosing) return;
    dismissKeyboard();
    setState(() => choosing = true);
    final epoch = widget.store.epoch;
    try {
      final choice = await showModalBottomSheet<Object>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: context.colors.surface,
        builder: (context) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .78,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '更换头像',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),
                Text(
                  '系统头像',
                  style: TextStyle(fontSize: 12, color: context.colors.muted),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: 12,
                    runSpacing: 14,
                    children: [
                      for (var i = 0; i < systemAvatarNames.length; i++)
                        SizedBox(
                          width: (constraints.maxWidth - 36) / 4,
                          child: Semantics(
                            selected: currentSystemAvatar == i,
                            child: InkWell(
                              key: ValueKey('system-avatar-$i'),
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => Navigator.pop(context, i),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        width: 2,
                                        color: currentSystemAvatar == i
                                            ? blue
                                            : Colors.transparent,
                                      ),
                                    ),
                                    child: ProfileAvatar(
                                      seed: '',
                                      variant: i,
                                      size:
                                          (constraints.maxWidth - 36) / 4 - 10,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    systemAvatarNames[i],
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: context.colors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, 'upload'),
                    icon: const AppIcon(AppIcons.avatarUpload, size: 20),
                    label: const Text('上传自己的头像'),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '支持 JPG、PNG、WebP，最大 5 MB',
                    style: TextStyle(fontSize: 11, color: context.colors.muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (!_canEdit(epoch)) return;
      if (choice is int) {
        final previous = selectedPhoto;
        setState(() {
          selectedAvatar = choice;
          selectedPhoto = null;
        });
        await discardResumePhotoCrop(previous);
      } else if (choice == 'upload') {
        await _pickAvatarPhoto(epoch);
      }
    } catch (e) {
      if (mounted && _canEdit(epoch)) toast(context, '$e');
    } finally {
      if (mounted) setState(() => choosing = false);
    }
  }

  bool _canEdit(int epoch) =>
      mounted &&
      widget.store.alive &&
      widget.store.isAuthenticated &&
      epoch == widget.store.epoch;

  Future<void> chooseLocalPhoto() async {
    if (saving || choosing) return;
    dismissKeyboard();
    final epoch = widget.store.epoch;
    setState(() => choosing = true);
    try {
      await _pickAvatarPhoto(epoch);
    } catch (e) {
      if (mounted && _canEdit(epoch)) toast(context, '$e');
    } finally {
      if (mounted) setState(() => choosing = false);
    }
  }

  Future<void> _pickAvatarPhoto(int epoch) async {
    final file = await pickAppGalleryPhoto();
    if (file == null || !_canEdit(epoch)) return;
    await validateResumePhoto(file);
    if (!mounted || !_canEdit(epoch)) return;
    final cropped = await openPage<XFile>(
      context,
      ResumePhotoCropPage(file: file, aspectRatio: 1),
    );
    if (!_canEdit(epoch)) {
      await discardResumePhotoCrop(cropped);
      return;
    }
    if (cropped != null) {
      final previous = selectedPhoto;
      setState(() {
        selectedPhoto = cropped;
        selectedAvatar = null;
      });
      await discardResumePhotoCrop(previous);
    }
  }

  Future<void> saveProfile() async {
    if (saving || choosing) return;
    if (widget.action == ProfileEditAction.settings &&
        name.text.trim().isEmpty) {
      toast(context, '给自己取一个昵称吧');
      return;
    }
    dismissKeyboard();
    setState(() => saving = true);
    final epoch = widget.store.epoch;
    final saved = await runRequest(context, () async {
      XFile? generated;
      try {
        if (selectedAvatar != null) {
          generated = await createSystemAvatarFile(selectedAvatar!);
        }
        final photo = generated ?? selectedPhoto;
        if (photo != null) {
          await uploadProfileAvatar(widget.store, photo);
          if (mounted) {
            setState(() {
              selectedAvatar = null;
            });
          }
          await discardResumePhotoCrop(selectedPhoto);
          selectedPhoto = null;
        }
        if (epoch != widget.store.epoch) return;
        if (widget.action != ProfileEditAction.avatar) {
          await widget.store.updateProfile(
            name.text.trim(),
            bio.text.trim(),
            updateName: widget.action == ProfileEditAction.settings,
          );
        }
      } finally {
        if (generated != null) await discardSystemAvatarFile(generated);
      }
    });
    if (!mounted || epoch != widget.store.epoch) return;
    if (saved) {
      setState(() => saving = false);
      Navigator.pop(context);
      toast(context, '个人资料已更新');
    } else {
      setState(() => saving = false);
    }
  }

  Widget _avatarSection() => _ProfileSurface(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: '更换个人头像',
            button: true,
            child: InkWell(
              onTap: saving || choosing ? null : chooseAvatar,
              borderRadius: BorderRadius.circular(30),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: context.colors.canvas,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: ProfileAvatar(
                      seed: avatarSeed,
                      url: widget.store.avatarURL,
                      variant: selectedAvatar,
                      file: selectedPhoto,
                      size: 84,
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: const AppIcon(
                        AppIcons.avatarEdit,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              textStyle: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
            ).withoutHover(),
            onPressed: saving || choosing ? null : chooseAvatar,
            child: Text(choosing ? '选择中…' : '更换头像'),
          ),
        ],
      ),
    ),
  );

  Widget _profileField(
    TextEditingController controller,
    String label,
    int limit, {
    bool multiline = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => Text(
              '${value.text.characters.length}/$limit',
              style: TextStyle(fontSize: 10, color: context.colors.muted),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      TextField(
        key: ValueKey(multiline ? 'profile-bio' : 'profile-name'),
        controller: controller,
        enabled: !saving,
        textInputAction: multiline
            ? TextInputAction.newline
            : TextInputAction.next,
        minLines: multiline ? 4 : 1,
        maxLines: multiline ? 6 : 1,
        maxLength: limit,
        buildCounter: (
          _, {
          required currentLength,
          required isFocused,
          maxLength,
        }) => null,
        style: TextStyle(
          fontSize: multiline ? 14 : 16,
          height: 1.6,
          fontWeight: multiline ? FontWeight.w400 : FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: multiline ? '介绍一下自己' : '填写你的昵称',
          fillColor: context.colors.canvas,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
        ),
      ),
    ],
  );

  Widget _detailsSection() => _ProfileSurface(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.action == ProfileEditAction.settings) ...[
            _profileField(name, '昵称', 20),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 20),
          ],
          _profileField(bio, '个人简介', 120, multiline: true),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (widget.action == ProfileEditAction.avatar) {
      return PopScope(
        canPop: !saving,
        child: ProfileAvatarEditorView(
          preview: (size) => ProfileAvatar(
            seed: avatarSeed,
            url: widget.store.avatarURL,
            variant: selectedAvatar,
            file: selectedPhoto,
            size: size,
            borderRadius: 0,
          ),
          saving: saving,
          choosing: choosing,
          hasChanges: selectedAvatar != null || selectedPhoto != null,
          onGallery: chooseLocalPhoto,
          onSystemAvatar: chooseAvatar,
          onSave: saveProfile,
        ),
      );
    }
    if (widget.action == ProfileEditAction.bio) {
      return PopScope(
        canPop: !saving,
        child: ProfileBiographyEditorView(
          controller: bio,
          saving: saving,
          onSave: saveProfile,
        ),
      );
    }
    return PopScope(
      canPop: !saving,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('编辑个人资料'),
          actions: const [DismissKeyboardButton()],
        ),
        body: GestureDetector(
          onTap: dismissKeyboard,
          behavior: HitTestBehavior.translucent,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: LayoutBuilder(
                builder: (context, constraints) => ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  children: [
                    if (constraints.maxWidth >= 600)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 190, child: _avatarSection()),
                          const SizedBox(width: 16),
                          Expanded(child: _detailsSection()),
                        ],
                      )
                    else ...[
                      _avatarSection(),
                      const SizedBox(height: 16),
                      _detailsSection(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              border: Border(top: BorderSide(color: context.colors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const ValueKey('profile-save'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ).withoutHover(),
                        onPressed: saving || choosing ? null : saveProfile,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (saving) ...[
                              const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Text(saving ? '正在保存…' : '保存资料'),
                          ],
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
    discardResumePhotoCrop(selectedPhoto);
    name.dispose();
    bio.dispose();
    super.dispose();
  }
}

class VerificationPage extends StatefulWidget {
  const VerificationPage({super.key, required this.store});
  final AppStore store;
  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  late Future<Map<String, dynamic>> result = load();
  Future<Map<String, dynamic>> load() async =>
      (await widget.store.request('GetMeIdentityVerification')).data;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('身份认证')),
    body: FutureBuilder(
      future: result,
      builder: (context, snapshot) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AppIcon(
            AppIcons.identityVerification,
            size: 54,
            color: context.colors.accent,
          ),
          const SizedBox(height: 24),
          if (snapshot.connectionState == ConnectionState.waiting)
            const Center(child: CircularProgressIndicator())
          else if (snapshot.hasError) ...[
            Text('${snapshot.error}'),
            TextButton(
              onPressed: () => setState(() => result = load()),
              child: const Text('重试'),
            ),
          ] else ...[
            Text(
              switch (snapshot.data?['status']) {
                'APPROVED' => '已认证',
                'PENDING' => '审核中',
                'REJECTED' => '认证未通过',
                _ => '尚未认证',
              },
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            Text(
              '提交证件资料请使用博简桌面端，认证结果会同步到这里。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.8,
                color: context.colors.muted,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
