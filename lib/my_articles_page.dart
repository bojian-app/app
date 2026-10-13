import 'playful_refresh.dart';

import 'dart:async';

import 'article_rich_content.dart';

import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'app_store.dart';
import 'design.dart';
import 'discovery.dart';
import 'resume_updated_label.dart';

const _statuses = {
  'SUBMITTED': '审核中',
  'PUBLISHED': '已发布',
  'DRAFT': '草稿',
  'REJECTED': '未通过',
};

Color _statusColor(String status) => switch (status) {
  'SUBMITTED' => const Color(0xFFB57920),
  'PUBLISHED' => const Color(0xFF38876F),
  'REJECTED' => const Color(0xFFBD5561),
  _ => muted,
};

String _time(dynamic value) {
  final date = DateTime.tryParse('$value');
  return date == null ? '' : resumeUpdatedLabel(date);
}

class MyArticlesPage extends StatefulWidget {
  const MyArticlesPage({super.key, required this.store});
  final AppStore store;
  @override
  State<MyArticlesPage> createState() => _MyArticlesPageState();
}

class _MyArticlesPageState extends State<MyArticlesPage> {
  String status = 'SUBMITTED', query = '', cursor = '';
  List<Map<String, dynamic>> articles = [];
  bool loading = true, loadingMore = false;
  String? error;
  int generation = 0;
  String? opening;
  StreamSubscription<Map<String, dynamic>>? realtime;
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
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
    final requestedStatus = status;
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
      if (!mounted || generation != requestGeneration) return;
      setState(() {
        final rows = items(response.data);
        articles = more ? [...articles, ...rows] : rows;
        cursor = response.nextCursor;
      });
    } catch (e) {
      if (mounted && generation == requestGeneration) {
        setState(() => error = '$e');
      }
    } finally {
      if (mounted && generation == requestGeneration) {
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
    setState(() => opening = id);
    try {
      final response = await widget.store.request(
        'GetArticlesId',
        path: {'id': id},
      );
      if (!mounted) return;
      final story = decodeStory(response.data);
      await openPage(context, _OwnArticlePreview(story: story, row: row));
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => opening = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = articles
        .where((row) => '${row['title']}'.contains(query))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的文章'),
        actions: [
          TextButton(
            onPressed: () async {
              await openPage(context, StoryComposer(store: widget.store));
              if (mounted) _load();
            },
            child: const Text('写文章'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                  child: TextField(
                    onChanged: (value) => setState(() => query = value.trim()),
                    onSubmitted: (_) => dismissKeyboard(),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: '搜索文章标题',
                      fillColor: Colors.white,
                      prefixIcon: const Padding(
                        padding: EdgeInsets.all(14),
                        child: AppIcon(AppIcons.search, size: 20, color: muted),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDEFF3),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        for (final entry in _statuses.entries)
                          Expanded(
                            child: Semantics(
                              selected: status == entry.key,
                              child: TextButton(
                                key: ValueKey('articles-${entry.key}'),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  minimumSize: const Size(0, 40),
                                  backgroundColor: status == entry.key
                                      ? Colors.white
                                      : Colors.transparent,
                                  foregroundColor: status == entry.key
                                      ? ink
                                      : muted,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  textStyle: TextStyle(
                                    fontSize: 13,
                                    fontWeight: status == entry.key
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
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
                Expanded(
                  child: PlayfulRefresh(
                    onRefresh: _load,
                    hasError: () => error != null,
                    child: ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      children: [
                        if (loading)
                          const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else ...[
                          if (status == 'SUBMITTED' && articles.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.only(left: 2, bottom: 16),
                              child: Text(
                                '审核通过后，文章将公开展示。',
                                style: TextStyle(fontSize: 12, color: muted),
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
                                    style: const TextStyle(
                                      color: muted,
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
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 64),
                              child: Column(
                                children: [
                                  const AppIcon(
                                    AppIcons.article,
                                    size: 36,
                                    color: muted,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    query.isNotEmpty
                                        ? '没有找到这篇文章'
                                        : '暂无${_statuses[status]}的文章',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    query.isNotEmpty
                                        ? '试试其他标题关键词'
                                        : status == 'SUBMITTED'
                                        ? '提交后的文章会显示在这里'
                                        : '下拉刷新，查看最新状态',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          for (final row in visible)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _ArticleCard(
                                row: row,
                                busy: opening == '${row['id']}',
                                onTap: () => _open(row),
                              ),
                            ),
                          if (cursor.isNotEmpty)
                            TextButton(
                              onPressed: loadingMore
                                  ? null
                                  : () => _load(more: true),
                              child: loadingMore
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('加载更多'),
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
    );
  }
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
    final color = _statusColor(status);
    final reason = '${row['review_reason'] ?? ''}'.trim();
    final published = status == 'PUBLISHED';
    return Material(
      color: Colors.white,
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
                    const AppIcon(AppIcons.forward, size: 18, color: muted),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '${row['title'] ?? ''}',
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
                style: const TextStyle(fontSize: 11, color: muted),
              ),
              if (published) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: [
                    Text(
                      '${integer(row['like_count'])} 赞',
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                    Text(
                      '${integer(row['favorite_count'])} 收藏',
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                    Text(
                      '${integer(row['share_count'])} 分享',
                      style: const TextStyle(fontSize: 11, color: muted),
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

class _OwnArticlePreview extends StatelessWidget {
  const _OwnArticlePreview({required this.story, required this.row});
  final Story story;
  final Map<String, dynamic> row;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(backgroundColor: Colors.white),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          children: [
            Text(
              _statuses['${row['status']}'] ?? '',
              style: TextStyle(
                color: _statusColor('${row['status']}'),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              story.title,
              style: const TextStyle(
                fontSize: 24,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            ArticleRichBody(
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
