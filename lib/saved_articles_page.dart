import 'app_page_bar.dart';
import 'playful_refresh.dart';

import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'app_store.dart';
import 'api/bojian_api.dart';
import 'app_search_field.dart';
import 'design.dart';
import 'discovery.dart';
import 'resume_updated_label.dart';

class SavedArticlesPage extends StatefulWidget {
  const SavedArticlesPage({
    super.key,
    required this.store,
    this.embedded = false,
  });
  final AppStore store;
  final bool embedded;
  @override
  State<SavedArticlesPage> createState() => _SavedArticlesPageState();
}

class _SavedArticlesPageState extends State<SavedArticlesPage> {
  final search = TextEditingController();
  List<Map<String, dynamic>> rows = [];
  final feedStories = <int, Story>{};
  String query = '';
  String? error, moreError, opening;
  String cursor = '';
  bool loading = true, loadingMore = false;
  final busy = <String>{};
  int generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (more && (cursor.isEmpty || loadingMore || loading)) return;
    final request = more ? generation : ++generation;
    setState(() {
      if (more) {
        loadingMore = true;
        moreError = null;
      } else {
        loading = true;
        error = null;
      }
    });
    try {
      final result = await widget.store.request(
        'GetMeFavorites',
        query: {'limit': '30', if (more) 'cursor': cursor},
      );
      if (mounted && request == generation) {
        final page = items(result.data);
        final loaded = <int, Story>{};
        final details = widget.embedded
            ? page
            : page
                  .where(
                    (row) =>
                        '${row['title'] ?? ''}'.trim().isEmpty &&
                        !row.containsKey('content'),
                  )
                  .toList();
        if (details.isNotEmpty || widget.embedded) {
          final session = widget.store.epoch;
          for (var start = 0; start < details.length; start += 4) {
            final stories = await Future.wait(
              details.skip(start).take(4).map((row) async {
                final id = integer(row['id']);
                try {
                  final result = await widget.store.request(
                    'GetArticlesId',
                    path: {'id': '$id'},
                    expectedEpoch: session,
                  );
                  if (result.data['content'] != null)
                    row['content'] = result.data['content'];
                  return decodeStory({
                    ...row,
                    'is_favorited': true,
                    ...result.data,
                  });
                } on ApiFailure catch (e) {
                  if (e.code == 'ARTICLE_NOT_FOUND' || e.code == 'NOT_FOUND')
                    return null;
                  rethrow;
                }
              }),
            );
            if (!mounted ||
                session != widget.store.epoch ||
                request != generation)
              return;
            for (final story in stories.whereType<Story>()) {
              if (story.saved) loaded[story.id] = story;
            }
          }
          if (!more) feedStories.clear();
          feedStories.addAll(loaded);
        }
        setState(() {
          rows = [
            if (more) ...rows,
            ...page
                .where(
                  (row) =>
                      !widget.embedded ||
                      loaded.containsKey(integer(row['id'])),
                )
                .where(
                  (row) => !more || !rows.any((v) => v['id'] == row['id']),
                ),
          ];
          cursor = result.nextCursor;
        });
      }
    } catch (e) {
      if (mounted && request == generation) {
        setState(() => more ? moreError = '$e' : error = '$e');
      }
    } finally {
      if (mounted && request == generation) {
        setState(() => more ? loadingMore = false : loading = false);
      }
    }
  }

  void _sync(String id, bool saved) {
    for (final story in widget.store.stories) {
      if ('${story.id}' == id) story.setBookmark(saved);
    }
    widget.store.changed();
  }

  Future<void> _remove(Map<String, dynamic> row) async {
    final id = '${row['id']}';
    if (busy.contains(id)) return;
    setState(() => busy.add(id));
    try {
      await widget.store.request(
        'DeleteArticlesIdFavorite',
        path: {'id': id},
        body: {},
      );
      _sync(id, false);
      if (!mounted) return;
      // Invalidate any older refresh so it cannot restore a removed item.
      ++generation;
      setState(() {
        rows.removeWhere((value) => '${value['id']}' == id);
        loading = false;
        loadingMore = false;
      });
      toast(
        context,
        '已取消收藏',
        success: true,
        action: SnackBarAction(
          label: '撤销',
          textColor: context.colors.accent,
          onPressed: () => _restore(row),
        ),
      );
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => busy.remove(id));
    }
  }

  Future<void> _restore(Map<String, dynamic> row) async {
    final id = '${row['id']}';
    if (busy.contains(id)) return;
    setState(() => busy.add(id));
    try {
      await widget.store.request(
        'PutArticlesIdFavorite',
        path: {'id': id},
        body: {},
      );
      _sync(id, true);
      if (mounted) await _load();
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => busy.remove(id));
    }
  }

  Future<void> _open(Map<String, dynamic> row) async {
    final id = '${row['id']}';
    if (opening != null || busy.contains(id)) return;
    setState(() => opening = id);
    try {
      final response = await widget.store.request(
        'GetArticlesId',
        path: {'id': id},
      );
      if (!mounted) return;
      final story = decodeStory(response.data);
      await openPage(context, StoryDetail(story: story, store: widget.store));
      if (!mounted) return;
      _sync(id, story.saved);
      if (!story.saved) {
        setState(() => rows.removeWhere((row) => '${row['id']}' == id));
      }
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => opening = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = rows
        .where(
          (row) =>
              articleListLabel(row).toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    final body = GestureDetector(
      onTap: dismissKeyboard,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: widget.embedded ? double.infinity : 680,
          ),
          child: AutoPaginate(
            canLoad:
                cursor.isNotEmpty &&
                !loading &&
                !loadingMore &&
                error == null &&
                moreError == null,
            onLoadMore: () => _load(more: true),
            child: PlayfulRefresh(
              onRefresh: _load,
              hasError: () => error != null,
              child: CustomScrollView(
                key: PageStorageKey(
                  widget.embedded ? 'profile-saved' : 'saved-articles',
                ),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (!widget.embedded)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          appPageHorizontalPadding,
                          16,
                          appPageHorizontalPadding,
                          18,
                        ),
                        child: AppSearchField(
                          fieldKey: const ValueKey('saved-search'),
                          controller: search,
                          hintText: '搜索收藏标题',
                          fillColor: context.colors.surface,
                          onChanged: (value) => setState(() => query = value),
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: widget.embedded
                        // Clears the home shell's floating tab bar.
                        ? EdgeInsets.only(
                            bottom: 28 + MediaQuery.paddingOf(context).bottom,
                          )
                        : const EdgeInsets.fromLTRB(
                            appPageHorizontalPadding,
                            0,
                            appPageHorizontalPadding,
                            28,
                          ),
                    sliver: SliverList.builder(
                      itemCount: loading || error != null || visible.isEmpty
                          ? 1
                          : visible.length + (widget.embedded ? 1 : 2),
                      itemBuilder: (context, index) {
                        if (loading) {
                          return const ListSkeleton(count: 4);
                        }
                        if (error != null) {
                          return EmptyState.failed(error!, onRetry: _load);
                        }
                        if (visible.isEmpty) {
                          return EmptyState(
                            query.isEmpty ? '还没有收藏的文章' : '没有找到这篇收藏',
                            query.isEmpty ? '文章中的书签按钮，可以把内容留在这里。' : '试试其他标题关键词',
                            art: query.isEmpty
                                ? EmptyArt.saved
                                : EmptyArt.search,
                          );
                        }
                        if (!widget.embedded && index == 0) {
                          return Padding(
                            padding: EdgeInsets.fromLTRB(2, 0, 2, 14),
                            child: Text(
                              '最近收藏',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: context.colors.muted,
                              ),
                            ),
                          );
                        }
                        final rowIndex = widget.embedded ? index : index - 1;
                        if (rowIndex >= visible.length) {
                          return moreError == null
                              ? PageLoadingFooter(visible: loadingMore)
                              : TextButton(
                                  onPressed: () => _load(more: true),
                                  child: const Text('加载失败，点击重试'),
                                );
                        }
                        final row = visible[rowIndex];
                        final id = '${row['id']}';
                        if (widget.embedded) {
                          final story = feedStories[integer(row['id'])]!;
                          return FeedRow(
                            child: ListenableBuilder(
                              listenable: widget.store,
                              builder: (context, _) => Stack(
                                children: [
                                  StoryCard(
                                    key: ValueKey('saved-story-$id'),
                                    story: story,
                                    store: widget.store,
                                    flat: true,
                                    compactTypography: true,
                                    onBookmark: () => _remove(row),
                                    onDetailClosed: () {
                                      if (!mounted || story.saved) return;
                                      ++generation;
                                      setState(() {
                                        rows.removeWhere(
                                          (r) => r['id'] == row['id'],
                                        );
                                        loading = false;
                                        loadingMore = false;
                                      });
                                    },
                                  ),
                                  if (story.hasGuidance)
                                    Positioned(
                                      right: feedContentPadding,
                                      bottom: 0,
                                      child: IconButton(
                                        tooltip: '取消收藏',
                                        onPressed: busy.contains(id)
                                            ? null
                                            : () => _remove(row),
                                        icon: AppIcon(
                                          AppIcons.bookmarked,
                                          size: 18,
                                          color: const Color(0xFFCA963A),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _SavedCard(
                            row: row,
                            removing: busy.contains(id),
                            opening: opening == id,
                            onOpen: () => _open(row),
                            onRemove: () => _remove(row),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppPageBar(
        title: const Text('我的收藏'),
        actions: const [DismissKeyboardButton(), SizedBox(width: 8)],
      ),
      body: SafeArea(top: false, child: body),
    );
  }
}

class _SavedCard extends StatelessWidget {
  const _SavedCard({
    required this.row,
    required this.removing,
    required this.opening,
    required this.onOpen,
    required this.onRemove,
  });
  final Map<String, dynamic> row;
  final bool removing, opening;
  final VoidCallback onOpen, onRemove;
  @override
  Widget build(BuildContext context) {
    final collected = DateTime.tryParse('${row['collected_at']}');
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: removing || opening ? null : onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 12, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        articleListLabel(row),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          height: 1.55,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    key: ValueKey('saved-remove-${row['id']}'),
                    tooltip: '取消收藏',
                    onPressed: removing || opening ? null : onRemove,
                    icon: removing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.star_rounded,
                            size: 21,
                            color: context.colors.accent,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      collected == null
                          ? '已收藏'
                          : '收藏于 ${resumeUpdatedLabel(collected)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colors.muted,
                      ),
                    ),
                  ),
                  if (opening)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Text(
                      '阅读全文',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(width: 6),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
