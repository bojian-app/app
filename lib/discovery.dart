import 'article_owner_actions.dart';
import 'app_page_bar.dart';
import 'api/bojian_api.dart';
import 'content_report.dart';
import 'playful_refresh.dart';

import 'dart:async';
import 'dart:math' as math;

import 'article_rich_content.dart';
import 'article_declaration.dart';
import 'article_poll.dart' show ArticlePollCard;
import 'panel_sheet.dart';
import 'article_reaction_button.dart';
import 'resume_guidance_view.dart';
import 'guidance_feed_card.dart';
import 'resume_updated_label.dart';
import 'resume_pages.dart' show ResumeLibrary;
import 'story_composer.dart';
export 'story_composer.dart';
import 'profile_avatar.dart';
import 'article_comment_tile.dart';
import 'withdraw_comment_button.dart';
import 'app_icons.dart';

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
import 'update_badge.dart';
import 'user_profile_page.dart';

part 'discovery_header.dart';

const _feedGapHeight = discoveryGapHeight;

Color _discoveryGapColor(BuildContext context) => discoveryGapColor(context);

class DiscoveryPage extends StatefulWidget {
  const DiscoveryPage({
    super.key,
    required this.store,
    this.onOpenProfile,
    this.onOpenMembership,
    this.onOpenService,
  });
  final AppStore store;
  final VoidCallback? onOpenProfile, onOpenMembership, onOpenService;
  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<DiscoveryPage> {
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
  final _seenArticles = <int>{};
  @override
  void dispose() {
    search.dispose();
    searchFocus.dispose();
    super.dispose();
  }

  Widget searchBar(BuildContext context) {
    final height = (MediaQuery.textScalerOf(context).scale(13) * 1.2 + 8)
        .clamp(32.0, double.infinity)
        .toDouble();
    final rowHeight = (height + 8).clamp(48.0, double.infinity).toDouble();
    final buttonStyle =
        (IconButtonTheme.of(context).style ?? const ButtonStyle()).copyWith(
          minimumSize: const WidgetStatePropertyAll(Size.square(44)),
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
    return Padding(
      // The avatar's tap target is padded, so its visible edge meets the
      // page gutter on the right.
      padding: const EdgeInsets.fromLTRB(
        appPageHorizontalPadding,
        2,
        appPageHorizontalPadding -
            (kMinInteractiveDimension - _discoveryAvatarSize) / 2,
        2,
      ),
      child: SizedBox(
        key: const ValueKey('discovery-search-row'),
        height: rowHeight,
        child: Row(
          children: [
            Expanded(
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
                  onChanged: (value) => setState(() => query = value.trim()),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
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
            const SizedBox(width: 8),
            IconButtonTheme(
              data: IconButtonThemeData(style: buttonStyle),
              child: SizedBox.square(
                dimension: 44,
                child: MessagesButton(
                  key: const ValueKey('discovery-messages'),
                  store: widget.store,
                  icon: AppIcons.notification,
                  iconSize: 20,
                ),
              ),
            ),
            _DiscoveryAvatarMenu(
              store: widget.store,
              onOpenProfile: widget.onOpenProfile,
              onOpenMembership: widget.onOpenMembership,
              onOpenService: widget.onOpenService,
              onScan: scanning ? null : scan,
            ),
          ],
        ),
      ),
    );
  }

  Widget headerWidth(Widget child) =>
      Center(child: SizedBox(width: 600, child: child));

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final term = query.toLowerCase();
    final stories = term.isEmpty
        ? store.stories.toList(growable: false)
        : store.stories
              .where(
                (story) => '${story.title} ${story.excerpt} ${story.author}'
                    .toLowerCase()
                    .contains(term),
              )
              .toList();
    late final indices = {
      for (var i = 0; i < stories.length; i++)
        ValueKey('discovery-story-${stories[i].id}'): i,
    };
    final ids = store.stories.map((story) => story.id).toSet();
    // Only records received after the first batch animate into the feed.
    final added = _seenArticles.isEmpty
        ? const <int>{}
        : ids.difference(_seenArticles);
    _seenArticles.addAll(ids);
    final feed = CustomScrollView(
      key: const PageStorageKey('discovery-feed-推荐'),
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(child: DiscoveryBanner(store: store)),
        if (stories.isEmpty && store.loading.contains('feed'))
          const SliverToBoxAdapter(child: _FeedSkeleton())
        else if (stories.isEmpty)
          SliverLayoutBuilder(
            builder: (context, constraints) => SliverToBoxAdapter(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      (constraints.viewportMainAxisExtent -
                              constraints.precedingScrollExtent -
                              24)
                          .clamp(0.0, double.infinity),
                ),
                child: Center(
                  child: DataStatus(
                    store: store,
                    section: 'feed',
                    empty: true,
                    title: query.isEmpty ? '还没有发布的内容' : '没有找到相关内容',
                    subtitle: query.isEmpty ? '' : '试试其他关键词。',
                  ),
                ),
              ),
            ),
          )
        else
          SliverList.builder(
            itemCount: stories.length,
            findChildIndexCallback: (key) => indices[key],
            itemBuilder: (context, index) {
              final story = stories[index];
              return _FeedArticleEntrance(
                key: ValueKey('discovery-story-${story.id}'),
                animate: added.contains(story.id),
                child: FeedRow(
                  gapColor: _discoveryGapColor(context),
                  child: StoryCard(story: story, store: store, flat: true),
                ),
              );
            },
          ),
        if (stories.isNotEmpty && store.errors['feed'] != null)
          SliverToBoxAdapter(
            child: DataStatus(store: store, section: 'feed', empty: false),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: PageLoadingFooter(
              visible: store.loadingMore.contains('feed'),
            ),
          ),
        ),
      ],
    );
    return ColoredBox(
      color: context.colors.surface,
      child: Column(
        children: [
          headerWidth(searchBar(context)),
          Divider(
            key: const ValueKey('discovery-feed-divider'),
            height: _feedGapHeight,
            thickness: _feedGapHeight,
            color: _discoveryGapColor(context),
          ),
          Expanded(
            child: Stack(
              children: [
                AutoPaginate.section(
                  store: store,
                  section: 'feed',
                  child: PlayfulRefresh(
                    hasError: () => store.errors['feed'] != null,
                    onRefresh: () => store.load('feed'),
                    child: feed,
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 18,
                  child: InviteFloatingBadge(store: store),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
      margin: const EdgeInsets.only(bottom: _feedGapHeight),
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
    await openPage<void>(context, StoryDetail(story: story, store: store));
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
          onTap: story.feedPoll == null ? () => _openDetail(context) : null,
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
                  // A poll or question has no page of its own to take it
                  // down from, so its author gets the action on the card.
                  if (story.feedPoll != null &&
                      story.authorID == store.userID &&
                      store.isAuthenticated)
                    ArticleOwnerActions(
                      store: store,
                      articleID: story.id,
                      popOnSuccess: false,
                      compact: true,
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
              if (story.feedPoll case final poll?)
                ArticlePollCard(
                  key: ValueKey('story-poll-${story.id}'),
                  block: poll,
                  store: store,
                  articleID: story.id,
                  embedded: true,
                ),
              SizedBox(height: flat ? 2 : 8),
              Row(
                children: [
                  Expanded(
                    // Without the reaction buttons that set this row's height,
                    // padding gives a poll post the same row height as others.
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: story.feedPoll == null ? 0 : 11,
                      ),
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
                  ),
                  if (story.feedPoll == null) ...[
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
                          () =>
                              runRequest(context, () => store.bookmark(story)),
                    ),
                  ],
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
  final VoidCallback? onTap;
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

class StoryDetail extends StatefulWidget {
  const StoryDetail({super.key, required this.story, required this.store});
  final Story story;
  final AppStore store;
  @override
  State<StoryDetail> createState() => _StoryDetailState();
}

class _StoryDetailState extends State<StoryDetail> {
  final scroll = ScrollController();
  // Heading blocks get keys, so the table of contents can scroll to them.
  final headingKeys = <int, GlobalKey>{};
  late ArticleRichBody body = _buildBody(widget.story.content);

  ArticleRichBody _buildBody(Map<String, dynamic> content) {
    final data = content.isEmpty
        ? richContent(widget.story.paragraphs.join('\n'))
        : content;
    headingKeys
      ..clear()
      ..addAll({
        for (final heading in articleHeadings(data))
          heading.blockIndex: GlobalKey(),
      });
    return ArticleRichBody(
      store: widget.store,
      articleID: widget.story.id,
      content: data,
      headingKeys: headingKeys,
    );
  }

  List<ArticleHeading> get headings => articleHeadings(body.content);

  Future<void> showContents() async {
    final items = headings;
    if (items.isEmpty) return;
    final minLevel = items.map((h) => h.level).reduce(math.min);
    final picked = await showPanelSheet<int>(
      context,
      builder: (sheet) => PanelSheet(
        title: '目录',
        child: ListView(
          key: const ValueKey('article-contents'),
          children: [
            for (final heading in items)
              InkWell(
                key: ValueKey('article-contents-${heading.blockIndex}'),
                onTap: () => Navigator.pop(sheet, heading.blockIndex),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    12 + (heading.level - minLevel) * 16.0,
                    12,
                    12,
                    12,
                  ),
                  child: Text(
                    heading.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: heading.level == minLevel
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: context.colors.ink,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) await jumpToHeading(picked);
  }

  Future<void> jumpToHeading(int blockIndex) async {
    var target = headingKeys[blockIndex]?.currentContext;
    // The article is one list item; bring it back into the tree first.
    if (target == null && scroll.hasClients) {
      scroll.jumpTo(0);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      target = headingKeys[blockIndex]?.currentContext;
    }
    if (target == null || !target.mounted) return;
    await Scrollable.ensureVisible(
      target,
      alignment: .04,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
    );
  }

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
        if (result.data['can_comment'] is bool) {
          widget.story.canComment = result.data['can_comment'] as bool;
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
    if (!widget.story.canComment ||
        widget.store.pending.contains('comment-${widget.story.id}'))
      return;
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

  Map<int?, List<ArticleComment>> localCommentsByParent() {
    final grouped = <int?, List<ArticleComment>>{};
    for (final row in widget.store.localContent(
      'PostArticlesIdComments',
      widget.story.id,
    )) {
      final comment = ArticleComment.fromJson(row);
      (grouped[comment.parentID] ??= []).add(comment);
    }
    return grouped;
  }

  List<ArticleComment> mergeComments(
    List<ArticleComment> remote,
    List<ArticleComment>? local,
  ) {
    if (local == null || local.isEmpty) return remote;
    final ids = local.map((c) => c.id).toSet();
    return [...local.reversed, ...remote.where((c) => !ids.contains(c.id))];
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
    onReply: widget.story.canComment && c.visible ? () => reply(c) : null,
    onReport: () => reportContent(
      context,
      store: widget.store,
      subjectType: 'COMMENT',
      subjectID: c.id,
    ),
    onRetry: !widget.story.canComment || c.local == null
        ? null
        : () => widget.store.sendContent(c.local!),
    onEdit: !widget.story.canComment
        ? null
        : () => setState(() {
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
  Widget thread(ArticleComment root, List<ArticleComment>? local) {
    final expanded = expandedThreads.contains(root.id);
    return Padding(
      padding: const EdgeInsets.only(left: 42),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (expanded) ...[
            for (final c in mergeComments(threads[root.id] ?? const [], local))
              commentTile(c, nested: true),
            if (loadingThreads.contains(root.id))
              const DotMatrixLoader(compact: true),
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
              local?.isNotEmpty == true ||
              threads[root.id]?.isNotEmpty == true ||
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
      if (mergeComments(
            widget.story.comments,
            localCommentsByParent()[null],
          ).any(
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
    scroll.dispose();
    commentFocus.dispose();
    comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) => _buildPage(context),
  );

  List<Widget> _articleHeader(bool commentsEmpty) => [
    if (widget.story.title.trim().isNotEmpty)
      Text(
        widget.story.title,
        style: TextStyle(
          fontSize: 26,
          height: 1.45,
          fontWeight: FontWeight.w700,
          shadows: articleBoldShadows(context, context.colors.ink, size: 26),
        ),
      ),
    ArticleDeclarationLabel(body.content),
    if (widget.story.title.trim().isNotEmpty ||
        readArticleDeclaration(body.content).label.isNotEmpty)
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
                style: TextStyle(fontSize: 11, color: context.colors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          widget.story.publishedAt.split('T').first,
          style: TextStyle(color: context.colors.muted, fontSize: 11),
        ),
      ],
    ),
    const SizedBox(height: 26),
    if (widget.story.cover == 1) ...[_StoryCover(), const SizedBox(height: 24)],
    if (widget.story.hasGuidance)
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: OutlinedButton(
          onPressed: () => openPage(
            context,
            ResumeGuidanceView(store: widget.store, id: widget.story.id),
          ),
          child: const Text('查看简历'),
        ),
      ),
    body,
    if (bodyError != null)
      TextButton(onPressed: loadBody, child: Text('$bodyError，点击重试')),
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
            onTap: widget.store.pending.contains('like-${widget.story.id}')
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
            onTap: widget.store.pending.contains('bookmark-${widget.story.id}')
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
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
    const SizedBox(height: 4),
    if (commentError != null) ...[
      Text(
        commentError!,
        style: TextStyle(color: context.colors.muted, fontSize: 12),
      ),
      TextButton(onPressed: loadComments, child: const Text('重新加载评论')),
    ],
    if (commentsLoading) const DotMatrixLoader(compact: true),
    if (commentsEmpty && commentError == null && !commentsLoading)
      EmptyState(
        widget.story.canComment ? '还没有评论，聊聊你的看法' : '还没有评论',
        '',
        compact: true,
      ),
  ];

  Widget _buildPage(BuildContext context) {
    final local = localCommentsByParent();
    final comments = mergeComments(widget.story.comments, local[null]);
    final header = _articleHeader(comments.isEmpty);
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppPageBar(
        // The icon's own edge, not its 48 px tap target, sits on the gutter.
        actionsPadding: const EdgeInsetsDirectional.only(end: 10),
        actions: [
          if (!articleRemoved && headings.length >= 2)
            IconButton(
              key: const ValueKey('article-contents-button'),
              tooltip: '目录',
              onPressed: showContents,
              icon: const AppIcon(AppIcons.outline, size: 20),
            ),
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
              child: ListView.builder(
                controller: scroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  appPageHorizontalPadding,
                  12,
                  appPageHorizontalPadding,
                  24,
                ),
                itemCount: header.length + comments.length + 1,
                itemBuilder: (context, index) {
                  if (index < header.length) return header[index];
                  if (index == header.length + comments.length) {
                    return PageLoadingFooter(visible: loadingMoreComments);
                  }
                  final root = comments[index - header.length];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      commentTile(root),
                      thread(root, local[root.id]),
                      const SizedBox(height: 10),
                    ],
                  );
                },
              ),
            ),
      bottomNavigationBar: articleRemoved
          ? null
          : !widget.story.canComment
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 20,
                ),
                child: Text(
                  '仅作者关注的人可以回复',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.muted, fontSize: 13),
                ),
              ),
            )
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
    if (!widget.story.canComment || text.isEmpty) return;
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
