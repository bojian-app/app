import 'article_owner_actions.dart';
import 'article_poll.dart' show openArticlePollComposer;
import 'article_privacy.dart';
import 'content_moderation.dart';
import 'app_page_bar.dart';
import 'panel_sheet.dart';
import 'playful_refresh.dart';

import 'dart:async';

import 'article_rich_content.dart';

import 'package:flutter/material.dart';

import 'api/bojian_api.dart';
import 'app_icons.dart';
import 'app_store.dart';
import 'confirmation_dialog.dart';
import 'app_search_field.dart';
import 'design.dart';
import 'discovery.dart';
import 'resume_updated_label.dart';
import 'user_display_name.dart';

const _statuses = {
  'SUBMITTED': '审核中',
  'PUBLISHED': '已发布',
  'DRAFT': '草稿',
  'REJECTED': '未通过',
};

Color _statusColor(BuildContext context, String status) => switch (status) {
  'SUBMITTED' => const Color(0xFFB57920),
  'PUBLISHED' => const Color(0xFF38876F),
  'REJECTED' => Theme.of(context).colorScheme.error,
  _ => context.colors.muted,
};

String _time(dynamic value) {
  final date = DateTime.tryParse('$value');
  return date == null ? '' : resumeUpdatedLabel(date);
}

class MyArticlesPage extends StatefulWidget {
  const MyArticlesPage({
    super.key,
    required this.store,
    this.embedded = false,
    this.publishedOnly = false,
    this.draftsOnly = false,
  });
  final AppStore store;
  final bool embedded;
  final bool publishedOnly;
  final bool draftsOnly;
  @override
  State<MyArticlesPage> createState() => _MyArticlesPageState();
}

class _MyArticlesPageState extends State<MyArticlesPage> {
  String status = 'SUBMITTED', query = '', cursor = '';
  List<Map<String, dynamic>> articles = [];
  final feedStories = <int, Story>{};
  bool loading = true, loadingMore = false;
  String? error;
  int generation = 0;
  String? opening, deleting;
  StreamSubscription<Map<String, dynamic>>? realtime;
  Timer? refreshTimer;
  bool get feedLayout => widget.embedded && widget.publishedOnly;

  bool _current(int request, int session) =>
      mounted && generation == request && widget.store.epoch == session;

  Future<List<Map<String, dynamic>>> _publishedRows(
    List<Map<String, dynamic>> rows,
    int request,
    int session,
  ) async {
    final published = rows
        .where((row) => row['status'] == 'PUBLISHED')
        .toList();
    final result = <Map<String, dynamic>>[];
    // The management endpoint returns metadata only. Complete one page in
    // bounded batches, without changing the user's feed or fetching comments.
    for (var start = 0; start < published.length; start += 4) {
      if (!_current(request, session)) return [];
      final batch = await Future.wait(
        published.skip(start).take(4).map((row) async {
          if ([
            'content',
            'comment_count',
            'is_liked',
            'is_favorited',
          ].every(row.containsKey)) {
            return row;
          }
          final detail = await widget.store.request(
            'GetArticlesId',
            path: {'id': '${row['id']}'},
          );
          if (integer(detail.data['id']) != integer(row['id']) ||
              !detail.data.containsKey('content')) {
            throw const ApiFailure('文章暂时无法加载');
          }
          return {...row, ...detail.data};
        }),
      );
      result.addAll(batch.where((row) => row['status'] == 'PUBLISHED'));
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    if (widget.publishedOnly) status = 'PUBLISHED';
    if (widget.draftsOnly) status = 'DRAFT';
    _load();
    realtime = widget.store.realtimeEvents.listen((event) {
      if (!{'connection.ready', 'article.updated'}.contains(event['type'])) {
        return;
      }
      refreshTimer?.cancel();
      refreshTimer = Timer(const Duration(milliseconds: 200), () {
        if (mounted) _load(silent: true);
      });
    });
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    unawaited(realtime?.cancel());
    super.dispose();
  }

  Future<void> _load({bool more = false, bool silent = false}) async {
    if (more && (loadingMore || loading || cursor.isEmpty)) return;
    final requestGeneration = more ? generation : ++generation;
    final session = widget.store.epoch;
    final requestedStatus = widget.publishedOnly ? 'PUBLISHED' : status;
    final requestedCursor = more ? cursor : '';
    setState(() {
      error = null;
      if (more) {
        loadingMore = true;
      } else {
        if (!silent) loading = true;
        loadingMore = false;
      }
    });
    try {
      final response = await widget.store.request(
        'GetMeArticles',
        query: {
          'status': requestedStatus,
          'limit': '20',
          if (requestedCursor.isNotEmpty) 'cursor': requestedCursor,
        },
      );
      if (!_current(requestGeneration, session)) return;
      final rows = feedLayout
          ? await _publishedRows(
              items(response.data),
              requestGeneration,
              session,
            )
          : items(response.data);
      if (!_current(requestGeneration, session)) return;
      setState(() {
        articles = more ? [...articles, ...rows] : rows;
        if (feedLayout) {
          if (!more) feedStories.clear();
          for (final row in rows) {
            final story = decodeStory({
              ...row,
              'author': {
                ...?row['author'] as Map<String, dynamic>?,
                'id': widget.store.userID,
                'display_name': userDisplayName(widget.store.name),
                'avatar_url': widget.store.avatarURL,
              },
            });
            feedStories[story.id] = story;
          }
        }
        cursor = response.nextCursor;
      });
    } catch (e) {
      if (_current(requestGeneration, session)) {
        setState(() => error = '$e');
      }
    } finally {
      if (_current(requestGeneration, session)) {
        setState(() {
          loading = false;
          loadingMore = false;
        });
      }
    }
  }

  Future<void> _open(Map<String, dynamic> row) async {
    if (opening != null) return;
    final id = '${row['id']}';
    final session = widget.store.epoch;
    setState(() => opening = id);
    try {
      final response = await widget.store.request(
        'GetArticlesId',
        path: {'id': id},
      );
      if (!mounted || widget.store.epoch != session) return;
      if (integer(response.data['id']) != integer(row['id'])) {
        throw const ApiFailure('文章暂时无法加载');
      }
      final detail = {...row, ...response.data};
      final story = decodeStory(response.data);
      if (detail['status'] == 'DRAFT') {
        // A poll or question is edited in its own form, not in the editor.
        if (story.feedPoll case final poll?) {
          await _editPoll(detail, poll);
        } else {
          await openPage(
            context,
            StoryComposer(store: widget.store, draft: detail),
          );
        }
        if (mounted && widget.store.epoch == session) await _load();
      } else {
        await openPage(
          context,
          OwnArticlePreview(store: widget.store, story: story, row: detail),
        );
      }
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => opening = null);
    }
  }

  /// Reopens a taken-down poll or question in its form. Finishing it
  /// publishes the post again with the new poll in place of the old one.
  Future<void> _editPoll(
    Map<String, dynamic> draft,
    Map<String, dynamic> poll,
  ) async {
    final session = widget.store.epoch;
    final block = await openArticlePollComposer(
      context,
      widget.store,
      initial: poll,
    );
    if (block == null || !mounted || widget.store.epoch != session) return;
    try {
      final content = Map<String, dynamic>.from(draft['content'] as Map? ?? {});
      content['blocks'] = [
        for (final old in content['blocks'] as List? ?? const [])
          if (old is Map && old['kind'] != 'poll') old,
        block,
      ];
      final privacy = ArticlePrivacy.fromDraft(draft);
      final id = integer(draft['id']);
      await widget.store.saveArticleDraft(
        id: id,
        title: '${draft['title'] ?? ''}',
        content: content,
        resumeID: draft['resume_id'] as int?,
        visibility: privacy.visibility,
        followedRepliesOnly: privacy.followedRepliesOnly,
        expectedEpoch: session,
      );
      final status = await widget.store.submitArticleDraft(
        id,
        expectedEpoch: session,
      );
      if (mounted) toast(context, articleSubmissionMessage(status));
    } catch (error) {
      if (mounted) await showRequestFailure(context, error);
    }
  }

  Future<void> _deleteDraft(Map<String, dynamic> row) async {
    if (deleting != null) return;
    final id = '${row['id']}';
    final title = '${row['title'] ?? ''}'.trim();
    final confirmed = await showAppConfirmation(
      context,
      title: '删除这篇草稿？',
      content: Text(title.isEmpty ? '删除后无法恢复。' : '“$title”删除后无法恢复。'),
      confirmLabel: '删除',
      destructive: true,
      confirmKey: ValueKey('draft-delete-confirm-$id'),
    );
    if (confirmed != true || !mounted) return;
    final session = widget.store.epoch;
    setState(() => deleting = id);
    try {
      await widget.store.request('DeleteArticlesId', path: {'id': id});
      if (!mounted || widget.store.epoch != session) return;
      setState(() => articles.removeWhere((item) => '${item['id']}' == id));
      toast(context, '草稿已删除', success: true);
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => deleting = null);
    }
  }

  Future<void> _write() async {
    await openPage(context, StoryComposer(store: widget.store));
    if (mounted) _load();
  }

  Widget writeButton() =>
      TextButton(onPressed: _write, child: const Text('写文章'));

  Widget _feedCard(Map<String, dynamic> row) => FeedRow(
    child: ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) => StoryCard(
        key: ValueKey('profile-story-${row['id']}'),
        story: feedStories[integer(row['id'])]!,
        store: widget.store,
        flat: true,
        compactTypography: true,
        authorName: userDisplayName(widget.store.name),
        authorAvatarURL: widget.store.avatarURL,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final visible = articles
        .where((row) => !widget.publishedOnly || row['status'] == 'PUBLISHED')
        .where((row) => !widget.draftsOnly || row['status'] == 'DRAFT')
        .where((row) => articleListLabel(row).contains(query))
        .toList();
    final body = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: feedLayout ? double.infinity : 680,
        ),
        child: AutoPaginate(
          canLoad:
              cursor.isNotEmpty && !loading && !loadingMore && error == null,
          onLoadMore: () => _load(more: true),
          child: PlayfulRefresh(
            onRefresh: _load,
            hasError: () => error != null,
            child: CustomScrollView(
              key: PageStorageKey(
                widget.embedded
                    ? widget.draftsOnly
                          ? 'profile-drafts'
                          : 'profile-articles'
                    : 'my-articles',
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (!widget.embedded ||
                    (!widget.publishedOnly && !widget.draftsOnly))
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        if (!widget.embedded)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              appPageHorizontalPadding,
                              16,
                              appPageHorizontalPadding,
                              14,
                            ),
                            child: AppSearchField(
                              fieldKey: const ValueKey('my-articles-search'),
                              hintText: '搜索文章',
                              fillColor: context.colors.surface,
                              clearable: false,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              onChanged: (value) =>
                                  setState(() => query = value),
                            ),
                          ),
                        if (!widget.publishedOnly && !widget.draftsOnly)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: appPageHorizontalPadding,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: (context.isDark
                                    ? context.colors.inset
                                    : const Color(0xFFEDEFF3)),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  for (final entry in _statuses.entries)
                                    Expanded(
                                      child: Semantics(
                                        selected: status == entry.key,
                                        child: TextButton(
                                          key: ValueKey(
                                            'articles-${entry.key}',
                                          ),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 3,
                                            ),
                                            minimumSize: const Size(0, 40),
                                            backgroundColor: status == entry.key
                                                ? context.colors.surface
                                                : Colors.transparent,
                                            foregroundColor: status == entry.key
                                                ? context.colors.ink
                                                : context.colors.muted,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            textStyle: Theme.of(context)
                                                .textTheme
                                                .labelLarge
                                                ?.copyWith(
                                                  fontSize: 13,
                                                  fontWeight:
                                                      status == entry.key
                                                      ? FontWeight.w700
                                                      : FontWeight.w500,
                                                ),
                                          ).withoutHover(),
                                          onPressed: () {
                                            if (status == entry.key) return;
                                            setState(() {
                                              status = entry.key;
                                              articles = [];
                                              cursor = '';
                                            });
                                            _load();
                                          },
                                          child: Text(entry.value),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    feedLayout ? 0 : appPageHorizontalPadding,
                    feedLayout || widget.draftsOnly ? 0 : 12,
                    feedLayout ? 0 : appPageHorizontalPadding,
                    24,
                  ),
                  sliver: SliverList.list(
                    children: [
                      if (loading)
                        const ListSkeleton(count: 4)
                      else ...[
                        if (status == 'SUBMITTED' && articles.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(left: 2, bottom: 16),
                            child: Text(
                              '审核通过后，文章将公开展示。',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.colors.muted,
                              ),
                            ),
                          ),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Column(
                              children: [
                                Text(
                                  error!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: context.colors.muted,
                                    fontSize: 13,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _load(
                                    more:
                                        articles.isNotEmpty &&
                                        cursor.isNotEmpty,
                                  ),
                                  child: const Text('重新加载'),
                                ),
                              ],
                            ),
                          ),
                        if (visible.isEmpty && error == null)
                          EmptyState(
                            query.isNotEmpty
                                ? '没有找到这篇文章'
                                : feedLayout
                                ? '暂无已发表的动态'
                                : '暂无${_statuses[status]}的文章',
                            query.isNotEmpty
                                ? '试试其他标题关键词'
                                : status == 'SUBMITTED'
                                ? '提交后的文章会显示在这里'
                                : '下拉刷新，查看最新状态',
                          ),
                        for (final row in visible)
                          if (feedLayout)
                            _feedCard(row)
                          else if (row['status'] == 'DRAFT')
                            _DraftRow(
                              key: ValueKey((
                                widget.store,
                                widget.store.epoch,
                                row['id'],
                                row['updated_at'],
                              )),
                              store: widget.store,
                              row: row,
                              busy:
                                  opening == '${row['id']}' ||
                                  deleting == '${row['id']}',
                              onOpen: () => _open(row),
                              onDelete: () => _deleteDraft(row),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _ArticleCard(
                                row: row,
                                busy:
                                    opening == '${row['id']}' ||
                                    deleting == '${row['id']}',
                                onTap: () => _open(row),
                              ),
                            ),
                        PageLoadingFooter(visible: loadingMore),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppPageBar(
        title: Text(widget.draftsOnly ? '草稿箱' : '我的文章'),
        actions: widget.draftsOnly
            ? null
            : [writeButton(), const SizedBox(width: 8)],
      ),
      body: SafeArea(top: false, child: body),
    );
  }
}

enum _DraftAction { edit, delete }

class _DraftRow extends StatefulWidget {
  const _DraftRow({
    super.key,
    required this.store,
    required this.row,
    required this.busy,
    required this.onOpen,
    required this.onDelete,
  });
  final AppStore store;
  final Map<String, dynamic> row;
  final bool busy;
  final VoidCallback onOpen, onDelete;

  @override
  State<_DraftRow> createState() => _DraftRowState();
}

class _DraftRowState extends State<_DraftRow> {
  // The list endpoint can return metadata only. Fetch text when the row is built.
  late final Future<String> excerpt = _excerpt();

  Future<String> _excerpt() async {
    final row = widget.row;
    if (row.containsKey('content')) return articlePreviewText(row['content']);
    try {
      final detail = await widget.store.request(
        'GetArticlesId',
        path: {'id': '${row['id']}'},
      );
      if (detail.data['id'] == row['id'] && detail.data['status'] == 'DRAFT') {
        return articlePreviewText(detail.data['content']);
      }
    } catch (_) {
      // The title still opens the draft when a preview is unavailable.
    }
    return '';
  }

  Future<void> _showActions() async {
    final draftID = widget.row['id'];
    final title = articleListLabel(widget.row, fallback: '无标题草稿');
    final edited = _time(widget.row['updated_at']);
    final action = await showPanelSheet<_DraftAction>(
      context,
      useRootNavigator: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .5,
        child: PanelSheet(
          header: Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: sheetContext.colors.ink,
                  ),
                ),
                if (edited.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '上次编辑 $edited',
                    style: TextStyle(
                      fontSize: 12,
                      color: sheetContext.colors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          backgroundColor: sheetContext.isDark
              ? null
              : sheetContext.colors.surface,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              PanelGroup(
                outlined: true,
                children: [
                  _DraftActionTile(
                    label: '继续编辑',
                    icon: AppIcons.edit,
                    color: sheetContext.colors.accent,
                    onTap: () => Navigator.pop(sheetContext, _DraftAction.edit),
                  ),
                  _DraftActionTile(
                    key: ValueKey('draft-delete-$draftID'),
                    label: '删除草稿',
                    icon: AppIcons.delete,
                    color: Theme.of(sheetContext).colorScheme.error,
                    destructive: true,
                    onTap: () =>
                        Navigator.pop(sheetContext, _DraftAction.delete),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || widget.busy) return;
    switch (action) {
      case _DraftAction.edit:
        widget.onOpen();
      case _DraftAction.delete:
        widget.onDelete();
      case null:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final title = articleListLabel(widget.row, fallback: '无标题草稿');
    final edited = _time(widget.row['updated_at']);
    return Column(
      children: [
        Material(
          color: colors.surface,
          child: InkWell(
            onTap: widget.busy ? null : widget.onOpen,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colors.ink,
                          ),
                        ),
                        FutureBuilder<String>(
                          future: excerpt,
                          builder: (context, state) {
                            final text = (state.data ?? '')
                                .replaceAll(RegExp(r'\s+'), ' ')
                                .trim();
                            if (text.isEmpty || text == title) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colors.muted,
                                ),
                              ),
                            );
                          },
                        ),
                        if (edited.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '上次编辑 $edited',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.muted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (widget.busy)
                    const SizedBox(
                      width: 48,
                      child: Center(
                        child: SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else
                    IconButton(
                      key: ValueKey('draft-more-${widget.row['id']}'),
                      tooltip: '更多操作',
                      onPressed: _showActions,
                      icon: AppIcon(
                        AppIcons.more,
                        size: 20,
                        color: colors.muted,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Divider(height: 1, color: colors.border),
      ],
    );
  }
}

class _DraftActionTile extends StatelessWidget {
  const _DraftActionTile({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.destructive = false,
  });
  final String label;
  final AppIconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
    horizontalTitleGap: 12,
    minLeadingWidth: 34,
    leading: SizedBox(
      width: 34,
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: AppIcon(icon, size: 20, color: color),
      ),
    ),
    title: Text(
      label,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: destructive ? color : context.colors.ink,
      ),
    ),
    onTap: onTap,
  );
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({
    required this.row,
    required this.busy,
    required this.onTap,
  });
  final Map<String, dynamic> row;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = '${row['status']}';
    final color = _statusColor(context, status);
    final reason = '${row['review_reason'] ?? ''}'.trim();
    final published = status == 'PUBLISHED';
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _statuses[status] ?? status,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (busy)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    AppIcon(
                      AppIcons.forward,
                      size: 18,
                      color: context.colors.muted,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                articleListLabel(row),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (status == 'REJECTED' && reason.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '审核意见：$reason',
                  style: TextStyle(fontSize: 12, height: 1.6, color: color),
                ),
              ],
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(
                '${published
                    ? '发布时间'
                    : status == 'SUBMITTED'
                    ? '提交时间'
                    : '修改时间'}：${_time(published ? row['published_at'] : row['updated_at'])}',
                style: TextStyle(fontSize: 11, color: context.colors.muted),
              ),
              if (published) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: [
                    Text(
                      '${integer(row['like_count'])} 赞',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colors.muted,
                      ),
                    ),
                    Text(
                      '${integer(row['favorite_count'])} 收藏',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colors.muted,
                      ),
                    ),
                    Text(
                      '${integer(row['share_count'])} 分享',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colors.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class OwnArticlePreview extends StatelessWidget {
  const OwnArticlePreview({
    super.key,
    required this.story,
    required this.row,
    this.store,
  });
  final AppStore? store;
  final Story story;
  final Map<String, dynamic> row;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.surface,
    appBar: AppPageBar(
      actions: [
        if (store != null &&
            {'PUBLISHED', 'SUBMITTED', 'REJECTED'}.contains(row['status']))
          ArticleOwnerActions(store: store!, articleID: story.id),
      ],
    ),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            appPageHorizontalPadding,
            16,
            appPageHorizontalPadding,
            40,
          ),
          children: [
            Text(
              _statuses['${row['status']}'] ?? '',
              style: TextStyle(
                color: _statusColor(context, '${row['status']}'),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (story.title.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                story.title,
                style: const TextStyle(
                  fontSize: 24,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if ('${row['review_reason'] ?? ''}'.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${{'DRAFT', 'REJECTED'}.contains(row['status']) ? '审核意见' : '上次审核意见'}：${row['review_reason']}',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (story.hasGuidance)
              Text(
                '${story.content['question'] ?? story.excerpt}',
                style: const TextStyle(fontSize: 15, height: 1.6),
              )
            else
              ArticleRichBody(
                store: store,
                articleID: story.id,
                content: story.content.isEmpty
                    ? richContent(story.paragraphs.join('\n'))
                    : story.content,
              ),
          ],
        ),
      ),
    ),
  );
}
