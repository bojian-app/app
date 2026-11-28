import 'app_page_bar.dart';
import 'playful_refresh.dart';

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
import 'app_update.dart';
import 'app_photo_picker.dart';
import 'developer_verification_page.dart';
import 'design.dart';
import 'membership_page.dart';
import 'order_history_page.dart';
import 'my_articles_page.dart';
import 'saved_articles_page.dart';
import 'resume_pages.dart';
import 'resume_market_document.dart' show MarketThemeCache;
import 'resume_thumbnail.dart' show ThumbnailSheetCache;
import 'story_composer.dart';
import 'profile_avatar.dart';
import 'profile_identity.dart';
import 'profile_edit_actions.dart';
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
            hintText: '搜索昵称或Z优简 ID',
            suffixIcon: IconButton(
              onPressed: loading ? null : search,
              tooltip: '搜索用户',
              icon: const AppIcon(AppIcons.search),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (loading) const DotMatrixLoader(compact: true),
        if (error != null)
          Text(error!, style: TextStyle(color: context.colors.muted)),
        if (searched && results.isEmpty && error == null)
          const EmptyState(
            '没有找到匹配的用户。',
            '试试其他昵称或Z优简 ID',
            art: EmptyArt.search,
            compact: true,
          ),
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

enum _ProfileMenuPage {
  drafts,
  settings,
  membership,
  orderHistory,
  developerVerification,
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.store, this.onExit});
  final AppStore store;
  final VoidCallback? onExit;
  @override
  State<ProfilePage> createState() => _ProfilePageState();

  /// The account whose resume covers are already typeset, so only a visit
  /// that beats the warm-up has to wait for them.
  static int? _warmedEpoch, _warmingEpoch;
  static Future<void>? _warming;

  static bool isWarm(AppStore store) => _warmedEpoch == store.epoch;

  /// Typesets the first resume covers (and fetches the theme packages of the
  /// template ones) in the background, one step per turn of the event loop,
  /// so opening this page later finds everything ready. Safe to call often.
  static Future<void> prewarm(AppStore store) {
    final epoch = store.epoch;
    if (_warmedEpoch == epoch) return Future.value();
    if (_warmingEpoch == epoch) return _warming!;
    _warmingEpoch = epoch;
    return _warming = _warm(store, epoch).whenComplete(() {
      if (_warmingEpoch == epoch) _warmingEpoch = null;
    });
  }

  static Future<void> _warm(AppStore store, int epoch) async {
    bool valid() => store.epoch == epoch;
    final waited = Stopwatch()..start();
    while (valid() &&
        store.isAuthenticated &&
        store.loading.contains('resumes') &&
        waited.elapsed < const Duration(seconds: 5)) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
    if (!valid() || !store.isAuthenticated) return;
    final first = store.resumes.take(9).toList();
    await Future.wait([
      for (final resume in first)
        if (resume.usesMarketTemplate)
          MarketThemeCache.fetch(
            store,
            resume,
          ).timeout(const Duration(seconds: 6), onTimeout: () => null),
    ]);
    await ThumbnailSheetCache.warm(
      first,
      valid: valid,
      themeOf: (resume) => MarketThemeCache.get(store, resume.marketTemplateID),
    );
    if (valid()) _warmedEpoch = epoch;
  }
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
    with LoadingHoldState<ProfilePage> {
  late bool warmed = ProfilePage.isWarm(store);
  final scroll = ScrollController();
  final nameMarker = GlobalKey();
  final headerMarker = GlobalKey();
  final headerSurfaceMarker = GlobalKey();
  bool openingSettings = false, openingCreation = false;
  final viewportMarker = GlobalKey();
  final headerOverlap = SliverOverlapAbsorberHandle();
  AppStore get store => widget.store;
  bool openingDetails = false;
  final compactHeader = ValueNotifier<bool>(false);
  bool measuringName = false;
  double? nameContentTop;
  double headerHeight = 400;
  int? profilePointer;

  @override
  void initState() {
    super.initState();
    scroll.addListener(profileScrolled);
    if (!warmed) unawaited(warmUp());
  }

  /// Waits for the shared warm-up, so switching to the resume tab afterwards
  /// does not stall on laying the covers out.
  Future<void> warmUp() async {
    final epoch = store.epoch;
    await ProfilePage.prewarm(store);
    if (!mounted || store.epoch != epoch) return;
    setState(() => warmed = true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    scheduleNameMeasurement();
  }

  void profileScrolled() {
    // Scrolling only flips a notifier; measuring and page-wide rebuilds are
    // kept off the scroll path so a fast fling cannot hitch on them.
    updateCompactHeader();
    if (nameContentTop == null) scheduleNameMeasurement();
  }

  void updateCompactHeader() {
    if (!mounted) return;
    final top = nameContentTop;
    final show =
        store.isAuthenticated &&
        scroll.hasClients &&
        top != null &&
        scroll.offset >= top - .5;
    compactHeader.value = show;
  }

  void scheduleNameMeasurement() {
    if (measuringName) return;
    measuringName = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      measuringName = false;
      if (!mounted || !scroll.hasClients) return;
      final headerBox = headerMarker.currentContext?.findRenderObject();
      if (headerBox is RenderBox && headerBox.hasSize) {
        final restingHeight = headerBox.size.height;
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
        final measured =
            nameBox.localToGlobal(Offset.zero, ancestor: viewport).dy +
            scroll.offset -
            MediaQuery.paddingOf(context).top;
        final previous = nameContentTop;
        nameContentTop = measured;
        if (previous == null || (previous - measured).abs() > .5) {
          // The sliver delegate reads this as its collapse extent, so a changed
          // measurement must reach it without waiting for another rebuild.
          setState(() {});
        }
      }
      updateCompactHeader();
    });
  }

  @override
  void dispose() {
    scroll.dispose();
    compactHeader.dispose();
    headerOverlap.dispose();
    super.dispose();
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
      return;
    }
    final origin =
        box.localToGlobal(Offset.zero, ancestor: navigatorBox) & box.size;
    const initialPull = 0.0;
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
    final navigation = Navigator.of(context).push<void>(route);
    try {
      await navigation;
      // push() completes at the start of pop; keep the source stable and block
      // another open until the reverse transition actually removes its overlay.
      await route.completed;
    } finally {
      openingDetails = false;
    }
  }

  Future<void> editAvatar() async {
    if (openingDetails ||
        openingSettings ||
        !store.isAuthenticated ||
        ModalRoute.of(context)?.isCurrent != true ||
        !TickerMode.valuesOf(context).enabled) {
      return;
    }
    await _editProfile(context, store, directAction: ProfileEditAction.avatar);
  }

  Future<void> openCreation(bool resume) async {
    if (openingCreation ||
        !store.isAuthenticated ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    setState(() => openingCreation = true);
    try {
      if (resume) {
        await ResumeLibrary(store: store).showAddOptions(context);
      } else {
        await openPage(context, StoryComposer(store: store));
      }
    } finally {
      if (mounted) setState(() => openingCreation = false);
    }
  }

  Future<void> openSettings() async {
    if (openingSettings ||
        !store.isAuthenticated ||
        ModalRoute.of(context)?.isCurrent != true ||
        !TickerMode.valuesOf(context).enabled) {
      return;
    }
    openingSettings = true;
    try {
      await openPage(context, SettingsPage(store: store));
    } finally {
      openingSettings = false;
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      scheduleNameMeasurement();
      final contentTabs = ProfileContentTabs(
        trailing: Builder(
          builder: (context) {
            final controller = DefaultTabController.of(context);
            return ListenableBuilder(
              listenable: Listenable.merge([controller, controller.animation]),
              builder: (context, _) {
                // Taps set the destination immediately; swipes only commit
                // controller.index at scroll end, so follow the visible page.
                final index = controller.indexIsChanging
                    ? controller.index
                    : controller.animation!.value.round().clamp(
                        0,
                        controller.length - 1,
                      );
                final isResume = index == 0;
                return Visibility(
                  visible: index == 0 || index == 2,
                  child: InkWell(
                    key: ValueKey(
                      isResume
                          ? 'profile-add-resume'
                          : 'profile-publish-article',
                    ),
                    borderRadius: BorderRadius.circular(6),
                    onTap: openingCreation
                        ? null
                        : () => openCreation(isResume),
                    child: Center(
                      widthFactor: 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppIcon(
                              AppIcons.add,
                              size: 12,
                              color: context.colors.accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isResume ? '添加简历' : '发表动态',
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.2,
                                fontWeight: FontWeight.w500,
                                color: context.colors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      );

      final collapsedHeight =
          ProfileHeader.toolbarHeight(context) +
          MediaQuery.paddingOf(context).top;
      scheduleNameMeasurement();
      final systemUiBase = appSystemUiStyle(context);
      final showLoading = holdLoading(store.isAuthenticated && !warmed);
      return ValueListenableBuilder<bool>(
        valueListenable: compactHeader,
        builder: (context, compact, child) =>
            AnnotatedRegion<SystemUiOverlayStyle>(
              key: const ValueKey('profile-system-ui'),
              value: compact || !store.isAuthenticated || showLoading
                  ? systemUiBase
                  : systemUiBase.copyWith(
                      statusBarIconBrightness: Brightness.light,
                      statusBarBrightness: Brightness.dark,
                      systemStatusBarContrastEnforced: false,
                    ),
              child: child!,
            ),
        child: ColoredBox(
          color: context.colors.surface,
          child: Stack(
            children: [
              Positioned.fill(
                child: !store.isAuthenticated
                    ? Scaffold(
                        backgroundColor: context.colors.surface,
                        appBar: AppPageBar(
                          leading: widget.onExit == null
                              ? null
                              : BackButton(onPressed: widget.onExit),
                          title: const Text('我的'),
                        ),
                        body: SafeArea(
                          child: DataStatus(
                            store: store,
                            section: 'profile',
                            empty: false,
                          ),
                        ),
                      )
                    : DefaultTabController(
                        length: 4,
                        child: PlayfulRefreshScope(
                          enabled: true,
                          child: Listener(
                            onPointerDown: (event) {
                              if (profilePointer != null) return;
                              profilePointer = event.pointer;
                            },
                            onPointerUp: (event) {
                              if (profilePointer == event.pointer) {
                                profilePointer = null;
                              }
                            },
                            onPointerCancel: (event) {
                              if (profilePointer == event.pointer) {
                                profilePointer = null;
                              }
                            },
                            child: NotificationListener<ScrollNotification>(
                              onNotification: onScroll,
                              child: ScrollConfiguration(
                                behavior: ScrollConfiguration.of(context)
                                    .copyWith(
                                      overscroll: false,
                                      physics: const ClampingScrollPhysics(),
                                    ),
                                child: SizedBox.expand(
                                  key: viewportMarker,
                                  child: NestedScrollView(
                                    key: const ValueKey('profile-scroll'),
                                    controller: scroll,
                                    physics: const ClampingScrollPhysics(
                                      parent: AlwaysScrollableScrollPhysics(),
                                    ),
                                    headerSliverBuilder:
                                        (context, innerScrolled) => [
                                          SliverOverlapAbsorber(
                                            handle: headerOverlap,
                                            sliver: SliverPersistentHeader(
                                              pinned: true,
                                              delegate: ProfileHeaderSliver(
                                                expandedHeight: headerHeight,
                                                collapsedHeight:
                                                    collapsedHeight,
                                                collapseExtent:
                                                    nameContentTop ?? 174,
                                                headerBuilder:
                                                    (
                                                      offset,
                                                      progress,
                                                    ) => ProfileHeader(
                                                      key: headerMarker,
                                                      store: store,
                                                      nameKey: nameMarker,
                                                      surfaceKey:
                                                          headerSurfaceMarker,
                                                      scrollOffset: offset,
                                                      collapseProgress:
                                                          progress,
                                                      onEdit: () =>
                                                          _editProfile(
                                                            context,
                                                            store,
                                                          ),
                                                      onAvatar: editAvatar,
                                                      onMenu: widget.onExit,
                                                      onSettings: openSettings,
                                                      onDetails: () =>
                                                          unawaited(
                                                            showDetails(),
                                                          ),
                                                    ),
                                              ),
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
                                              backgroundColor:
                                                  context.colors.surface,
                                              elevation: 0,
                                              scrolledUnderElevation: 0,
                                              surfaceTintColor:
                                                  Colors.transparent,
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
                                            child: ResumeLibrary(
                                              store: store,
                                              embedded: true,
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
                                            child: MyArticlesPage(
                                              store: store,
                                              embedded: true,
                                              publishedOnly: true,
                                            ),
                                          ),
                                          _ProfileContentTab(
                                            index: 3,
                                            child: MyArticlesPage(
                                              store: store,
                                              embedded: true,
                                              draftsOnly: true,
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
              ),
              // The page is built underneath so it is ready the moment this
              // view lifts; touches stay out until then.
              if (showLoading)
                Positioned.fill(
                  child: ColoredBox(
                    color: context.colors.surface,
                    child: Stack(
                      children: [
                        const Positioned.fill(child: DotMatrixLoader()),
                        if (widget.onExit != null)
                          SafeArea(
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  left: appPageHorizontalPadding - 12,
                                ),
                                child: IconButton(
                                  tooltip: '返回',
                                  onPressed: widget.onExit,
                                  icon: const AppIcon(AppIcons.back, size: 22),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showAccountMenu(BuildContext context, AppStore store) async {
  if (!store.isAuthenticated ||
      ModalRoute.of(context)?.isCurrent != true ||
      !TickerMode.valuesOf(context).enabled) {
    return;
  }
  dismissKeyboard();
  unawaited(store.load('identity'));
  unawaited(AppUpdates.instance.refresh(store));
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
        _ProfileMenuPage.membership => MembershipPage(store: store),
        _ProfileMenuPage.orderHistory => OrderHistoryPage(store: store),
        _ProfileMenuPage.developerVerification => DeveloperVerificationPage(
          store: store,
        ),
      });
    } finally {
      openingDestination = false;
    }
  }

  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
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
                                onTap: () => Navigator.of(menuContext).pop(),
                                child: IconButton(
                                  key: const ValueKey('profile-menu-close'),
                                  tooltip: '关闭菜单',
                                  style: IconButton.styleFrom(
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  constraints: const BoxConstraints.tightFor(
                                    width: 44,
                                    height: 44,
                                  ),
                                  onPressed: () =>
                                      Navigator.of(menuContext).pop(),
                                  icon: const AppIcon(AppIcons.close, size: 18),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                            children: [
                              _ProfileMenuIdentity(store: store),
                              if (membershipPageAvailable)
                                _menu(
                                  context,
                                  'Z优简会员',
                                  AppIcons.membership,
                                  () => openDestination(
                                    menuContext,
                                    _ProfileMenuPage.membership,
                                  ),
                                ),
                              _menu(
                                context,
                                '订单记录',
                                AppIcons.article,
                                () => openDestination(
                                  menuContext,
                                  _ProfileMenuPage.orderHistory,
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
                              ListenableBuilder(
                                listenable: AppUpdates.instance,
                                builder: (context, _) => _menu(
                                  context,
                                  '隐私与设置',
                                  AppIcons.settings,
                                  () => openDestination(
                                    menuContext,
                                    _ProfileMenuPage.settings,
                                  ),
                                  dot: AppUpdates.instance.hasUpdate,
                                ),
                              ),
                              if (store.canApplyDeveloperVerification)
                                _menu(
                                  context,
                                  '实名认证',
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
          position: Tween(
            begin: const Offset(-1, 0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
          child: child,
        ),
  );
}

Widget _menu(
  BuildContext context,
  String label,
  AppIconData icon,
  VoidCallback onTap, {
  bool dot = false,
}) => Material(
  color: Colors.transparent,
  child: ListTile(
    minTileHeight: 48,
    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    horizontalTitleGap: 12,
    minLeadingWidth: 20,
    leading: AppIcon(icon, size: 20, color: context.colors.ink),
    title: Text(label, style: const TextStyle(fontSize: 13)),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dot)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFE5322D),
              shape: BoxShape.circle,
            ),
          ),
        AppIcon(AppIcons.forward, size: 14, color: context.colors.muted),
      ],
    ),
    onTap: onTap,
  ),
);

class _ProfileMenuIdentity extends StatelessWidget {
  const _ProfileMenuIdentity({required this.store});
  final AppStore store;

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
            ],
          ),
        ),
      ],
    ),
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
  bool active = false;

  /// Whether the list has been through its first frame, which it spends joined.
  bool settled = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => settled = true);
    });
  }

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
    if (active != next) setState(() => active = next);
  }

  @override
  void dispose() {
    tabs?.removeListener(tabChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // NestedScrollView treats every attached inner list as one: an idle tab
    // resting at its top lets a drag or fling in the visible list expand the
    // header, and focus in one tab moves the others. Only the visible tab joins
    // the coordinator; switching controllers keeps each list's offset.
    //
    // A new list joins for its first frame even when idle. A swipe builds the
    // next page before it is the current one, and a list that started apart
    // would not hear of the change: it would never join, and the header would
    // stop following drags on it. Its scroll position also has to be made by
    // the coordinator to be able to return to it.
    final inner = PrimaryScrollController.maybeOf(context);
    final child = FocusScope(
      canRequestFocus: active,
      child: TickerMode(enabled: active, child: widget.child),
    );
    return (active || !settled) && inner != null
        ? PrimaryScrollController(
            // Matches the inheritance NestedScrollView gives its body.
            automaticallyInheritForPlatforms: TargetPlatform.values.toSet(),
            controller: inner,
            child: child,
          )
        : PrimaryScrollController.none(child: child);
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
  const ProfileEditor({super.key, required this.store, required this.action});
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
            padding: const EdgeInsets.fromLTRB(
              appPageHorizontalPadding,
              0,
              appPageHorizontalPadding,
              24,
            ),
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
                          // Five per row; floor so rounding never wraps early.
                          width: ((constraints.maxWidth - 48) / 5)
                              .floorToDouble(),
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
                                            ? context.colors.accent
                                            : Colors.transparent,
                                      ),
                                    ),
                                    child: ProfileAvatar(
                                      seed: '',
                                      variant: i,
                                      size:
                                          ((constraints.maxWidth - 48) / 5)
                                              .floorToDouble() -
                                          10,
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
    if (widget.action == ProfileEditAction.nickname &&
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
            updateName: widget.action == ProfileEditAction.nickname,
            updateBio: widget.action == ProfileEditAction.bio,
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

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: switch (widget.action) {
      ProfileEditAction.avatar => ProfileAvatarEditorView(
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
      ProfileEditAction.nickname => ProfileNicknameEditorView(
        controller: name,
        saving: saving,
        onSave: saveProfile,
      ),
      ProfileEditAction.bio => ProfileBiographyEditorView(
        controller: bio,
        saving: saving,
        onSave: saveProfile,
      ),
    },
  );

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
    appBar: AppPageBar(title: const Text('身份认证')),
    body: FutureBuilder(
      future: result,
      builder: (context, snapshot) => ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: appPageHorizontalPadding,
          vertical: 24,
        ),
        children: [
          AppIcon(
            AppIcons.identityVerification,
            size: 54,
            color: context.colors.accent,
          ),
          const SizedBox(height: 24),
          if (snapshot.connectionState == ConnectionState.waiting)
            const DotMatrixLoader(compact: true)
          else if (snapshot.hasError) ...[
            Text('${snapshot.error}'),
            TextButton(
              onPressed: () => setState(() => result = load()),
              child: const Text('重试'),
            ),
          ] else ...[
            Text(
              switch (snapshot.data?['status']) {
                'VERIFIED' || 'EXPIRED' => '已认证',
                'PENDING' => '审核中',
                'REJECTED' => '认证未通过',
                _ => '尚未认证',
              },
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            Text(
              '提交证件资料请使用Z优简桌面端，认证结果会同步到这里。',
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
