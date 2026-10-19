import 'user_display_name.dart';

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_store.dart';
import 'design.dart';
import 'app_icons.dart';
import 'profile_avatar.dart';
import 'resume_updated_label.dart';
import 'resume_guidance_review.dart';

String guidanceFieldText(Map snapshot, String path) {
  dynamic value = snapshot;
  for (final part in path.split('.')) {
    if (value is Map) {
      value = value[part];
    } else if (value is List) {
      final index = int.tryParse(part);
      if (index == null || index < 0 || index >= value.length) return '';
      value = value[index];
    } else {
      return '';
    }
  }
  return value is String ? value : '';
}

String annotationMethod(
  bool notification,
  String verb, {
  bool decision = false,
}) =>
    '$verb${notification ? 'Notifications' : 'Articles'}IdGuidanceAnnotations${decision ? 'AnnotationIdDecision' : ''}';

Future<bool?> composeGuidanceAnnotation(
  BuildContext context, {
  required AppStore store,
  required int id,
  required bool notification,
  required Map snapshot,
  required String fieldPath,
  required String selectedText,
  required bool replace,
}) {
  final original = guidanceFieldText(snapshot, fieldPath);
  final selected = selectedText.trim();
  if (selected.isEmpty ||
      !original.contains(selected) ||
      original.indexOf(selected) != original.lastIndexOf(selected)) {
    toast(context, '该区域暂时无法准确定位，请刷新简历后重试');
    return Future.value(false);
  }
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AnnotationComposer(
      store: store,
      id: id,
      notification: notification,
      fieldPath: fieldPath,
      original: original,
      selected: selected,
      replace: replace,
    ),
  );
}

class _AnnotationComposer extends StatefulWidget {
  const _AnnotationComposer({
    required this.store,
    required this.id,
    required this.notification,
    required this.fieldPath,
    required this.original,
    required this.selected,
    required this.replace,
  });
  final AppStore store;
  final int id;
  final bool notification, replace;
  final String fieldPath, original, selected;
  @override
  State<_AnnotationComposer> createState() => _AnnotationComposerState();
}

class _AnnotationComposerState extends State<_AnnotationComposer> {
  final text = TextEditingController();
  final inputFocus = FocusNode();
  final inputKey = GlobalKey();
  double lastKeyboardInset = -1;
  bool sending = false;
  String? payload, key;
  @override
  void initState() {
    super.initState();
    if (widget.replace) text.text = widget.selected;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    if (inset != lastKeyboardInset) {
      lastKeyboardInset = inset;
      if (inset > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final field = inputKey.currentContext;
          if (mounted && inputFocus.hasFocus && field != null) {
            Scrollable.ensureVisible(field, alignment: 1);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    inputFocus.dispose();
    text.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (sending || text.text.trim().isEmpty) return;
    final body = <String, dynamic>{
      'field_path': widget.fieldPath,
      'field_value': widget.original,
      'selected_text': widget.selected,
      'suggestion': widget.replace ? '' : text.text.trim(),
      'replacement': widget.replace ? text.text.trim() : '',
    };
    final next = jsonEncode(body);
    if (next != payload) {
      payload = next;
      key = 'annotation-${widget.id}-${DateTime.now().microsecondsSinceEpoch}';
    }
    setState(() => sending = true);
    final sent = await runRequest(
      context,
      () => widget.store.request(
        annotationMethod(widget.notification, 'Post'),
        path: {'id': '${widget.id}'},
        body: body,
        extra: {'idempotency-key': key!},
      ),
    );
    if (!mounted) return;
    if (sent) {
      Navigator.pop(context, true);
    } else {
      setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !sending,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final lineHeight = MediaQuery.textScalerOf(context).scale(16) * 1.5;
            final lines = ((constraints.maxHeight - 160) / lineHeight)
                .floor()
                .clamp(2, 6);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.replace ? '替换内容' : '评论这段内容',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (!widget.replace) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: context.colors.canvas,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: math.min(
                                  100,
                                  constraints.maxHeight * .22,
                                ),
                              ),
                              child: SingleChildScrollView(
                                child: Text(
                                  widget.selected,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                    color: context.colors.muted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        KeyedSubtree(
                          key: const ValueKey('tour-rewrite-input'),
                          child: TextField(
                            key: inputKey,
                            controller: text,
                            focusNode: inputFocus,
                            enabled: !sending,
                            autofocus: false,
                            minLines: 2,
                            maxLines: lines,
                            scrollPadding: const EdgeInsets.all(12),
                            maxLength: widget.replace ? 20000 : 10000,
                            decoration: InputDecoration(
                              hintText: widget.replace ? '填写建议替换的内容' : '写下你的评论',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.replace) ...[
                        Text(
                          '改写内容仅你和作者可见。',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.muted,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: const ValueKey('annotation-submit'),
                          onPressed: sending ? null : submit,
                          child: Text(
                            sending
                                ? '正在发送…'
                                : widget.replace
                                ? '提交替换建议'
                                : '发送评论',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class GuidanceAnnotations extends StatefulWidget {
  const GuidanceAnnotations({
    super.key,
    required this.store,
    required this.id,
    required this.notification,
    required this.owner,
    required this.onChanged,
    this.reviewerKey,
    this.recordKeys,
    this.initialItems,
    this.legacyItems = const [],
    this.currentSnapshot,
    this.mineOnly = false,
  });
  final AppStore store;
  final int id;
  final bool notification, owner;
  final bool mineOnly;
  final VoidCallback onChanged;
  final String? reviewerKey;
  final Set<String>? recordKeys;
  final List<Map<String, dynamic>>? initialItems;
  final List<Map<String, dynamic>> legacyItems;
  final Map? currentSnapshot;
  @override
  State<GuidanceAnnotations> createState() => _GuidanceAnnotationsState();
}

class _GuidanceAnnotationsState extends State<GuidanceAnnotations> {
  List<Map<String, dynamic>>? items;
  String? error;
  int? busy;
  @override
  void initState() {
    super.initState();
    items = widget.initialItems;
    load();
  }

  Future<void> load() async {
    try {
      final result = await widget.store.request(
        annotationMethod(widget.notification, 'Get'),
        path: {'id': '${widget.id}'},
      );
      var legacy = widget.legacyItems;
      if (widget.mineOnly) {
        final detail = await widget.store.request(
          widget.notification
              ? 'GetNotificationsIdGuidance'
              : 'GetArticlesIdGuidance',
          path: {'id': '${widget.id}'},
        );
        legacy = guidanceRecords([], detail.data['suggestions'] as List? ?? []);
      }
      if (mounted) {
        setState(() {
          items =
              [
                    ...(result.data['items'] as List? ?? [])
                        .whereType<Map>()
                        .map((v) => Map<String, dynamic>.from(v)),
                    ...legacy,
                  ]
                  .where(
                    (v) =>
                        (!widget.mineOnly ||
                            (widget.store.userID > 0 &&
                                integer(v['reviewer_id']) ==
                                    widget.store.userID)) &&
                        (widget.reviewerKey == null ||
                            guidanceReviewerKey(v) == widget.reviewerKey) &&
                        (widget.recordKeys == null ||
                            widget.recordKeys!.contains(guidanceRecordKey(v))),
                  )
                  .toList();
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> decide(Map<String, dynamic> item, bool accept) async {
    if (busy != null) return;
    setState(() => busy = integer(item['id']));
    final sent = await runRequest(
      context,
      () => widget.store.request(
        annotationMethod(widget.notification, 'Post', decision: true),
        path: {'id': '${widget.id}', 'annotation_id': '${item['id']}'},
        body: {'status': accept ? 'ACCEPTED' : 'REJECTED'},
      ),
    );
    if (!mounted) return;
    setState(() => busy = null);
    if (sent) {
      widget.onChanged();
      if (accept) await widget.store.load('resumes');
      await load();
      if (accept && mounted) toast(context, '已生成新的简历，原简历已保留');
    }
  }

  Widget contentBlock(String label, String text, {Color? color}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
    decoration: BoxDecoration(
      color: color?.withValues(alpha: .12) ?? context.colors.canvas,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color == null
                ? context.colors.muted
                : const Color(0xFF7A63AC),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            height: 1.6,
            color: color == null
                ? (context.isDark
                      ? context.colors.muted
                      : const Color(0xFF677183))
                : context.colors.ink,
          ),
        ),
      ],
    ),
  );

  Widget recordCard(Map<String, dynamic> item) {
    final replacement = '${item['replacement'] ?? ''}';
    final advice = '${item['suggestion'] ?? ''}';
    final quote = '${item['selected_text'] ?? ''}';
    final status = '${item['status'] ?? 'PENDING'}';
    final isReplacement = replacement.isNotEmpty;
    final color = isReplacement
        ? guidanceReplacementColor
        : guidanceCommentColor;
    final changed =
        status != 'ACCEPTED' &&
        widget.currentSnapshot != null &&
        quote.isNotEmpty &&
        !guidanceFieldText(
          widget.currentSnapshot!,
          '${item['field_path']}',
        ).contains(quote);
    final updated = DateTime.tryParse(
      '${item['created_at'] ?? item['updated_at'] ?? ''}',
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProfileAvatar(
                seed: '${item['reviewer_id'] ?? guidanceReviewerKey(item)}',
                url: '${item['reviewer_avatar_url'] ?? ''}',
                size: 32,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userDisplayName(item['reviewer_name']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (updated != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        resumeUpdatedLabel(updated),
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isReplacement ? '改写' : '评论',
                  style: TextStyle(
                    fontSize: 11,
                    color: isReplacement
                        ? const Color(0xFF7A63AC)
                        : const Color(0xFF408C77),
                  ),
                ),
              ),
            ],
          ),
          if (quote.isNotEmpty) ...[
            const SizedBox(height: 14),
            contentBlock('原文', quote),
          ],
          if (isReplacement) ...[
            const SizedBox(height: 8),
            contentBlock('建议替换为', replacement, color: guidanceReplacementColor),
          ],
          if (advice.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(advice, style: const TextStyle(fontSize: 13, height: 1.6)),
          ],
          if (changed) ...[
            const SizedBox(height: 10),
            Text(
              '原文已变化，色块标记的是对应栏目。',
              style: TextStyle(
                fontSize: 11,
                color: context.colors.muted,
                height: 1.5,
              ),
            ),
          ],
          if (isReplacement) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 6),
            if (item['legacy'] == true)
              Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  '早期建议，可在简历编辑页中调整。',
                  style: TextStyle(fontSize: 12, color: context.colors.muted),
                ),
              )
            else if (status != 'PENDING')
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    if (status == 'ACCEPTED') ...[
                      const AppIcon(
                        AppIcons.confirm,
                        size: 16,
                        color: Color(0xFF408C77),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      status == 'ACCEPTED' ? '作者已采纳' : '作者未采纳',
                      style: TextStyle(
                        fontSize: 12,
                        color: status == 'ACCEPTED'
                            ? const Color(0xFF408C77)
                            : context.colors.muted,
                      ),
                    ),
                  ],
                ),
              )
            else if (widget.owner)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: busy == null ? () => decide(item, false) : null,
                    style: TextButton.styleFrom(
                      foregroundColor: context.colors.muted,
                      minimumSize: const Size(64, 40),
                    ).withoutHover(),
                    child: const Text('不采纳'),
                  ),
                  const SizedBox(width: 18),
                  TextButton(
                    onPressed: busy == null ? () => decide(item, true) : null,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(64, 40),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ).withoutHover(),
                    child: busy == integer(item['id'])
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('采纳'),
                  ),
                ],
              )
            else
              Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  '等待作者确认',
                  style: TextStyle(fontSize: 12, color: context.colors.muted),
                ),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.canvas,
    appBar: AppBar(title: Text(widget.mineOnly ? '我的优化建议' : '指点记录')),
    body: SafeArea(
      top: false,
      child: error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error!, textAlign: TextAlign.center),
                  TextButton(onPressed: load, child: const Text('重新加载')),
                ],
              ),
            )
          : items == null
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : RefreshIndicator(
              onRefresh: load,
              child: items!.isEmpty
                  ? LayoutBuilder(
                      builder: (context, constraints) => ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: constraints.maxHeight,
                            child: Center(
                              child: Text(
                                '还没有指点记录',
                                style: TextStyle(
                                  color: context.colors.muted,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: items!.length,
                      separatorBuilder: (_, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (_, index) => recordCard(items![index]),
                    ),
            ),
    ),
  );
}
