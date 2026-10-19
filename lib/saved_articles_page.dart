import 'playful_refresh.dart';

import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'app_store.dart';
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
  String query = '';
  String? error, opening;
  bool loading = true;
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

  Future<void> _load() async {
    final request = ++generation;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.store.request(
        'GetMeFavorites',
        query: {'limit': '50'},
      );
      if (mounted && request == generation) {
        setState(() => rows = items(result.data));
      }
    } catch (e) {
      if (mounted && request == generation) setState(() => error = '$e');
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  void _sync(String id, bool saved) {
    for (final story in widget.store.stories) {
      if ('${story.id}' == id) story.saved = saved;
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
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('已取消收藏'),
            action: SnackBarAction(label: '撤销', onPressed: () => _restore(row)),
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
              '${row['title']}'.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    final body = GestureDetector(
      onTap: dismissKeyboard,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: PlayfulRefresh(
            onRefresh: _load,
            hasError: () => error != null,
            child: CustomScrollView(
              key: PageStorageKey(
                widget.embedded ? 'profile-saved' : 'saved-articles',
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (!widget.embedded)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                      child: TextField(
                        key: const ValueKey('saved-search'),
                        controller: search,
                        onChanged: (value) =>
                            setState(() => query = value.trim()),
                        onSubmitted: (_) => dismissKeyboard(),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: '搜索收藏标题',
                          fillColor: context.colors.surface,
                          prefixIcon: Padding(
                            padding: EdgeInsets.all(14),
                            child: AppIcon(
                              AppIcons.search,
                              size: 20,
                              color: context.colors.muted,
                            ),
                          ),
                          suffixIcon: query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: '清空搜索',
                                  onPressed: () {
                                    search.clear();
                                    setState(() => query = '');
                                    dismissKeyboard();
                                  },
                                  icon: AppIcon(
                                    AppIcons.clear,
                                    size: 18,
                                    color: context.colors.muted,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    widget.embedded ? 16 : 0,
                    20,
                    28,
                  ),
                  sliver: SliverList.builder(
                    itemCount: loading || error != null || visible.isEmpty
                        ? 1
                        : visible.length + 1,
                    itemBuilder: (context, index) {
                      if (loading) {
                        return const Padding(
                          padding: EdgeInsets.all(48),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }
                      if (error != null) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Column(
                            children: [
                              AppIcon(
                                AppIcons.refresh,
                                size: 32,
                                color: context.colors.muted,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.colors.muted,
                                ),
                              ),
                              TextButton(
                                onPressed: _load,
                                child: const Text('重新加载'),
                              ),
                            ],
                          ),
                        );
                      }
                      if (visible.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 64),
                          child: Column(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: blue.withValues(alpha: .07),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Center(
                                  child: AppIcon(
                                    AppIcons.bookmark,
                                    size: 28,
                                    color: context.colors.accent,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                query.isEmpty ? '还没有收藏的文章' : '没有找到这篇收藏',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                query.isEmpty
                                    ? '文章中的书签按钮，可以把内容留在这里。'
                                    : '试试其他标题关键词',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.7,
                                  color: context.colors.muted,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      if (index == 0) {
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
                      final row = visible[index - 1];
                      final id = '${row['id']}';
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
    );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(
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
                        '${row['title'] ?? ''}',
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
                        : AppIcon(
                            AppIcons.bookmarked,
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
