import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_icons.dart';
import 'app_store.dart';
import 'design.dart';
import 'profile_avatar.dart';
import 'profile_identity_data.dart';
export 'profile_identity_data.dart';
import 'messages_button.dart';
import 'user_id_label.dart';
import 'user_display_name.dart';

class ProfileBackdrop extends StatelessWidget {
  const ProfileBackdrop({super.key, required this.store, this.identity});
  final AppStore store;
  final ProfileIdentityData? identity;
  ProfileIdentityData get data =>
      identity ?? ProfileIdentityData.fromStore(store);

  @override
  Widget build(BuildContext context) {
    // Use the same canvas in the header and the expanded route. Resizing only
    // the visible clip keeps the photo crop, blur and gradient unchanged.
    final canvas = MediaQuery.sizeOf(context);
    return ExcludeSemantics(
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: canvas.width,
          maxWidth: canvas.width,
          minHeight: canvas.height,
          maxHeight: canvas.height,
          child: RepaintBoundary(
            child: ColoredBox(
              color: const Color(0xFF242A33),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Blur the small source before scaling it, keeping the
                  // apparent blur radius at 32 logical pixels on the canvas.
                  FittedBox(
                    fit: BoxFit.cover,
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(
                        sigmaX: 32 * 240 / canvas.longestSide,
                        sigmaY: 32 * 240 / canvas.longestSide,
                      ),
                      child: ProfileAvatar(
                        seed: data.avatarSeed,
                        url: data.avatarURL,
                        size: 240,
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF17202B).withValues(alpha: .48),
                          const Color(0xFF242A33).withValues(alpha: .86),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.store,
    this.identity,
    required this.onEdit,
    required this.onAvatar,
    required this.onMenu,
    required this.onDetails,
    this.pullProgress = 0,
    this.collapseProgress = 0,
    this.scrollOffset = 0,
    this.nameKey,
    this.surfaceKey,
    this.showName = true,
    this.transitionSnapshot = false,
    this.paintBackground = true,
  });
  final AppStore store;
  final ProfileIdentityData? identity;
  ProfileIdentityData get data =>
      identity ?? ProfileIdentityData.fromStore(store);
  final VoidCallback onEdit, onAvatar, onMenu, onDetails;
  final double pullProgress, collapseProgress, scrollOffset;
  final Key? nameKey, surfaceKey;
  final bool showName, transitionSnapshot, paintBackground;
  static const pullExtent = 40.0;

  static double toolbarHeight(BuildContext context) =>
      (MediaQuery.textScalerOf(context).scale(14) * 1.3)
          .clamp(44.0, double.infinity)
          .toDouble();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final t = collapseProgress;
      final inset = MediaQuery.paddingOf(context).top;
      final width = constraints.maxWidth;
      final toolbar = toolbarHeight(context);
      final color = Color.lerp(
        Colors.white,
        context.colors.ink,
        Curves.easeOutCubic.transform(t),
      )!;
      final sourceStyle = DefaultTextStyle.of(context).style.merge(
        TextStyle(
          fontSize: 20,
          height: 1.25,
          fontWeight: MediaQuery.boldTextOf(context)
              ? FontWeight.bold
              : FontWeight.w600,
          color: Colors.white,
        ),
      );
      // Reserve the expanded name's height while its one existing Text moves.
      // Its changing font/width must not change the Sliver's natural extent.
      final namePainter = TextPainter(
        text: TextSpan(text: userDisplayName(data.name), style: sourceStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: width - 32);
      final nameHeight = namePainter.height;
      final avatarTop = inset + toolbar + 24 + pullProgress * pullExtent;
      final nameTop = avatarTop + 106;
      final nameWidth = ui.lerpDouble(
        width - 32,
        (width - 204).clamp(0, width),
        t,
      )!;
      final nameLineHeight = MediaQuery.textScalerOf(context).scale(14) * 1.3;
      final visualAvatar = ui.lerpDouble(86, 26, t)!;
      final avatarCenterY = ui.lerpDouble(
        avatarTop + 43,
        inset + toolbar / 2,
        t,
      )!;
      final nameRise = Curves.easeInOutCubic.transform(
        ((t - .9) / .1).clamp(0, 1),
      );
      final nameY = ui.lerpDouble(
        avatarCenterY + visualAvatar / 2 + 20 * (1 - t),
        inset + (toolbar - nameLineHeight) / 2,
        nameRise,
      )!;
      final nameStyle = sourceStyle.copyWith(
        fontSize: ui.lerpDouble(20, 14, t),
        height: ui.lerpDouble(1.25, 1.3, t),
        color: color,
      );
      namePainter
        ..text = TextSpan(text: userDisplayName(data.name), style: nameStyle)
        ..maxLines = t == 1 ? 1 : 2
        ..layout(maxWidth: nameWidth);
      final surfaceHeight = (nameY + namePainter.height).clamp(
        inset + toolbar,
        double.infinity,
      );
      namePainter.dispose();
      final buttonStyle =
          (IconButtonTheme.of(context).style ?? const ButtonStyle()).copyWith(
            minimumSize: const WidgetStatePropertyAll(Size.square(44)),
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
      return ClipRect(
        key: const ValueKey('profile-header'),
        child: Stack(
          children: [
            if (paintBackground) ...[
              Positioned.fill(
                child: RepaintBoundary(
                  child: ProfileBackdrop(store: store, identity: identity),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: -1,
                height: 25,
                child: IgnorePointer(
                  child: ProfileSheetHandle(handleOpacity: 1 - t),
                ),
              ),
            ],
            Padding(
              padding: EdgeInsets.fromLTRB(16, inset, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: toolbar),
                  SizedBox(height: 24 + pullProgress * pullExtent),
                  const SizedBox(height: 86),
                  const SizedBox(height: 20),
                  SizedBox(key: nameKey, height: nameHeight),
                  ClipRect(
                    clipper: _ProfileBodyClipper(
                      surfaceHeight - (nameTop + nameHeight - scrollOffset),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (data.publicID.isNotEmpty ||
                            data.ipLocation.isNotEmpty)
                          Text(
                            [
                              if (data.publicID.isNotEmpty)
                                'ID：${data.publicID}',
                              if (data.ipLocation.isNotEmpty)
                                'IP：${data.ipLocation.replaceFirst(RegExp(r'省$'), '')}',
                            ].join(' / '),
                            key: const ValueKey('profile-account-summary'),
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFFCDD2D9),
                            ),
                          ),
                        const SizedBox(height: 10),
                        _ProfileAboutSummary(bio: data.bio, onTap: onDetails),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (paintBackground)
              Positioned(
                top: scrollOffset,
                left: 0,
                right: 0,
                height: surfaceHeight,
                child: KeyedSubtree(
                  key: surfaceKey,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: t,
                      child: ColoredBox(
                        key: t > 0
                            ? const ValueKey('profile-compact-header')
                            : null,
                        color: context.colors.surface,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left:
                  ui.lerpDouble(width / 2, 74, t)! -
                  ui.lerpDouble(86, 44, t)! / 2,
              top: scrollOffset + avatarCenterY - ui.lerpDouble(86, 44, t)! / 2,
              width: ui.lerpDouble(86, 44, t),
              height: ui.lerpDouble(86, 44, t),
              child: Semantics(
                label: identity == null ? '更改头像' : '查看个人详情',
                button: true,
                child: InkResponse(
                  key: const ValueKey('profile-identity-avatar'),
                  onTap: onAvatar,
                  child: Center(
                    child: Transform.scale(
                      scale: 1 + pullProgress * .08,
                      child: SizedBox.square(
                        dimension: ui.lerpDouble(86, 26, t)!,
                        child: Opacity(
                          opacity: transitionSnapshot ? 0 : 1,
                          child: _ProfileMorphHero(
                            store: store,
                            identity: identity,
                            avatar: true,
                            child: FittedBox(
                              child: identity == null
                                  ? _EditableAvatar(
                                      store: store,
                                      collapseProgress: t,
                                    )
                                  : _Avatar(
                                      store: store,
                                      identity: identity,
                                      size: 80,
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
            Positioned(
              left: ui.lerpDouble(16, 104, t),
              top: scrollOffset + nameY,
              width: nameWidth,
              child: Opacity(
                opacity: showName && !transitionSnapshot ? 1 : 0,
                child: _ProfileMorphHero(
                  store: store,
                  identity: identity,
                  child: Text(
                    userDisplayName(data.name),
                    key: const ValueKey('profile-identity-name'),
                    maxLines: t == 1 ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: nameStyle,
                  ),
                ),
              ),
            ),
            Positioned(
              top: scrollOffset + inset,
              left: 8,
              right: 8,
              height: toolbar,
              child: IconButtonTheme(
                data: IconButtonThemeData(style: buttonStyle),
                child: Row(
                  children: [
                    IconButton(
                      key: const ValueKey('profile-menu'),
                      tooltip: identity == null ? '展开菜单' : '返回',
                      onPressed: onMenu,
                      icon: AppIcon(
                        identity == null ? AppIcons.menu : AppIcons.back,
                        size: 20,
                        color: color,
                      ),
                    ),
                    const Spacer(),
                    if (identity == null &&
                        store.loading.contains('profile') &&
                        t < .5)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: color,
                            semanticsLabel: '正在刷新',
                          ),
                        ),
                      ),
                    if (identity == null)
                      IconButton(
                        key: const ValueKey('profile-edit'),
                        tooltip: '编辑个人资料',
                        onPressed: onEdit,
                        icon: AppIcon(
                          AppIcons.profileEdit,
                          size: 20,
                          color: color,
                        ),
                      ),
                    MessagesButton(
                      key: const ValueKey('profile-messages'),
                      store: store,
                      color: color,
                      iconSize: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _ProfileBodyClipper extends CustomClipper<Rect> {
  const _ProfileBodyClipper(this.top);
  final double top;
  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, top.clamp(0, size.height), size.width, size.height);
  @override
  bool shouldReclip(_ProfileBodyClipper oldClipper) => top != oldClipper.top;
}

class ProfileContentTabs extends StatelessWidget
    implements PreferredSizeWidget {
  const ProfileContentTabs({
    super.key,
    this.tabBarKey = const ValueKey('profile-tabs'),
    this.tabs = const [
      Tab(key: ValueKey('profile-tab-articles'), text: '动态', height: 36),
      Tab(key: ValueKey('profile-tab-saved'), text: '收藏', height: 36),
      Tab(key: ValueKey('profile-tab-resumes'), text: '简历', height: 36),
    ],
  });
  final List<Widget> tabs;
  final Key? tabBarKey;

  @override
  Size get preferredSize => const Size.fromHeight(38);

  @override
  Widget build(BuildContext context) => SizedBox(
    height: preferredSize.height,
    child: TabBar(
      key: tabBarKey,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      dividerColor: context.colors.border,
      indicatorColor: context.colors.ink,
      indicatorWeight: 2,
      indicatorSize: TabBarIndicatorSize.label,
      labelColor: context.colors.ink,
      unselectedLabelColor: context.colors.muted,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      unselectedLabelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      tabs: tabs,
    ),
  );
}

class ProfileSheetHandle extends StatelessWidget {
  const ProfileSheetHandle({super.key, this.handleOpacity = 1});
  final double handleOpacity;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const ValueKey('profile-curved-edge'),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
    ),
    child: Center(
      child: Opacity(
        opacity: handleOpacity,
        child: Container(
          key: const ValueKey('profile-drag-handle'),
          width: 44,
          height: 4,
          decoration: BoxDecoration(
            color: context.colors.muted.withValues(alpha: .4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    ),
  );
}

class _ProfileAboutSummary extends StatelessWidget {
  const _ProfileAboutSummary({required this.bio, required this.onTap});
  final String bio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontSize: 13,
      height: 1.5,
      color: Colors.white,
      fontWeight: MediaQuery.boldTextOf(context)
          ? FontWeight.bold
          : FontWeight.w400,
    );
    final text = bio.trim();
    final textScaler = MediaQuery.textScalerOf(context);
    TextSpan summary(String value, {bool clipped = false}) => TextSpan(
      style: style,
      children: [
        if (value.isNotEmpty) TextSpan(text: '$value${clipped ? '...' : ''}  '),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '关于我',
                style: style.copyWith(color: const Color(0xFFCDD2D9)),
                // WidgetSpan scales this entire row with the surrounding text.
                textScaler: TextScaler.noScaling,
              ),
              const SizedBox(width: 3),
              const AppIcon(
                AppIcons.expand,
                size: 14,
                color: Color(0xFFCDD2D9),
              ),
            ],
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      child: InkWell(
        key: const ValueKey('profile-about-summary'),
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final actionLabel = TextPainter(
              text: TextSpan(text: '关于我', style: style),
              textDirection: Directionality.of(context),
              textScaler: textScaler,
              locale: Localizations.maybeLocaleOf(context),
            )..layout();
            final inlineScale =
                textScaler.scale(style.fontSize!) / style.fontSize!;
            final iconHeight = 14 * inlineScale;
            final actionSize = Size(
              actionLabel.width + 17 * inlineScale,
              actionLabel.height < iconHeight ? iconHeight : actionLabel.height,
            );
            actionLabel.dispose();
            bool fits(TextSpan span, {bool reserveTrailingSpace = false}) {
              final painter =
                  TextPainter(
                    text: span,
                    textDirection: Directionality.of(context),
                    textScaler: textScaler,
                    locale: Localizations.maybeLocaleOf(context),
                    maxLines: 3,
                  )..setPlaceholderDimensions([
                    PlaceholderDimensions(
                      size: actionSize,
                      alignment: PlaceholderAlignment.middle,
                    ),
                  ]);
              try {
                painter.layout(maxWidth: constraints.maxWidth);
                if (painter.didExceedMaxLines) return false;
                if (!reserveTrailingSpace) return true;
                final lines = painter.computeLineMetrics();
                // Leave breathing room after the ellipsis and About me action.
                return lines.length < 3 ||
                    lines.last.width <= constraints.maxWidth * .8;
              } finally {
                painter.dispose();
              }
            }

            var span = summary(text);
            if (!fits(span)) {
              final characters = text.characters.toList();
              var low = 0, high = characters.length;
              while (low < high) {
                final middle = (low + high + 1) ~/ 2;
                if (fits(
                  summary(
                    characters.take(middle).join().trimRight(),
                    clipped: true,
                  ),
                  reserveTrailingSpace: true,
                )) {
                  low = middle;
                } else {
                  high = middle - 1;
                }
              }
              span = summary(
                characters.take(low).join().trimRight(),
                clipped: true,
              );
            }
            return Text.rich(
              span,
              key: const ValueKey('profile-about-text'),
              maxLines: 3,
              textScaler: textScaler,
              locale: Localizations.maybeLocaleOf(context),
              semanticsLabel: text.isEmpty ? '关于我' : '$text  关于我',
            );
          },
        ),
      ),
    );
  }
}

class ProfileHeaderSliver extends SliverPersistentHeaderDelegate {
  const ProfileHeaderSliver({
    required this.expandedHeight,
    required this.collapsedHeight,
    required this.headerBuilder,
    required this.collapseExtent,
  });

  final double expandedHeight, collapsedHeight;
  final Widget Function(double offset, double progress) headerBuilder;
  final double collapseExtent;

  @override
  double get minExtent => collapsedHeight;
  @override
  double get maxExtent =>
      expandedHeight.clamp(collapsedHeight, double.infinity).toDouble();

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ClipRect(
    child: Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: -shrinkOffset,
          left: 0,
          right: 0,
          child: headerBuilder(
            shrinkOffset,
            Curves.easeInOutCubic.transform(
              (shrinkOffset / collapseExtent.clamp(1, double.infinity)).clamp(
                0,
                1,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  @override
  bool shouldRebuild(ProfileHeaderSliver oldDelegate) =>
      expandedHeight != oldDelegate.expandedHeight ||
      collapsedHeight != oldDelegate.collapsedHeight ||
      headerBuilder != oldDelegate.headerBuilder ||
      collapseExtent != oldDelegate.collapseExtent;
}

class ProfileDetailsPage extends StatefulWidget {
  const ProfileDetailsPage({
    super.key,
    required this.store,
    this.identity,
    required this.onEdit,
    required this.onAvatar,
    this.origin,
    this.returnOrigin,
    this.initialPull = 0,
    this.initialCollapse = 0,
    this.initialScrollOffset = 0,
    this.initialSurfaceHeight = 0,
    this.expansion = const AlwaysStoppedAnimation(1),
  });
  final AppStore store;
  final ProfileIdentityData? identity;
  ProfileIdentityData get data =>
      identity ?? ProfileIdentityData.fromStore(store);
  final Future<void> Function(BuildContext) onEdit;
  final Future<void> Function(BuildContext) onAvatar;
  final Rect? origin, returnOrigin;
  final double initialPull,
      initialCollapse,
      initialScrollOffset,
      initialSurfaceHeight;
  final Animation<double> expansion;

  @override
  State<ProfileDetailsPage> createState() => _ProfileDetailsPageState();
}

class _ProfileDetailsPageState extends State<ProfileDetailsPage> {
  final scroll = ScrollController();
  bool expanded = false;
  AppStore get store => widget.store;
  ProfileIdentityData? get identity => widget.identity;
  Rect? get origin => widget.origin;
  double get initialPull => widget.initialPull;
  Animation<double> get expansion => widget.expansion;

  @override
  void initState() {
    super.initState();
    expanded = expansion.status == AnimationStatus.completed;
    expansion.addStatusListener(onStatus);
  }

  void onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) expanded = true;
    if (status == AnimationStatus.reverse && scroll.hasClients) {
      if (MediaQuery.disableAnimationsOf(context)) {
        scroll.jumpTo(0);
        return;
      }
      scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    expansion.removeStatusListener(onStatus);
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final target = Offset.zero & constraints.biggest;
        final openingOrigin = origin ?? target;
        // Keep the bitmap/filter and page layout at a fixed size. Only the clip
        // and opacity change during the transition, so their layers can be reused.
        final background = RepaintBoundary(
          child: SizedBox.fromSize(
            size: target.size,
            child: ProfileBackdrop(store: store, identity: identity),
          ),
        );
        Widget sourceSnapshot(double pullProgress) => IgnorePointer(
          child: ExcludeSemantics(
            child: HeroMode(
              enabled: false,
              child: RepaintBoundary(
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: 0,
                    maxHeight: double.infinity,
                    child: ProfileHeader(
                      store: store,
                      identity: identity,
                      transitionSnapshot: true,
                      paintBackground: false,
                      pullProgress: pullProgress,
                      collapseProgress: widget.initialCollapse,
                      scrollOffset: widget.initialScrollOffset,
                      onMenu: () {},
                      onEdit: () {},
                      onAvatar: () {},
                      onDetails: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final snapshot = sourceSnapshot(initialPull);
        final restingSnapshot = initialPull == 0 ? snapshot : sourceSnapshot(0);
        final details = RepaintBoundary(
          child: _ProfileDetailsLayout(
            store: store,
            identity: identity,
            scroll: scroll,
            onEdit: widget.onEdit,
            onAvatar: widget.onAvatar,
          ),
        );
        return AnimatedBuilder(
          animation: expansion,
          builder: (context, _) {
            final progress = Curves.easeInOutCubic.transform(expansion.value);
            final returning =
                expanded &&
                (expansion.status == AnimationStatus.reverse ||
                    expansion.status == AnimationStatus.dismissed);
            final start = returning
                ? widget.returnOrigin ?? openingOrigin
                : openingOrigin;
            final rect = Rect.lerp(start, target, progress)!;
            return Material(
              key: const ValueKey('profile-details-page'),
              type: MaterialType.transparency,
              child: Stack(
                children: [
                  Positioned.fromRect(
                    rect: rect,
                    child: ClipRect(
                      key: const ValueKey('profile-expansion-region'),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          OverflowBox(
                            alignment: Alignment.topLeft,
                            minWidth: target.width,
                            maxWidth: target.width,
                            minHeight: target.height,
                            maxHeight: target.height,
                            child: background,
                          ),

                          Positioned(
                            top: widget.initialScrollOffset,
                            left: 0,
                            right: 0,
                            height: widget.initialSurfaceHeight > 0
                                ? widget.initialSurfaceHeight
                                : MediaQuery.paddingOf(context).top +
                                      ProfileHeader.toolbarHeight(context),
                            child: Opacity(
                              opacity: widget.initialCollapse * (1 - progress),
                              child: ColoredBox(color: context.colors.surface),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (progress < 1 &&
                      (identity != null || store.isAuthenticated))
                    Positioned.fromRect(
                      rect: start,
                      child: Opacity(
                        opacity: (1 - progress * 2).clamp(0.0, 1.0),
                        child: returning ? restingSnapshot : snapshot,
                      ),
                    ),
                  Positioned.fill(
                    key: const ValueKey('profile-details-destination'),
                    child: Opacity(
                      opacity: ((progress - .35) / .65).clamp(0.0, 1.0),
                      child: details,
                    ),
                  ),
                  if (progress < 1)
                    Positioned(
                      left: rect.left,
                      width: rect.width,
                      top: rect.bottom - 24 + progress * 25,
                      height: 25,
                      child: const IgnorePointer(child: ProfileSheetHandle()),
                    ),
                ],
              ),
            );
          },
        );
      },
    ),
  );
}

class _ProfileMorphHero extends StatelessWidget {
  const _ProfileMorphHero({
    required this.store,
    this.identity,
    required this.child,
    this.avatar = false,
  });
  final AppStore store;
  final ProfileIdentityData? identity;
  ProfileIdentityData get data =>
      identity ?? ProfileIdentityData.fromStore(store);
  final Widget child;
  final bool avatar;

  @override
  Widget build(BuildContext context) => Hero(
    tag:
        '${avatar ? 'profile-avatar-morph' : 'profile-name-morph'}${identity == null ? '' : '-${data.userID}'}',
    curve: Curves.easeInOutCubic,
    createRectTween: (begin, end) => RectTween(begin: begin, end: end),
    flightShuttleBuilder: (context, animation, direction, from, to) =>
        AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final t = animation.value;
            return Material(
              type: MaterialType.transparency,
              child: SizedBox.expand(
                key: ValueKey(
                  avatar ? 'profile-avatar-flight' : 'profile-name-flight',
                ),
                child: avatar
                    ? FittedBox(
                        child: Stack(
                          children: [
                            _Avatar(store: store, identity: identity, size: 80),
                            if (identity == null)
                              Opacity(
                                opacity: 1 - t,
                                child: _EditableAvatar(store: store),
                              ),
                          ],
                        ),
                      )
                    : Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          userDisplayName(data.name),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20 + 2 * t,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
              ),
            );
          },
        ),
    child: child,
  );
}

class _ProfileDetailsLayout extends StatelessWidget {
  const _ProfileDetailsLayout({
    required this.store,
    this.identity,
    required this.onEdit,
    required this.onAvatar,
    required this.scroll,
  });
  final ScrollController scroll;
  final AppStore store;
  final ProfileIdentityData? identity;
  ProfileIdentityData get data =>
      identity ?? ProfileIdentityData.fromStore(store);
  final Future<void> Function(BuildContext) onEdit;
  final Future<void> Function(BuildContext) onAvatar;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: appSystemUiStyle(context).copyWith(
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: const Color(0xFF242A33),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => Stack(
          fit: StackFit.expand,
          children: [
            if (identity != null || store.isAuthenticated)
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                          child: IconButton(
                            key: const ValueKey('profile-details-close'),
                            tooltip: '关闭',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const AppIcon(
                              AppIcons.close,
                              size: 28,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            controller: scroll,
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (identity == null)
                                  TextButton.icon(
                                    key: const ValueKey('profile-details-edit'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      backgroundColor: const Color(0xFF181A1E),
                                      minimumSize: const Size(0, 32),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 6,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ).withoutHover(),
                                    onPressed: () => onEdit(context),
                                    icon: const AppIcon(
                                      AppIcons.edit,
                                      size: 18,
                                    ),
                                    label: const Text('编辑'),
                                  ),
                                const SizedBox(height: 14),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _ProfileMorphHero(
                                            store: store,
                                            identity: identity,
                                            child: Text(
                                              userDisplayName(data.name),
                                              key: const ValueKey(
                                                'profile-details-name',
                                              ),
                                              style: const TextStyle(
                                                fontSize: 22,
                                                height: 1.25,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          if (MediaQuery.textScalerOf(context)
                                                  .scale(12) <=
                                              20) ...[
                                            const SizedBox(height: 2),
                                            _ProfileAccountDetails(
                                              store: store,
                                              identity: identity,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Semantics(
                                      label: identity == null ? '更改头像' : '头像',
                                      button: identity == null,
                                      child: InkResponse(
                                        key: const ValueKey(
                                          'profile-details-avatar',
                                        ),
                                        onTap: identity == null
                                            ? () => onAvatar(context)
                                            : null,
                                        child: _ProfileMorphHero(
                                          store: store,
                                          identity: identity,
                                          avatar: true,
                                          child: _Avatar(
                                            store: store,
                                            identity: identity,
                                            size: 52,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (MediaQuery.textScalerOf(context).scale(12) >
                                    20) ...[
                                  const SizedBox(height: 2),
                                  _ProfileAccountDetails(
                                    store: store,
                                    identity: identity,
                                  ),
                                ],
                                if (data.bio.trim().isNotEmpty) ...[
                                  const SizedBox(height: 28),
                                  const Text(
                                    '关于我',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    data.bio,
                                    key: const ValueKey('profile-details-bio'),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.65,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ],
                            ),
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
    ),
  );
}

class _ProfileAccountDetails extends StatelessWidget {
  const _ProfileAccountDetails({required this.store, this.identity});
  final AppStore store;
  final ProfileIdentityData? identity;
  ProfileIdentityData get data =>
      identity ?? ProfileIdentityData.fromStore(store);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (data.publicID.isNotEmpty)
        UserIDLabel(
          value: data.publicID,
          fontSize: 12,
          color: Colors.white,
          compact: true,
        ),
      if (data.registeredAt case final date?)
        Text(
          '注册时间：${_registrationDate(date)}',
          key: const ValueKey('profile-registration-date'),
          style: const TextStyle(
            fontSize: 12,
            height: 1.6,
            color: Colors.white,
          ),
        ),
      if (data.ipLocation.isNotEmpty)
        Text(
          'IP属地：${data.ipLocation}',
          key: const ValueKey('profile-details-ip-location'),
          style: const TextStyle(
            fontSize: 12,
            height: 1.6,
            color: Colors.white,
          ),
        ),
    ],
  );
}

String _registrationDate(DateTime value) {
  final date = value.toLocal();
  return '${date.year}年${date.month}月${date.day}日';
}

class _EditableAvatar extends StatelessWidget {
  const _EditableAvatar({required this.store, this.collapseProgress = 0});
  final AppStore store;
  final double collapseProgress;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      ClipPath(
        clipper: _AvatarCameraNotch(collapseProgress),
        child: _Avatar(store: store, size: 80),
      ),
      Positioned(
        right: 0,
        bottom: 0,
        child: Opacity(
          opacity: 1 - collapseProgress,
          child: ExcludeSemantics(
            child: Container(
              key: const ValueKey('profile-avatar-camera'),
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: const Center(
                child: AppIcon(
                  AppIcons.camera,
                  size: 16,
                  color: Color(0xFF252A34),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _AvatarCameraNotch extends CustomClipper<Path> {
  const _AvatarCameraNotch(this.progress);
  final double progress;

  @override
  Path getClip(Size size) => Path.combine(
    PathOperation.difference,
    Path()..addOval(Offset.zero & size),
    Path()..addOval(
      Rect.fromCircle(
        center: Offset(size.width - 14, size.height - 14),
        radius: 16 * (1 - progress),
      ),
    ),
  );

  @override
  bool shouldReclip(_AvatarCameraNotch oldClipper) =>
      oldClipper.progress != progress;
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.store, required this.size, this.identity});
  final AppStore store;
  final ProfileIdentityData? identity;
  ProfileIdentityData get data =>
      identity ?? ProfileIdentityData.fromStore(store);
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white,
    ),
    child: ClipOval(
      child: ProfileAvatar(
        seed: data.avatarSeed,
        url: data.avatarURL,
        size: size,
      ),
    ),
  );
}
