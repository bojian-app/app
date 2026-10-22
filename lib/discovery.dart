import 'playful_refresh.dart';

import 'dart:async';

import 'article_rich_content.dart';
import 'article_reaction_button.dart';
import 'resume_guidance_view.dart';
import 'guidance_feed_card.dart';
import 'story_composer.dart';
export 'story_composer.dart';
import 'profile_avatar.dart';
import 'profile_identity.dart';
import 'article_comment_tile.dart';
import 'app_icons.dart';

import 'package:flutter/material.dart';

import 'app_store.dart';
import 'discovery_banner.dart';
import 'design.dart';
import 'discovery_art.dart';
import 'messages_button.dart';
import 'my_articles_page.dart';
import 'saved_articles_page.dart';
import 'story_author_identity.dart';
import 'user_profile_page.dart';

class DiscoveryPage extends StatefulWidget {
  const DiscoveryPage({super.key, required this.store});
  final AppStore store;
  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<DiscoveryPage> {
  static const categories = ['推荐', '简历求指点', '经验分享'];
  final search = TextEditingController();
  final searchFocus = FocusNode();
  String query = '';
  bool openingComposer = false;
  final _seenArticles = <String, Set<int>>{};
  @override
  void dispose() {
    search.dispose();
    searchFocus.dispose();
    super.dispose();
  }

  Future<void> write() async {
    if (openingComposer ||
        !widget.store.isAuthenticated ||
        ModalRoute.of(context)?.isCurrent != true ||
        !TickerMode.valuesOf(context).enabled) {
      return;
    }
    setState(() => openingComposer = true);
    try {
      await openPage(context, StoryComposer(store: widget.store));
    } finally {
      if (mounted) setState(() => openingComposer = false);
    }
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
    final known = _seenArticles.putIfAbsent(
      category,
      () => stories.map((story) => story.id).toSet(),
    );
    final added = stories
        .where((story) => !known.contains(story.id))
        .map((story) => story.id)
        .toSet();
    known.addAll(stories.map((story) => story.id));
    return LayoutBuilder(
      builder: (context, constraints) => PlayfulRefresh(
        hasError: () => widget.store.errors['feed'] != null,
        onRefresh: () => widget.store.load('feed'),
        child: ListView(
          key: PageStorageKey('discovery-feed-$category'),
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (stories.isEmpty)
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
                    illustration: DiscoveryArt(
                      scene: query.isEmpty
                          ? DiscoveryScene.community
                          : DiscoveryScene.search,
                    ),
                  ),
                ),
              ),
            for (final story in stories)
              _FeedArticleEntrance(
                key: ValueKey('discovery-story-${story.id}'),
                animate: added.contains(story.id),
                child: ColoredBox(
                  color: context.colors.canvas,
                  child: Container(
                    color: context.colors.surface,
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: StoryCard(
                          story: story,
                          store: widget.store,
                          flat: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (stories.isNotEmpty && widget.store.errors['feed'] != null)
              DataStatus(store: widget.store, section: 'feed', empty: false),
            MoreButton(store: widget.store, section: 'feed'),
          ],
        ),
      ),
    );
  }

  Widget searchBar(BuildContext context) {
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        key: const ValueKey('discovery-search-row'),
        height: rowHeight,
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
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
            const SizedBox(width: 8),
            SizedBox(
              width: 88,
              height: 44,
              child: IconButtonTheme(
                data: IconButtonThemeData(style: buttonStyle),
                child: Row(
                  children: [
                    Semantics(
                      label: '发布动态',
                      button: true,
                      excludeSemantics: true,
                      onTap: openingComposer || !widget.store.isAuthenticated
                          ? null
                          : write,
                      child: IconButton(
                        key: const ValueKey('discovery-create'),
                        tooltip: '发布动态',
                        onPressed:
                            openingComposer || !widget.store.isAuthenticated
                            ? null
                            : write,
                        icon: AppIcon(
                          AppIcons.send,
                          size: 20,
                          color: context.colors.ink,
                        ),
                      ),
                    ),
                    SizedBox.square(
                      dimension: 44,
                      child: MessagesButton(
                        key: const ValueKey('discovery-messages'),
                        store: widget.store,
                        iconSize: 20,
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
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colors.surface,
      child: DefaultTabController(
        length: categories.length,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerScrolled) => [
            SliverToBoxAdapter(child: searchBar(context)),
            SliverAppBar(
              primary: false,
              pinned: true,
              toolbarHeight: 0,
              automaticallyImplyLeading: false,
              backgroundColor: context.colors.surface,
              scrolledUnderElevation: 0,
              bottom: ProfileContentTabs(
                tabBarKey: const ValueKey('discovery-tabs'),
                tabs: [
                  for (final category in categories)
                    Tab(text: category, height: 36),
                ],
              ),
            ),
            SliverToBoxAdapter(child: DiscoveryBanner(store: widget.store)),
            SliverToBoxAdapter(
              child: ColoredBox(
                color: context.colors.canvas,
                child: const SizedBox(height: 8),
              ),
            ),
          ],
          body: TabBarView(
            children: [for (final category in categories) feed(category)],
          ),
        ),
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
  });
  final Story story;
  final AppStore store;
  final bool flat;
  final bool compactTypography;
  final String? authorName, authorAvatarURL;
  final bool authorNavigationEnabled;
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Semantics(
                    button:
                        authorNavigationEnabled &&
                        story.authorID > 0 &&
                        story.authorID != store.userID,
                    label: '${authorName ?? story.author}的头像',
                    child: InkWell(
                      key: ValueKey('story-author-avatar-${story.id}'),
                      borderRadius: BorderRadius.circular(13),
                      onTap:
                          !authorNavigationEnabled ||
                              story.authorID <= 0 ||
                              story.authorID == store.userID
                          ? null
                          : () => openPage(
                              context,
                              UserProfilePage(
                                store: store,
                                userID: story.authorID,
                              ),
                            ),
                      child: Padding(
                        padding: EdgeInsets.all(flat ? 7 : 4),
                        child: ProfileAvatar(
                          seed: story.authorID > 0
                              ? '${story.authorID}'
                              : story.author,
                          url: authorAvatarURL ?? story.authorAvatarURL,
                          size: 30,
                        ),
                      ),
                    ),
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
              SizedBox(height: flat ? 8 : 12),
              InkWell(
                onTap: () =>
                    openPage(context, StoryDetail(story: story, store: store)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      story.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compactTypography ? 14 : 16,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: flat ? 4 : 6),
                    Text(
                      story.excerpt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compactTypography ? 12 : (flat ? 13 : 11.5),
                        color: flat ? context.colors.ink : context.colors.muted,
                        height: 1.5,
                      ),
                    ),
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
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      story.publishedAt.split('T').first,
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
                    onTap: store.pending.contains('like-${story.id}')
                        ? null
                        : () => runRequest(context, () => store.like(story)),
                  ),
                  SizedBox(width: flat ? 12 : 16),
                  _Reaction(
                    icon: AppIcons.comment,
                    label: '${story.commentCount}',
                    onTap: () => openPage(
                      context,
                      StoryDetail(story: story, store: store),
                    ),
                  ),
                  SizedBox(width: flat ? 12 : 16),
                  ArticleReactionButton(
                    key: ValueKey('story-bookmark-${story.id}'),
                    reaction: ArticleReaction.bookmark,
                    compact: true,
                    active: story.saved,
                    onTap: store.pending.contains('bookmark-${story.id}')
                        ? null
                        : () =>
                              runRequest(context, () => store.bookmark(story)),
                  ),
                ],
              ),
            ],
          ),
        );
}

class _StorySurface extends StatelessWidget {
  const _StorySurface({required this.flat, required this.child});
  final bool flat;
  final Widget child;
  @override
  Widget build(BuildContext context) => flat
      ? Material(
          color: context.colors.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: child,
          ),
        )
      : Panel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: child,
        );
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
  late Map<String, dynamic> bodyContent = widget.story.content;
  String? bodyError;
  Future<void> loadBody() async {
    try {
      final result = await widget.store.request(
        'GetArticlesId',
        path: {'id': '${widget.story.id}'},
      );
      if (!mounted) return;
      setState(() {
        if (result.data['content'] != null) {
          bodyContent = decodeStory(result.data).content;
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
    } catch (_) {
      if (mounted) setState(() => bodyError = '文章暂时无法加载');
    }
  }

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
          ...items(result.data).map(ArticleComment.fromJson),
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

  Widget commentTile(ArticleComment c, {bool nested = false}) =>
      ArticleCommentTile(
        comment: c,
        articleAuthorID: widget.story.authorID,
        currentUserID: widget.store.userID,
        nested: nested,
        onAuthorTap: () =>
            openUserProfile(context, store: widget.store, userID: c.authorID),
        onReply: () => reply(c),
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
            for (final c in threads[root.id] ?? <ArticleComment>[])
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
          if (root.replyCount > 0 || expanded)
            TextButton(
              key: ValueKey('article-thread-toggle-${root.id}'),
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
              style: TextButton.styleFrom(
                foregroundColor: (context.isDark
                    ? context.colors.muted
                    : const Color(0xFF7F8897)),
                overlayColor: Colors.transparent,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: TextStyle(
                  fontFamily: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ).withoutHover(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 18,
                    height: 1,
                    color: (context.isDark
                        ? context.colors.accentSoft
                        : const Color(0xFFD7DADE)),
                  ),
                  const SizedBox(width: 8),
                  Text(expanded ? '收起回复' : '展开 ${root.replyCount} 条回复'),
                  const SizedBox(width: 2),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String? commentError, commentSendError;
  bool commentsLoading = true;
  StreamSubscription<Map<String, dynamic>>? realtime;
  Timer? refreshTimer;
  bool refreshingComments = false, refreshCommentsPending = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        loadBody();
        loadComments();
      }
    });
    realtime = widget.store.realtimeEvents.listen((event) {
      final data = event['data'] is Map ? event['data'] as Map : const {};
      if (event['type'] != 'connection.ready' &&
          (!{
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
          loadComments(silent: true);
          for (final root in expandedThreads.toList()) {
            loadThread(root);
          }
        }
      });
    });
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
    refreshTimer?.cancel();
    unawaited(realtime?.cancel());
    commentFocus.dispose();
    comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) => Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        actions: [const DismissKeyboardButton()],
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        children: [
          Text(
            widget.story.title,
            style: const TextStyle(
              fontSize: 26,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
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
                style: TextStyle(color: context.colors.muted, fontSize: 11),
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
                  ResumeGuidanceView(store: widget.store, id: widget.story.id),
                ),
                child: const Text('查看简历并指点'),
              ),
            ),
          ArticleRichBody(
            content: bodyContent.isEmpty
                ? richContent(widget.story.paragraphs.join('\n'))
                : bodyContent,
          ),
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
                  onTap:
                      widget.store.pending.contains('like-${widget.story.id}')
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
          if (commentsLoading)
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          if (widget.story.comments.isEmpty &&
              commentError == null &&
              !commentsLoading)
            Text(
              '还没有评论，聊聊你的看法',
              style: TextStyle(color: context.colors.muted, fontSize: 13),
            ),
          for (
            var index = 0;
            index < widget.story.comments.length;
            index++
          ) ...[
            commentTile(widget.story.comments[index]),
            thread(widget.story.comments[index]),
            const SizedBox(height: 10),
          ],
        ],
      ),
      bottomNavigationBar: Padding(
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
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                        child: TextField(
                          key: const ValueKey('article-comment-input'),
                          controller: comment,
                          focusNode: commentFocus,
                          enabled: !widget.store.pending.contains(
                            'comment-${widget.story.id}',
                          ),
                          minLines: 1,
                          maxLines:
                              MediaQuery.sizeOf(context).height -
                                      MediaQuery.viewInsetsOf(context).bottom <
                                  280
                              ? 1
                              : 3,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: (context.isDark
                                ? context.colors.ink
                                : Color(0xFF24262B)),
                          ),
                          decoration: InputDecoration(
                            hintText: replyTarget == null
                                ? '写下评论…'
                                : '回复 ${replyTarget!.author}…',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: (context.isDark
                                  ? context.colors.muted
                                  : Color(0xFFA7ABB3)),
                            ),
                            filled: true,
                            fillColor: (context.isDark
                                ? context.colors.inset
                                : const Color(0xFFF4F5F7)),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 11,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(22),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: comment,
                        builder: (_, value, _) {
                          final sending = widget.store.pending.contains(
                            'comment-${widget.story.id}',
                          );
                          return Tooltip(
                            message: '发送评论',
                            child: FilledButton(
                              key: const ValueKey('article-comment-send'),
                              onPressed: sending || value.text.trim().isEmpty
                                  ? null
                                  : _send,
                              style: FilledButton.styleFrom(
                                backgroundColor: blue,
                                disabledBackgroundColor: (context.isDark
                                    ? context.colors.inset
                                    : const Color(0xFFF0F1F4)),
                                disabledForegroundColor: (context.isDark
                                    ? context.colors.muted
                                    : const Color(0xFFB3B7BE)),
                                minimumSize: const Size(52, 42),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(21),
                                ),
                                textStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.fontFamily,
                                ),
                              ).withoutHover(),
                              child: Text(sending ? '发送中' : '发送'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Future<void> _send() async {
    final text = comment.text.trim();
    if (text.isEmpty ||
        widget.store.pending.contains('comment-${widget.story.id}')) {
      return;
    }
    final target = replyTarget;
    setState(() => commentSendError = null);
    final sent = await runRequest(
      context,
      () => widget.store.comment(widget.story, text, replyToID: target?.id),
    );
    if (!mounted) return;
    if (!sent) {
      setState(() => commentSendError = '发送失败，请重试');
      return;
    }
    setState(() {
      commentError = null;
      commentSendError = null;
      replyTarget = null;
    });
    if (target != null) await loadThread(target.parentID ?? target.id);
    if (!mounted) return;
    comment.clear();
    FocusScope.of(context).unfocus();
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
              appBar: AppBar(
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
                  TextField(
                    key: const ValueKey('story-search'),
                    controller: search,
                    autofocus: !widget.savedOnly && !widget.mineOnly,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => dismissKeyboard(),
                    decoration: InputDecoration(
                      hintText: '搜索',
                      prefixIcon: const AppIcon(AppIcons.search),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: '清空搜索',
                              onPressed: () {
                                search.clear();
                                setState(() => query = '');
                              },
                              icon: const AppIcon(AppIcons.clear, size: 18),
                            ),
                    ),
                    onChanged: (v) => setState(() => query = v.trim()),
                  ),
                  const SizedBox(height: 20),
                  if (results.isEmpty)
                    const EmptyState(
                      '这里还没有内容',
                      '试试其他关键词，或去发现页看看。',
                      illustration: DiscoveryArt(scene: DiscoveryScene.search),
                    ),
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
