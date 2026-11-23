import 'article_owner_actions.dart';
import 'app_page_bar.dart';
import 'api/bojian_api.dart';
import 'content_report.dart';
import 'playful_refresh.dart';

import 'dart:async';

import 'article_rich_content.dart';
import 'article_declaration.dart';
import 'article_reaction_button.dart';
import 'resume_guidance_view.dart';
import 'guidance_feed_card.dart';
import 'resume_updated_label.dart';
export 'story_composer.dart';
import 'profile_avatar.dart';
import 'profile_identity.dart';
import 'article_comment_tile.dart';
import 'withdraw_comment_button.dart';
import 'app_icons.dart';

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import 'app_store.dart';
import 'discovery_banner.dart';
import 'invite_floating_badge.dart';
import 'invitation_dialog.dart';
import 'app_search_field.dart';
import 'comment_composer.dart';
import 'design.dart';
import 'messages_button.dart';
import 'my_articles_page.dart';
import 'saved_articles_page.dart';
import 'story_author_identity.dart';
import 'user_profile_page.dart';

Color _discoveryGapColor(BuildContext context) =>
    context.isDark ? context.colors.canvas : context.colors.inset;

class DiscoveryPage extends StatefulWidget {
  const DiscoveryPage({super.key, required this.store});
  final AppStore store;
  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<DiscoveryPage> {
  static const categories = ['推荐', '简历分享', '动态'];
  static const headerActionsWidth = 88.0;
  bool scanning = false;

  Future<void> scan() async {
    if (scanning || ModalRoute.of(context)?.isCurrent != true) return;
    setState(() => scanning = true);
    try {
      await scanAndBindInvitation(context, widget.store);
    } finally {
      if (mounted) setState(() => scanning = false);
    }
  }

  final search = TextEditingController();
  final searchFocus = FocusNode();
  String query = '';
  final _seenArticles = <String, Set<int>>{};
  @override
  void dispose() {
    search.dispose();
    searchFocus.dispose();
    super.dispose();
  }

  Widget feed(String category) {
    final stories = widget.store.stories
        .where(
          (s) =>
              (category == '推荐' || s.category == category) &&
              (query.isEmpty ||
                  '${s.title} ${s.excerpt} ${s.author}'.toLowerCase().contains(
                    query.toLowerCase(),
                  )),
        )
        .toList();
    // Only refreshes animate newcomers in; the first batch a list shows (for
    // example right after sign-in, when the feed was still empty) appears as is.
    final known = _seenArticles.putIfAbsent(category, () => <int>{});
    final added = known.isEmpty
        ? const <int>{}
        : stories
              .where((story) => !known.contains(story.id))
              .map((story) => story.id)
              .toSet();
    known.addAll(stories.map((story) => story.id));
    return LayoutBuilder(
      builder: (context, constraints) => AutoPaginate.section(
        store: widget.store,
        section: 'feed',
        child: PlayfulRefresh(
          hasError: () => widget.store.errors['feed'] != null,
          onRefresh: () => widget.store.load('feed'),
          child: ListView(
            key: PageStorageKey('discovery-feed-$category'),
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (stories.isEmpty && widget.store.loading.contains('feed'))
                const _FeedSkeleton()
              else if (stories.isEmpty)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 24).clamp(
                      0.0,
                      double.infinity,
                    ),
                  ),
                  child: Center(
                    child: DataStatus(
                      store: widget.store,
                      section: 'feed',
                      empty: stories.isEmpty,
                      title: query.isEmpty ? '还没有发布的内容' : '没有找到相关内容',
                      subtitle: query.isEmpty ? '' : '试试其他关键词。',
                    ),
                  ),
                ),
              for (final story in stories)
                _FeedArticleEntrance(
                  key: ValueKey('discovery-story-${story.id}'),
                  animate: added.contains(story.id),
                  child: FeedRow(
                    gapColor: _discoveryGapColor(context),
                    child: StoryCard(
                      story: story,
                      store: widget.store,
                      flat: true,
                    ),
                  ),
                ),
              if (stories.isNotEmpty && widget.store.errors['feed'] != null)
                DataStatus(store: widget.store, section: 'feed', empty: false),
              PageLoadingFooter(
                visible: widget.store.loadingMore.contains('feed'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget searchBar(BuildContext context, {double collapse = 0}) {
    final height = (MediaQuery.textScalerOf(context).scale(13) * 1.2 + 8)
        .clamp(32.0, double.infinity)
        .toDouble();
    final rowHeight = (height + 8).clamp(44.0, double.infinity).toDouble();
    final buttonStyle =
        (IconButtonTheme.of(context).style ?? const ButtonStyle()).copyWith(
          minimumSize: const WidgetStatePropertyAll(Size.square(44)),
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
    return Padding(
      // Align the search field to the page gutter while preserving the
      // scan icon's artwork alignment at the opposite edge.
      padding: const EdgeInsets.fromLTRB(
        appPageHorizontalPadding,
        0,
        appPageHorizontalPadding - 13,
        0,
      ),
      child: SizedBox(
        key: const ValueKey('discovery-search-row'),
        height: rowHeight,
        child: Row(
          children: [
            Expanded(
              child: IgnorePointer(
                ignoring: collapse > 0,
                child: Opacity(
                  opacity: (1 - collapse * 2).clamp(0.0, 1.0),
                  child: SizedBox(
                    height: height,
                    child: TextField(
                      key: const ValueKey('discovery-search'),
                      controller: search,
                      focusNode: searchFocus,
                      textInputAction: TextInputAction.search,
                      textAlignVertical: TextAlignVertical.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.2,
                        color: context.colors.ink,
                      ),
                      onChanged: (value) =>
                          setState(() => query = value.trim()),
                      onSubmitted: (_) => searchFocus.unfocus(),
                      decoration: InputDecoration(
                        hintText: '搜索',
                        hintStyle: TextStyle(
                          color: context.colors.muted,
                          fontSize: 13,
                          height: 1.2,
                        ),
                        filled: true,
                        fillColor: context.colors.inset,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        prefixIconConstraints: BoxConstraints.tightFor(
                          width: 36,
                          height: height,
                        ),
                        prefixIcon: Center(
                          child: AppIcon(
                            AppIcons.search,
                            size: 16,
                            color: context.colors.muted,
                          ),
                        ),
                        suffixIconConstraints: BoxConstraints.tightFor(
                          width: 32,
                          height: height,
                        ),
                        suffixIcon: search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: '清空搜索',
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  search.clear();
                                  setState(() => query = '');
                                  searchFocus.requestFocus();
                                },
                                icon: AppIcon(
                                  AppIcons.clear,
                                  size: 16,
                                  color: context.colors.muted,
                                ),
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: headerActionsWidth,
              height: 44,
              child: ColoredBox(
                color: context.colors.surface,
                child: IconButtonTheme(
                  data: IconButtonThemeData(style: buttonStyle),
                  child: Row(
                    children: [
                      SizedBox.square(
                        dimension: 44,
                        child: MessagesButton(
                          key: const ValueKey('discovery-messages'),
                          store: widget.store,
                          iconSize: 20,
                        ),
                      ),
                      SizedBox.square(
                        dimension: 44,
                        child: IconButton(
                          key: const ValueKey('discovery-scan'),
                          tooltip: '扫一扫',
                          onPressed: scanning ? null : scan,
                          icon: const AppIcon(AppIcons.scan, size: 20),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colors.surface,
      child: DefaultTabController(
        length: categories.length,
        child: Stack(
          children: [
            NestedScrollView(
              headerSliverBuilder: (context, innerScrolled) => [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _DiscoveryHeaderDelegate(
                    rowHeight:
                        (MediaQuery.textScalerOf(context).scale(13) * 1.2 + 16)
                            .clamp(44.0, double.infinity),
                    builder: (context, collapse) => ColoredBox(
                      color: context.colors.surface,
                      child: Padding(
                        padding: EdgeInsets.zero,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: Stack(
                              children: [
                                Positioned(
                                  // Collapsed tabs keep their page gutter and
                                  // leave room for the two actions on the right.
                                  left: 0,
                                  right:
                                      (appPageHorizontalPadding -
                                          13 +
                                          headerActionsWidth) *
                                      collapse,
                                  bottom:
                                      (((MediaQuery.textScalerOf(context)
                                                              .scale(13) *
                                                          1.2 +
                                                      16)
                                                  .clamp(
                                                    44.0,
                                                    double.infinity,
                                                  ) -
                                              38) /
                                          2) *
                                      collapse,
                                  child: ProfileContentTabs(
                                    tabBarKey: const ValueKey('discovery-tabs'),
                                    horizontalPadding:
                                        appPageHorizontalPadding - 8,
                                    showDivider: false,
                                    tabs: [
                                      for (final category in categories)
                                        Tab(text: category, height: 36),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: searchBar(context, collapse: collapse),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: DiscoveryBanner(store: widget.store)),
                SliverToBoxAdapter(
                  child: ColoredBox(
                    color: _discoveryGapColor(context),
                    child: const SizedBox(height: 8),
                  ),
                ),
              ],
              body: TabBarView(
                children: [for (final category in categories) feed(category)],
              ),
            ),
            Positioned(
              right: 10,
              bottom: 18,
              child: InviteFloatingBadge(store: widget.store),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _DiscoveryHeaderDelegate({
    required this.rowHeight,
    required this.builder,
  });
  final double rowHeight;
  final Widget Function(BuildContext context, double collapse) builder;

  @override
  double get minExtent => rowHeight;
  @override
  double get maxExtent => rowHeight + 38;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => builder(
    context,
    (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0),
  );

  @override
  bool shouldRebuild(_DiscoveryHeaderDelegate oldDelegate) =>
      rowHeight != oldDelegate.rowHeight || builder != oldDelegate.builder;
}

/// Only newly arriving records expand into the list. Existing keyed cards
/// retain their state and never replay an entrance on an ordinary refresh.
class _FeedArticleEntrance extends StatefulWidget {
  const _FeedArticleEntrance({
    super.key,
    required this.animate,
    required this.child,
  });
  final bool animate;
  final Widget child;
  @override
  State<_FeedArticleEntrance> createState() => _FeedArticleEntranceState();
}

class _FeedArticleEntranceState extends State<_FeedArticleEntrance>
    with SingleTickerProviderStateMixin {
  late final _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: widget.animate ? 0 : 1,
  );
  late final _curve = CurvedAnimation(
    parent: _entrance,
    curve: Curves.easeOutCubic,
  );
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else if (widget.animate) {
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizeTransition(
    sizeFactor: _curve,
    alignment: Alignment.topLeft,
    child: FadeTransition(opacity: _curve, child: widget.child),
  );
}

/// Full-bleed white feed row with a 6pt canvas gap, centring its card.
class FeedRow extends StatelessWidget {
  const FeedRow({super.key, required this.child, this.gapColor});

  final Widget child;
  final Color? gapColor;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: gapColor ?? context.colors.canvas,
    child: Container(
      color: context.colors.surface,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: feedOuterPadding),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: child,
        ),
      ),
    ),
  );
}

class StoryCard extends StatelessWidget {
  const StoryCard({
    super.key,
    required this.story,
    required this.store,
    this.flat = false,
    this.compactTypography = false,
    this.authorName,
    this.authorAvatarURL,
    this.authorNavigationEnabled = true,
    this.onBookmark,
    this.onDetailClosed,
  });
  final Story story;
  final AppStore store;
  final bool flat;
  final bool compactTypography;
  final String? authorName, authorAvatarURL;
  final bool authorNavigationEnabled;
  final VoidCallback? onBookmark, onDetailClosed;
  Future<void> _openDetail(BuildContext context) async {
    dismissKeyboard();
    await Navigator.of(context).push(
      _StoryDetailRoute(
        builder: (_) => StoryDetail(story: story, store: store),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : Theme.of(context).platform == TargetPlatform.android
            ? const Duration(milliseconds: 260)
            : null,
      ),
    );
    onDetailClosed?.call();
  }

  @override
  Widget build(BuildContext context) => story.hasGuidance
      ? GuidanceFeedCard(
          story: story,
          store: store,
          flat: flat,
          compactTypography: compactTypography,
          authorName: authorName,
          authorAvatarURL: authorAvatarURL,
          authorNavigationEnabled: authorNavigationEnabled,
        )
      : _StorySurface(
          flat: flat,
          onTap: () => _openDetail(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StoryAuthorAvatar(
                    story: story,
                    store: store,
                    size: 30,
                    flat: flat,
                    name: authorName,
                    avatarURL: authorAvatarURL,
                    navigationEnabled: authorNavigationEnabled,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StoryAuthorIdentity(
                      story: story,
                      store: store,
                      name: authorName,
                      flat: flat,
                    ),
                  ),
                ],
              ),
              SizedBox(height: flat ? 5 : 12),
              if (story.title.trim().isNotEmpty)
                Text(
                  story.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compactTypography ? 14 : (flat ? 18 : 16),
                    fontWeight: feedTitleWeight,
                    color: context.colors.ink,
                    height: 1.4,
                  ),
                ),
              ArticleDeclarationLabel(story.content),
              if (story.excerpt.trim().isNotEmpty) ...[
                if (story.title.trim().isNotEmpty)
                  SizedBox(height: flat ? 2 : 6),
                Text(
                  story.excerpt,
                  maxLines: flat ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compactTypography ? 13 : (flat ? 14 : 11.5),
                    fontWeight: FontWeight.normal,
                    color: flat ? context.colors.ink : context.colors.muted,
                    height: 1.5,
                  ),
                ),
              ],
              if (story.cover == 1) ...[
                const SizedBox(height: 15),
                _StoryCover(),
              ],
              if (story.cover == 2) ...[
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: (context.isDark
                        ? context.colors.successSoft
                        : const Color(0xFFF5F8F7)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      AppIcon(
                        AppIcons.resume,
                        color: Color(0xFF509B87),
                        size: 23,
                      ),
                      SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '产品经理 · 转行简历',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '希望得到具体的修改建议',
                              style: TextStyle(
                                fontSize: 10,
                                color: context.colors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppIcon(
                        AppIcons.external,
                        size: 14,
                        color: context.colors.muted,
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: flat ? 2 : 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      switch (DateTime.tryParse(story.publishedAt)) {
                        final date? => resumeUpdatedLabel(date),
                        null => '',
                      },
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: context.colors.muted,
                      ),
                    ),
                  ),
                  ArticleReactionButton(
                    key: ValueKey('story-like-${story.id}'),
                    reaction: ArticleReaction.like,
                    count: story.likes,
                    compact: true,
                    active: story.liked,
                    onTap: () => runRequest(context, () => store.like(story)),
                  ),
                  SizedBox(width: flat ? 12 : 16),
                  _Reaction(
                    icon: AppIcons.comment,
                    label: '${story.commentCount}',
                    onTap: () => _openDetail(context),
                  ),
                  SizedBox(width: flat ? 12 : 16),
                  ArticleReactionButton(
                    key: ValueKey('story-bookmark-${story.id}'),
                    reaction: ArticleReaction.bookmark,
                    compact: true,
                    count: story.favorites,
                    active: story.saved,
                    onTap:
                        onBookmark ??
                        () => runRequest(context, () => store.bookmark(story)),
                  ),
                ],
              ),
            ],
          ),
        );
}

/// Stand-in feed cards shown, in the real cards' place, until the first page of
/// articles arrives.
class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonPulse(
    child: Column(
      key: const ValueKey('discovery-feed-skeleton'),
      children: [
        for (var i = 0; i < 4; i++)
          FeedRow(
            gapColor: _discoveryGapColor(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: feedContentPadding,
                vertical: 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        SkeletonBox(width: 30, height: 30, radius: 15),
                        SizedBox(width: 15),
                        SkeletonBox(width: 88, height: 12),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  FractionallySizedBox(
                    widthFactor: i.isEven ? 0.72 : 0.56,
                    child: const SkeletonBox(height: 18),
                  ),
                  const SizedBox(height: 10),
                  const SkeletonBox(height: 12),
                  const SizedBox(height: 8),
                  const FractionallySizedBox(
                    widthFactor: 0.82,
                    child: SkeletonBox(height: 12),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class _StorySurface extends StatelessWidget {
  const _StorySurface({
    required this.flat,
    required this.onTap,
    required this.child,
  });
  final bool flat;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(flat ? 0 : 20);
    return Material(
      color: context.colors.surface,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: flat
              ? const EdgeInsets.fromLTRB(
                  feedContentPadding,
                  8,
                  feedContentPadding,
                  2,
                )
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: child,
        ),
      ),
    );
  }
}

class _Reaction extends StatelessWidget {
  const _Reaction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final AppIconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: 17, color: context.colors.muted),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: context.colors.muted),
            ),
          ],
        ],
      ),
    ),
  );
}

class _StoryCover extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    height: 122,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: (context.isDark
          ? context.colors.accentSoft
          : const Color(0xFFEDF2FA)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Stack(
      children: [
        const Positioned(
          right: 14,
          top: 10,
          child: RotationTransition(
            turns: AlwaysStoppedAnimation(.025),
            child: DocumentArt(width: 82, height: 112),
          ),
        ),
        const Positioned(
          right: 51,
          top: 17,
          child: RotationTransition(
            turns: AlwaysStoppedAnimation(-.055),
            child: DocumentArt(width: 82, height: 112, variant: 1),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'LESS, BUT BETTER.',
                style: TextStyle(
                  fontSize: 8,
                  color: Color(0xFF7187AA),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '少一点堆砌\n多一点重点',
                style: TextStyle(
                  fontSize: 18,
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                  color: (context.isDark
                      ? context.colors.ink
                      : Color(0xFF35547F)),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _StoryDetailRoute extends CupertinoPageRoute<void> {
  _StoryDetailRoute({required super.builder, required this.duration});

  final Duration? duration;

  @override
  Duration get transitionDuration => duration ?? super.transitionDuration;
}

class StoryDetail extends StatefulWidget {
  const StoryDetail({super.key, required this.story, required this.store});
  final Story story;
  final AppStore store;
  @override
  State<StoryDetail> createState() => _StoryDetailState();
}

class _StoryDetailState extends State<StoryDetail> {
  late ArticleRichBody body = _buildBody(widget.story.content);

  ArticleRichBody _buildBody(Map<String, dynamic> content) => ArticleRichBody(
    content: content.isEmpty
        ? richContent(widget.story.paragraphs.join('\n'))
        : content,
  );
  String? bodyError;
  Future<void> loadBody() async {
    try {
      final result = await widget.store.request(
        'GetArticlesId',
        path: {'id': '${widget.story.id}'},
      );
      if (!mounted) return;
      setState(() {
        if (result.data['status'] != null &&
            result.data['status'] != 'PUBLISHED') {
          articleRemoved = true;
        }
        if (result.data['content'] != null) {
          final content = result.data['content'];
          body = _buildBody(
            content is Map
                ? Map<String, dynamic>.from(content)
                : richContent(plainContent(content)),
          );
        }
        if (!widget.store.pending.contains('bookmark-${widget.story.id}')) {
          widget.story.readBookmarkMetrics(result.data);
        }
        if (!widget.store.pending.contains('like-${widget.story.id}') &&
            result.data.containsKey('like_count')) {
          widget.story.likes = integer(result.data['like_count']);
          if (result.data.containsKey('is_liked')) {
            widget.story.liked = result.data['is_liked'] == true;
          }
        }
        bodyError = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          bodyError = '文章暂时无法加载';
          if (e is ApiFailure && e.code == 'ARTICLE_NOT_FOUND') {
            articleRemoved = true;
          }
        });
      }
    }
  }

  bool articleRemoved = false;
  final comment = TextEditingController();
  final commentFocus = FocusNode();
  ArticleComment? replyTarget;
  final threads = <int, List<ArticleComment>>{};
  final cursors = <int, String>{};
  final loadingThreads = <int>{};
  final threadErrors = <int, String>{};
  final expandedThreads = <int>{};
  void reply(ArticleComment target) {
    if (widget.store.pending.contains('comment-${widget.story.id}')) return;
    setState(() {
      replyTarget = target;
      commentSendError = null;
    });
    commentFocus.requestFocus();
  }

  Future<void> loadThread(int root, {bool more = false}) async {
    if (loadingThreads.contains(root)) return;
    setState(() {
      loadingThreads.add(root);
      expandedThreads.add(root);
      threadErrors.remove(root);
    });
    try {
      final result = await widget.store.request(
        'GetArticlesIdCommentsCommentIDReplies',
        path: {'id': '${widget.story.id}', 'commentID': '$root'},
        query: {
          'limit': '20',
          if (more && cursors[root]?.isNotEmpty == true)
            'cursor': cursors[root]!,
        },
      );
      if (!mounted) return;
      setState(() {
        threads[root] = [
          if (more) ...?threads[root],
          ...widget.store
              .mergeContent(
                'PostArticlesIdComments',
                widget.story.id,
                items(result.data),
              )
              .where((r) => integer(r['parent_id']) == root)
              .map(ArticleComment.fromJson),
        ];
        cursors[root] = result.nextCursor;
      });
    } catch (e) {
      if (mounted) setState(() => threadErrors[root] = '$e');
    } finally {
      if (mounted) setState(() => loadingThreads.remove(root));
    }
  }

  Future<void> react(ArticleComment target, bool dislike) async {
    await runRequest(context, () async {
      final updated = await widget.store.reactToComment(
        widget.story,
        target,
        dislike: dislike,
      );
      if (!mounted || updated == null) return;
      setState(() {
        for (final root in threads.keys.toList()) {
          threads[root] = threads[root]!
              .map((c) => c.id == updated.id ? updated : c)
              .toList();
        }
      });
    });
  }

  List<ArticleComment> get displayedComments {
    final local = widget.store
        .localContent('PostArticlesIdComments', widget.story.id)
        .where((r) => r['parent_id'] == null)
        .map(ArticleComment.fromJson)
        .toList();
    return [
      ...local.reversed,
      ...widget.story.comments.where((c) => !local.any((v) => v.id == c.id)),
    ];
  }

  List<ArticleComment> threadComments(int root) {
    final local = widget.store
        .localContent('PostArticlesIdComments', widget.story.id)
        .where((r) => integer(r['parent_id']) == root)
        .map(ArticleComment.fromJson)
        .toList();
    return [
      ...local.reversed,
      ...(threads[root] ?? []).where((c) => !local.any((v) => v.id == c.id)),
    ];
  }

  Widget commentTile(
    ArticleComment c, {
    bool nested = false,
  }) => ArticleCommentTile(
    comment: c,
    articleAuthorID: widget.story.authorID,
    currentUserID: widget.store.userID,
    nested: nested,
    withdrawButton: c.id > 0 && !c.deleted && c.authorID == widget.store.userID
        ? WithdrawCommentButton(
            store: widget.store,
            method: 'DeleteArticlesIdCommentsCommentID',
            submissionMethod: 'PostArticlesIdComments',
            commentID: c.id,
            path: {'id': '${widget.story.id}', 'commentID': '${c.id}'},
            onWithdrawn: () async {
              if (!mounted) return;
              setState(() {
                if (replyTarget?.id == c.id) replyTarget = null;
                if (nested)
                  threads[c.parentID]?.removeWhere((item) => item.id == c.id);
              });
              await loadComments(silent: true);
              if (mounted && nested && c.parentID != null)
                await loadThread(c.parentID!);
            },
          )
        : null,
    onAuthorTap: () =>
        openUserProfile(context, store: widget.store, userID: c.authorID),
    onReply: c.visible ? () => reply(c) : null,
    onReport: () => reportContent(
      context,
      store: widget.store,
      subjectType: 'COMMENT',
      subjectID: c.id,
    ),
    onRetry: c.local == null ? null : () => widget.store.sendContent(c.local!),
    onEdit: () => setState(() {
      comment.text = c.content;
      replyTarget = c.replyToID == null
          ? null
          : ArticleComment(
              id: c.replyToID!,
              authorID: 0,
              author: c.replyToName,
              content: '',
              parentID: c.parentID,
            );
      commentFocus.requestFocus();
    }),
    onLike: () => react(c, false),
    onDislike: () => react(c, true),
    pending: widget.store.pending.contains(
      'comment-reaction-${widget.story.id}-${c.id}',
    ),
  );
  Widget thread(ArticleComment root) {
    final expanded = expandedThreads.contains(root.id);
    return Padding(
      padding: const EdgeInsets.only(left: 42),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (expanded) ...[
            for (final c in threadComments(root.id))
              commentTile(c, nested: true),
            if (loadingThreads.contains(root.id))
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            if (threadErrors.containsKey(root.id))
              TextButton(
                onPressed: () => loadThread(root.id),
                child: const Text('回复加载失败，点击重试'),
              ),
            if (!loadingThreads.contains(root.id) &&
                cursors[root.id]?.isNotEmpty == true)
              TextButton(
                onPressed: () => loadThread(root.id, more: true),
                child: const Text('查看更多回复'),
              ),
          ],
          if (root.replyCount > 0 ||
              threadComments(root.id).isNotEmpty ||
              expanded)
            ReplyThreadToggle(
              key: ValueKey('article-thread-toggle-${root.id}'),
              expanded: expanded,
              replyCount: root.replyCount,
              onPressed: () {
                if (expanded) {
                  setState(() => expandedThreads.remove(root.id));
                } else if (threads.containsKey(root.id) &&
                    !threadErrors.containsKey(root.id)) {
                  setState(() => expandedThreads.add(root.id));
                } else {
                  loadThread(root.id);
                }
              },
            ),
        ],
      ),
    );
  }

  String? commentError, commentSendError;
  bool commentsLoading = true;
  StreamSubscription<Map<String, dynamic>>? realtime;
  Timer? refreshTimer;
  Timer? moderationTimer;
  bool refreshingComments = false, refreshCommentsPending = false;
  Animation<double>? opening;

  void _onOpeningStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    opening?.removeStatusListener(_onOpeningStatus);
    opening = null;
    // The feed already supplies the first screen. Refresh comments after the
    // slide so the store does not rebuild both pages in the middle of it.
    if (!articleRemoved) unawaited(loadComments(silent: true));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        loadBody();
        opening = ModalRoute.of(context)?.animation;
        if (opening == null || opening!.isCompleted) {
          _onOpeningStatus(AnimationStatus.completed);
        } else {
          opening!.addStatusListener(_onOpeningStatus);
        }
      }
    });
    moderationTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted ||
          !widget.store.foreground ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      if (displayedComments.any(
            (c) => const {'SENDING', 'QUEUED', 'PENDING'}.contains(c.status),
          ) ||
          threads.values
              .expand((v) => v)
              .any(
                (c) =>
                    const {'SENDING', 'QUEUED', 'PENDING'}.contains(c.status),
              ) ||
          widget.store
              .localContent('PostArticlesIdComments', widget.story.id)
              .any((r) => r['moderation_status'] != 'FAILED')) {
        loadComments(silent: true);
        for (final root in expandedThreads.toList()) {
          loadThread(root);
        }
      }
    });
    realtime = widget.store.realtimeEvents.listen((event) {
      final data = event['data'] is Map ? event['data'] as Map : const {};
      if (event['type'] == 'content.removed' &&
          integer(data['article_id']) == widget.story.id &&
          {'ARTICLE', 'POST'}.contains(data['subject_type'])) {
        setState(() => articleRemoved = true);
        return;
      }
      if (event['type'] != 'connection.ready' &&
          (!{
                'content.removed',
                'article.comment',
                'article.reaction',
                'article.updated',
              }.contains(event['type']) ||
              integer(data['article_id']) != widget.story.id)) {
        return;
      }
      refreshTimer?.cancel();
      refreshTimer = Timer(const Duration(milliseconds: 200), () {
        if (mounted) {
          loadBody();
          if (opening == null) loadComments(silent: true);
          for (final root in expandedThreads.toList()) {
            loadThread(root);
          }
        }
      });
    });
  }

  bool loadingMoreComments = false;

  Future<void> loadMoreComments() async {
    setState(() => loadingMoreComments = true);
    try {
      await widget.store.article(widget.story, more: true);
      if (mounted) setState(() => commentError = null);
    } catch (e) {
      if (mounted) setState(() => commentError = '$e');
    } finally {
      if (mounted) setState(() => loadingMoreComments = false);
    }
  }

  Future<void> loadComments({bool silent = false}) async {
    if (refreshingComments) {
      refreshCommentsPending = true;
      return;
    }
    refreshingComments = true;
    if (!silent) setState(() => commentsLoading = true);
    try {
      await widget.store.article(widget.story);
      if (mounted) setState(() => commentError = null);
    } catch (e) {
      if (mounted) setState(() => commentError = '$e');
    } finally {
      refreshingComments = false;
      if (mounted) {
        setState(() => commentsLoading = false);
        if (refreshCommentsPending) {
          refreshCommentsPending = false;
          unawaited(loadComments(silent: true));
        }
      }
    }
  }

  @override
  void dispose() {
    opening?.removeStatusListener(_onOpeningStatus);
    refreshTimer?.cancel();
    moderationTimer?.cancel();
    unawaited(realtime?.cancel());
    commentFocus.dispose();
    comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) => _buildPage(context),
  );

  Widget _buildPage(BuildContext context) {
    final comments = displayedComments;
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppPageBar(
        actions: [
          if (!articleRemoved && widget.story.authorID == widget.store.userID)
            ArticleOwnerActions(
              store: widget.store,
              articleID: widget.story.id,
            ),
          if (!articleRemoved && widget.story.authorID != widget.store.userID)
            ReportArticleButton(
              store: widget.store,
              articleID: widget.story.id,
            ),
          const DismissKeyboardButton(),
        ],
      ),
      body: articleRemoved
          ? const Center(child: Text('该文章已撤回，暂时无法查看'))
          : AutoPaginate(
              canLoad:
                  widget.story.commentsCursor.isNotEmpty &&
                  !commentsLoading &&
                  !loadingMoreComments &&
                  commentError == null,
              onLoadMore: loadMoreComments,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  appPageHorizontalPadding,
                  12,
                  appPageHorizontalPadding,
                  24,
                ),
                children: [
                  Text(
                    widget.story.title,
                    style: const TextStyle(
                      fontSize: 26,
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  ArticleDeclarationLabel(body.content),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      ProfileAvatar(
                        seed: widget.story.authorID > 0
                            ? '${widget.story.authorID}'
                            : widget.story.author,
                        url: widget.story.authorAvatarURL,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.story.author,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              widget.story.role,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.colors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.story.publishedAt.split('T').first,
                        style: TextStyle(
                          color: context.colors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  if (widget.story.cover == 1) ...[
                    _StoryCover(),
                    const SizedBox(height: 24),
                  ],
                  if (widget.story.hasGuidance)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: OutlinedButton(
                        onPressed: () => openPage(
                          context,
                          ResumeGuidanceView(
                            store: widget.store,
                            id: widget.story.id,
                          ),
                        ),
                        child: const Text('查看简历'),
                      ),
                    ),
                  body,
                  if (bodyError != null)
                    TextButton(
                      onPressed: loadBody,
                      child: Text('$bodyError，点击重试'),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      key: const ValueKey('article-end-actions'),
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ArticleReactionButton(
                          key: const ValueKey('detail-like'),
                          count: widget.story.likes,
                          reaction: ArticleReaction.like,
                          active: widget.story.liked,
                          onTap:
                              widget.store.pending.contains(
                                'like-${widget.story.id}',
                              )
                              ? null
                              : () => runRequest(
                                  context,
                                  () => widget.store.like(widget.story),
                                ),
                        ),
                        const SizedBox(width: 8),
                        ArticleReactionButton(
                          key: const ValueKey('detail-bookmark'),
                          reaction: ArticleReaction.bookmark,
                          count: widget.story.favorites,
                          active: widget.story.saved,
                          onTap:
                              widget.store.pending.contains(
                                'bookmark-${widget.story.id}',
                              )
                              ? null
                              : () => runRequest(
                                  context,
                                  () => widget.store.bookmark(widget.story),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 18),
                  Text(
                    '评论（${widget.story.commentCount}）',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (commentError != null) ...[
                    Text(
                      commentError!,
                      style: TextStyle(
                        color: context.colors.muted,
                        fontSize: 12,
                      ),
                    ),
                    TextButton(
                      onPressed: loadComments,
                      child: const Text('重新加载评论'),
                    ),
                  ],
                  if (commentsLoading)
                    const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  if (comments.isEmpty &&
                      commentError == null &&
                      !commentsLoading)
                    const EmptyState('还没有评论，聊聊你的看法', '', compact: true),
                  for (final c in comments) ...[
                    commentTile(c),
                    thread(c),
                    const SizedBox(height: 10),
                  ],
                  PageLoadingFooter(visible: loadingMoreComments),
                ],
              ),
            ),
      bottomNavigationBar: articleRemoved
          ? null
          : Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  border: Border(
                    top: BorderSide(
                      color: (context.isDark
                          ? context.colors.border
                          : Color(0xFFF0F1F3)),
                      width: .5,
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (replyTarget != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '回复 ${replyTarget!.author}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: (context.isDark
                                          ? context.colors.muted
                                          : Color(0xFF92969E)),
                                    ),
                                  ),
                                ),
                                Tooltip(
                                  message: '取消回复',
                                  child: TextButton(
                                    onPressed:
                                        widget.store.pending.contains(
                                          'comment-${widget.story.id}',
                                        )
                                        ? null
                                        : () => setState(() {
                                            replyTarget = null;
                                            commentSendError = null;
                                          }),
                                    style: TextButton.styleFrom(
                                      foregroundColor: (context.isDark
                                          ? context.colors.muted
                                          : const Color(0xFF92969E)),
                                      overlayColor: Colors.transparent,
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(56, 24),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      textStyle: TextStyle(
                                        fontSize: 11,
                                        fontFamily: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.fontFamily,
                                      ),
                                    ).withoutHover(),
                                    child: const Text('取消回复'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (commentSendError != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              commentSendError!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: CommentInputField(
                                fieldKey: const ValueKey(
                                  'article-comment-input',
                                ),
                                controller: comment,
                                focusNode: commentFocus,
                                enabled: !widget.store.pending.contains(
                                  'comment-${widget.story.id}',
                                ),
                                maxLines:
                                    MediaQuery.sizeOf(context).height -
                                            MediaQuery.viewInsetsOf(context)
                                                .bottom <
                                        280
                                    ? 1
                                    : 3,
                                hintText: replyTarget == null
                                    ? '写下评论…'
                                    : '回复 ${replyTarget!.author}…',
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _send(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Tooltip(
                              message: '发送评论',
                              child: CommentSendButton(
                                buttonKey: const ValueKey(
                                  'article-comment-send',
                                ),
                                controller: comment,
                                sending: widget.store.pending.contains(
                                  'comment-${widget.story.id}',
                                ),
                                onPressed: _send,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _send() async {
    final text = comment.text.trim();
    if (text.isEmpty) return;
    final target = replyTarget;
    widget.store.enqueueContent(
      'PostArticlesIdComments',
      widget.story.id,
      {'content': text, if (target != null) 'reply_to_id': target.id},
      display: {
        if (target != null) 'parent_id': target.parentID ?? target.id,
        if (target != null)
          'reply_to': {'id': target.id, 'display_name': target.author},
      },
    );
    setState(() {
      if (target != null) expandedThreads.add(target.parentID ?? target.id);
      replyTarget = null;
      commentSendError = null;
      comment.clear();
    });
    commentFocus.unfocus();
  }
}

class StorySearch extends StatefulWidget {
  const StorySearch({
    super.key,
    required this.store,
    this.savedOnly = false,
    this.mineOnly = false,
  });
  final AppStore store;
  final bool savedOnly, mineOnly;
  @override
  State<StorySearch> createState() => _StorySearchState();
}

class _StorySearchState extends State<StorySearch> {
  final search = TextEditingController();
  String query = '';
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.mineOnly
      ? MyArticlesPage(store: widget.store)
      : widget.savedOnly
      ? SavedArticlesPage(store: widget.store)
      : AnimatedBuilder(
          animation: widget.store,
          builder: (context, _) {
            final results = widget.store.stories
                .where(
                  (s) =>
                      (!widget.savedOnly || s.saved) &&
                      (!widget.mineOnly || s.authorID == widget.store.userID) &&
                      (s.title + s.excerpt + s.author).contains(query),
                )
                .toList();
            return Scaffold(
              appBar: AppPageBar(
                title: Text(
                  widget.savedOnly
                      ? '我的收藏'
                      : widget.mineOnly
                      ? '我的文章'
                      : '搜索',
                ),
              ),
              body: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  AppSearchField(
                    fieldKey: const ValueKey('story-search'),
                    controller: search,
                    autofocus: !widget.savedOnly && !widget.mineOnly,
                    hintText: '搜索',
                    plainIcons: true,
                    onChanged: (v) => setState(() => query = v),
                  ),
                  const SizedBox(height: 20),
                  if (results.isEmpty)
                    const EmptyState('这里还没有内容', '试试其他关键词，或去发现页看看。'),
                  for (final story in results)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: StoryCard(story: story, store: widget.store),
                    ),
                ],
              ),
            );
          },
        );
}
