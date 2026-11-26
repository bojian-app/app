import 'dart:async';

import 'playful_refresh.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_page_bar.dart';
import 'app_store.dart';
import 'design.dart';
import 'discovery.dart';

Future<String?> pickArticleTopic(BuildContext context, AppStore store) async {
  final epoch = store.epoch;
  final name = await openPage<String>(context, _TopicPicker(store: store));
  return epoch == store.epoch && store.alive ? name : null;
}

Future<void> openArticleTopic(
  BuildContext context,
  AppStore store,
  String name,
) async {
  if (name.trim().isEmpty) return;
  await openPage<void>(context, _TopicFeed(store: store, name: name.trim()));
}

class _TopicPicker extends StatefulWidget {
  const _TopicPicker({required this.store});
  final AppStore store;

  @override
  State<_TopicPicker> createState() => _TopicPickerState();
}

class _TopicPickerState extends State<_TopicPicker> {
  late final account = widget.store.epoch;
  final input = TextEditingController();
  final focus = FocusNode();
  Timer? pending;
  String get name => input.text.trim();
  bool get valid => name.isNotEmpty && name.runes.length <= 120;
  int generation = 0;
  bool loading = false, failed = false;
  List<Map<String, dynamic>> options = [];

  void changed(String value) {
    pending?.cancel();
    final request = ++generation;
    final query = value.trim();
    setState(() {
      options = [];
      loading = query.isNotEmpty;
      failed = false;
    });
    if (query.isNotEmpty) {
      pending = Timer(
        const Duration(milliseconds: 220),
        () => search(query, request),
      );
    }
  }

  Future<void> search(String value, int request) async {
    try {
      final result = await widget.store.request(
        'GetArticleTopics',
        query: {'query': value},
        expectedEpoch: account,
      );
      if (!mounted || request != generation || account != widget.store.epoch) {
        return;
      }
      setState(() {
        options = items(result.data);
        loading = false;
        failed = false;
      });
    } catch (_) {
      if (mounted && request == generation) {
        setState(() {
          loading = false;
          failed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    pending?.cancel();
    focus.dispose();
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: const AppPageBar(leading: CloseButton()),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: appPageHorizontalPadding,
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => focus.requestFocus(),
                child: Row(
                  children: [
                    const Text('#'),
                    Flexible(
                      child: IntrinsicWidth(
                        child: TextField(
                          controller: input,
                          autofocus: true,
                          focusNode: focus,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                            isDense: true,
                            constraints: BoxConstraints(minWidth: 3),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.deny(
                              RegExp(r'[#\x00-\x1f\x7f-\x9f]'),
                            ),
                            LengthLimitingTextInputFormatter(120),
                          ],
                          onChanged: changed,
                          onSubmitted: (_) {
                            if (valid) Navigator.pop(context, name);
                          },
                        ),
                      ),
                    ),
                    const Text('#'),
                  ],
                ),
              ),
            ),
            const Divider(
              height: 1,
              indent: appPageHorizontalPadding,
              endIndent: appPageHorizontalPadding,
            ),
            Expanded(
              child: LoadingGate(
                loading: loading,
                builder: (_) => loading
                    ? const DotMatrixLoader()
                    : failed
                    ? Center(
                        child: TextButton(
                          onPressed: () => changed(name),
                          child: const Text('加载失败，点击重试'),
                        ),
                      )
                    : ListView.builder(
                        itemCount: options.length,
                        itemBuilder: (context, i) {
                          final item = options[i];
                          final topic = item['name'] as String;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: appPageHorizontalPadding,
                            ),
                            title: Text('#$topic#'),
                            trailing: Text(
                              '${integer(item['article_count'])} 条动态',
                              style: TextStyle(color: colors.muted),
                            ),
                            onTap: () => Navigator.pop(context, topic),
                          );
                        },
                      ),
              ),
            ),
            const Divider(
              height: 1,
              indent: appPageHorizontalPadding,
              endIndent: appPageHorizontalPadding,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: appPageHorizontalPadding),
                child: TextButton(
                  onPressed: valid ? () => Navigator.pop(context, name) : null,
                  child: const Text('完成'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicFeed extends StatefulWidget {
  const _TopicFeed({required this.store, required this.name});
  final AppStore store;
  final String name;
  @override
  State<_TopicFeed> createState() => _TopicFeedState();
}

class _TopicFeedState extends State<_TopicFeed> {
  late final account = widget.store.epoch;
  List<Story> stories = [];
  bool loading = false, failed = false;
  String cursor = '';
  int generation = 0;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(accountChanged);
    load();
  }

  void accountChanged() {
    if (account != widget.store.epoch && (stories.isNotEmpty || loading)) {
      generation++;
      setState(() {
        stories = [];
        cursor = '';
        loading = false;
        failed = true;
      });
    }
  }

  Future<void> load({bool more = false}) async {
    if (account != widget.store.epoch || more && (loading || cursor.isEmpty)) {
      return;
    }
    final request = ++generation;
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      final result = await widget.store.request(
        'GetFeed',
        query: {
          'topic': widget.name,
          'limit': '20',
          if (more) 'cursor': cursor,
        },
        expectedEpoch: account,
      );
      if (!mounted || generation != request || account != widget.store.epoch) {
        return;
      }
      final page = items(result.data).map(decodeStory);
      setState(() {
        if (!more) stories = [];
        final seen = stories.map((s) => s.id).toSet();
        stories.addAll(page.where((s) => seen.add(s.id)));
        cursor = result.nextCursor;
      });
    } catch (_) {
      if (mounted && generation == request) setState(() => failed = true);
    } finally {
      if (mounted && generation == request) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(accountChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppPageBar(title: Text('#${widget.name}#')),
    body: SafeArea(
      top: false,
      child: PlayfulRefresh(
        onRefresh: load,
        child: AutoPaginate(
          canLoad: !loading && !failed && cursor.isNotEmpty,
          onLoadMore: () => load(more: true),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: stories.length + 1,
            itemBuilder: (context, index) {
              if (index < stories.length) {
                return FeedRow(
                  child: StoryCard(
                    store: widget.store,
                    story: stories[index],
                    flat: true,
                    compactTypography: true,
                  ),
                );
              }
              if (loading) return const PageLoadingFooter(visible: true);
              if (failed) {
                return Center(
                  child: TextButton(
                    onPressed: () =>
                        load(more: stories.isNotEmpty && cursor.isNotEmpty),
                    child: const Text('加载失败，点击重试'),
                  ),
                );
              }
              if (stories.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('暂无公开动态')),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    ),
  );
}
