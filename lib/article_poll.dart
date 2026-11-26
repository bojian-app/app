import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import 'app_page_bar.dart';
import 'app_store.dart';
import 'confirmation_dialog.dart';
import 'design.dart';

Future<Map<String, dynamic>?> openArticlePollComposer(
  BuildContext context,
  AppStore store,
) => openPage<Map<String, dynamic>>(context, _PollComposer(store: store));

class _PollComposer extends StatefulWidget {
  const _PollComposer({required this.store});
  final AppStore store;
  @override
  State<_PollComposer> createState() => _PollComposerState();
}

class _PollComposerState extends State<_PollComposer> {
  final pollTitle = TextEditingController();
  final questionTitle = TextEditingController();
  final answer = TextEditingController();
  final options = [TextEditingController(), TextEditingController()];
  final correct = <TextEditingController>{};
  late final account = widget.store.epoch;
  bool question = false, multiple = false, quiz = false, dirty = false;
  bool saving = false, leaving = false;
  int limit = 2;
  String deadline = '一周';
  DateTime? picked;
  String? lastData, requestKey;
  DateTime? requestDeadline;

  @override
  void dispose() {
    for (final c in [pollTitle, questionTitle, answer, ...options]) {
      c.dispose();
    }
    super.dispose();
  }

  void change(VoidCallback update) => setState(() {
    dirty = true;
    update();
  });

  void markEdited(String _) {
    if (!dirty) setState(() => dirty = true);
  }

  Future<void> close() async {
    if (saving || leaving) return;
    if (dirty &&
        await showAppConfirmation(
              context,
              title: '确定退出编辑吗？',
              cancelLabel: '继续编辑',
              confirmLabel: '退出',
            ) !=
            true) {
      return;
    }
    if (!mounted) return;
    setState(() => leaving = true);
    Navigator.of(context).pop();
  }

  Future<void> pickMultiple() async {
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('多选类型'),
        children: [
          for (var n = 2; n <= options.length; n++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, n),
              child: Text('最多选$n项'),
            ),
        ],
      ),
    );
    if (result != null && mounted) {
      change(() {
        multiple = true;
        limit = result;
        if (correct.length > limit) correct.clear();
      });
    }
  }

  Future<void> customDate() async {
    final now = DateTime.now();
    final end = picked?.isAfter(now) == true
        ? picked!
        : now.add(const Duration(days: 1));
    final day = await showDatePicker(
      context: context,
      firstDate: DateUtils.dateOnly(now),
      lastDate: DateTime(9999, 12, 31),
      initialDate: end,
    );
    if (day == null || !mounted) return;
    final clock = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(end),
    );
    if (clock == null || !mounted) return;
    final selected = DateTime(
      day.year,
      day.month,
      day.day,
      clock.hour,
      clock.minute,
    );
    if (!selected.isAfter(DateTime.now())) {
      toast(context, '结束时间须晚于现在');
      return;
    }
    change(() {
      picked = selected;
      deadline = '自定义';
    });
  }

  Future<void> save() async {
    if (saving) return;
    final title = (question ? questionTitle : pollTitle).text.trim();
    final values = [for (final c in options) c.text.trim()];
    if (title.isEmpty) {
      toast(context, question ? '请填写问答标题' : '请填写投票标题');
      return;
    }
    if (question && answer.text.trim().isEmpty) {
      toast(context, '请输入正确答案');
      return;
    }
    if (!question && values.any((v) => v.isEmpty)) {
      toast(context, '请填全投票选项');
      return;
    }
    if (!question && quiz && correct.isEmpty) {
      toast(context, '请选择正确答案');
      return;
    }
    final payload = <String, dynamic>{
      'title': title,
      'mode': question ? 'question' : 'poll',
      if (question) 'answer': answer.text,
      if (!question) ...{
        'options': values,
        'multiple': multiple,
        if (multiple) 'max_selections': limit,
        if (quiz)
          'correct_options': [
            for (var i = 0; i < options.length; i++)
              if (correct.contains(options[i])) i,
          ],
      },
    };
    final data = jsonEncode([
      payload,
      deadline,
      if (deadline == '自定义') picked?.toIso8601String(),
    ]);
    if (lastData != data) {
      lastData = data;
      requestKey =
          '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
      requestDeadline = switch (deadline) {
        '一天' => DateTime.now().add(const Duration(days: 1)),
        '一周' => DateTime.now().add(const Duration(days: 7)),
        '自定义' => picked,
        _ => null,
      };
    }
    setState(() => saving = true);
    try {
      final response = await widget.store.request(
        'PostArticlePolls',
        body: {
          ...payload,
          'request_key': requestKey,
          if (requestDeadline != null)
            'ends_at': requestDeadline!.toUtc().toIso8601String(),
        },
        expectedEpoch: account,
      );
      if (!mounted) return;
      if (response.data['kind'] != 'poll' ||
          integer(response.data['poll_id']) <= 0) {
        throw const FormatException('投票保存结果无效');
      }
      setState(() => leaving = true);
      Navigator.of(context).pop(response.data);
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        await showRequestFailure(context, e);
      }
    }
  }

  Widget chip(String label, bool selected, VoidCallback action) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => action(),
    showCheckmark: false,
  );

  void removeOption(TextEditingController option) {
    change(() {
      options.remove(option);
      correct.remove(option);
      limit = min(limit, options.length);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => option.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final type = question ? '问答' : '投票';
    return PopScope(
      canPop: leaving || !saving && !dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) close();
      },
      child: Scaffold(
        appBar: AppPageBar(
          // The theme's text buttons have no side padding, so inset them to the gutter.
          leadingWidth: appPageHorizontalPadding + 64,
          leading: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: appPageHorizontalPadding),
              child: TextButton(
                onPressed: saving ? null : close,
                child: const Text('取消'),
              ),
            ),
          ),
          titleSpacing: 0,
          title: Text('发起$type'),
          actionsPadding: const EdgeInsetsDirectional.only(
            end: appPageHorizontalPadding,
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : save,
              child: Text(saving ? '保存中…' : '完成'),
            ),
          ],
        ),
        body: SafeArea(
          child: IgnorePointer(
            ignoring: saving,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                appPageHorizontalPadding,
                8,
                appPageHorizontalPadding,
                24,
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    chip(
                      '投票',
                      !question,
                      () => setState(() => question = false),
                    ),
                    chip('问答', question, () => setState(() => question = true)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: question ? questionTitle : pollTitle,
                  onChanged: markEdited,
                  decoration: InputDecoration(hintText: '$type标题'),
                ),
                const SizedBox(height: 12),
                if (question)
                  TextField(
                    controller: answer,
                    maxLength: 50,
                    minLines: 2,
                    maxLines: 4,
                    onChanged: markEdited,
                    decoration: const InputDecoration(
                      hintText: '请输入正确答案',
                      helperText: '答题者需输入完全匹配的答案，才算回答正确',
                    ),
                  )
                else ...[
                  for (var i = 0; i < options.length; i++)
                    Padding(
                      key: ObjectKey(options[i]),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          if (quiz)
                            Checkbox(
                              value: correct.contains(options[i]),
                              semanticLabel: '选项${i + 1}正确',
                              onChanged: (v) {
                                if (v == true &&
                                    multiple &&
                                    correct.length >= limit) {
                                  toast(context, '最多选$limit项');
                                  return;
                                }
                                change(() {
                                  if (!multiple) correct.clear();
                                  if (v == true) {
                                    correct.add(options[i]);
                                  } else {
                                    correct.remove(options[i]);
                                  }
                                });
                              },
                            ),
                          Expanded(
                            child: TextField(
                              controller: options[i],
                              onChanged: markEdited,
                              decoration: InputDecoration(
                                hintText: '选项 ${i + 1}',
                              ),
                            ),
                          ),
                          if (options.length > 2)
                            IconButton(
                              tooltip: '删除选项 ${i + 1}',
                              onPressed: () => removeOption(options[i]),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                        ],
                      ),
                    ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('添加选项'),
                    onPressed: () =>
                        change(() => options.add(TextEditingController())),
                  ),
                  const Divider(height: 28),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: quiz,
                    title: const Text('设置正确答案'),
                    onChanged: (v) => change(() => quiz = v == true),
                  ),
                  const Text('选择方式'),
                  Wrap(
                    spacing: 8,
                    children: [
                      chip(
                        '单选',
                        !multiple,
                        () => change(() {
                          multiple = false;
                          if (correct.length > 1) correct.clear();
                        }),
                      ),
                      chip(
                        multiple ? '最多选$limit项' : '多选',
                        multiple,
                        pickMultiple,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                const Text('结束时间'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final d in ['一天', '一周', '从不', '自定义'])
                      chip(
                        d,
                        deadline == d,
                        () => d == '自定义'
                            ? customDate()
                            : change(() => deadline = d),
                      ),
                  ],
                ),
                if (deadline == '自定义' && picked != null)
                  Text(
                    '${MaterialLocalizations.of(context).formatFullDate(picked!)} ${TimeOfDay.fromDateTime(picked!).format(context)}',
                  ),
                const SizedBox(height: 16),
                Text(
                  '保存提示：$type一旦保存不可再修改',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ArticlePollCard extends StatefulWidget {
  const ArticlePollCard({
    super.key,
    required this.block,
    this.store,
    this.articleID,
    this.embedded = false,
  });

  /// Inside another card that already shows the title: only the options,
  /// vote button and results, without the poll's own panel.
  final bool embedded;
  final Map block;
  final AppStore? store;
  final int? articleID;
  @override
  State<ArticlePollCard> createState() => _ArticlePollCardState();
}

class _ArticlePollCardState extends State<ArticlePollCard> {
  final answer = TextEditingController();
  final selected = <int>{};
  Map<String, dynamic>? state;
  String? error;
  bool busy = false;
  int serial = 0;
  int get pollID => integer(widget.block['poll_id']);
  bool get interactive =>
      widget.store?.isAuthenticated == true &&
      (widget.articleID ?? 0) > 0 &&
      pollID > 0;
  Map<String, String> get path => {
    'id': '${widget.articleID}',
    'pollID': '$pollID',
  };
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(ArticlePollCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.articleID != widget.articleID ||
        oldWidget.block['poll_id'] != widget.block['poll_id'] ||
        oldWidget.store != widget.store) {
      serial++;
      state = null;
      error = null;
      busy = false;
      selected.clear();
      answer.clear();
      load();
    }
  }

  Future<void> load() async {
    if (!interactive) return;
    final seq = ++serial;
    try {
      final result = await widget.store!.request(
        'GetArticlesIdPollsPollID',
        path: path,
      );
      if (mounted && seq == serial) {
        setState(() {
          state = result.data;
          error = null;
        });
      }
    } catch (e) {
      if (mounted && seq == serial) setState(() => error = '$e');
    }
  }

  Future<void> vote() async {
    if (!interactive ||
        busy ||
        state?['responded'] == true ||
        state?['closed'] == true) {
      return;
    }
    final seq = ++serial;
    setState(() => busy = true);
    try {
      final result = await widget.store!.request(
        'PostArticlesIdPollsPollID',
        path: path,
        body: {
          if (widget.block['mode'] == 'question')
            'answer': answer.text
          else
            'selections': selected.toList()..sort(),
        },
      );
      if (mounted && seq == serial) setState(() => state = result.data);
    } catch (e) {
      if (mounted && seq == serial) {
        await showRequestFailure(context, e);
        if (mounted) await load();
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    answer.dispose();
    super.dispose();
  }

  void toggle(int i) {
    final b = widget.block;
    setState(() {
      if (b['multiple'] != true) {
        selected
          ..clear()
          ..add(i);
      } else if (!selected.remove(i)) {
        final limit = integer(b['max_selections']);
        if (selected.length < limit) {
          selected.add(i);
        } else {
          toast(context, '最多选$limit项');
        }
      }
    });
  }

  /// One option: name on the left, votes and share on the right, and a bar
  /// showing the share underneath once results are known.
  Widget option(
    BuildContext context, {
    required int index,
    required String name,
    required bool allowed,
    required bool showMark,
    required bool chosen,
    required bool multiple,
    required int? count,
    required double percent,
  }) {
    final colors = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: allowed ? () => toggle(index) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (showMark)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      multiple
                          ? (chosen
                                ? Icons.check_box
                                : Icons.check_box_outline_blank)
                          : (chosen
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked),
                      size: 20,
                      color: chosen ? colors.accent : colors.muted,
                    ),
                  ),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: chosen ? colors.accent : colors.ink,
                    ),
                  ),
                ),
                if (count != null)
                  Text(
                    '$count (${percent.toStringAsFixed(1)}%)',
                    style: TextStyle(fontSize: 12, color: colors.muted),
                  ),
              ],
            ),
            if (count != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (percent / 100).clamp(0.0, 1.0),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
                backgroundColor: colors.muted.withValues(alpha: .15),
                color: chosen
                    ? colors.accent
                    : colors.muted.withValues(alpha: .5),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Feed version of an option: one slim row whose background is the result
  /// bar, so a poll takes little more room than a line of text per choice.
  Widget compactOption(
    BuildContext context, {
    required String name,
    required VoidCallback? onTap,
    required bool showMark,
    required bool chosen,
    required bool multiple,
    required double? percent,
  }) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: colors.inset,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              if (percent != null)
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (percent / 100).clamp(0.0, 1.0),
                    child: ColoredBox(
                      color: colors.accent.withValues(alpha: chosen ? .22 : .1),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  height: 36,
                  child: Row(
                    children: [
                      if (showMark)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            multiple
                                ? (chosen
                                      ? Icons.check_box
                                      : Icons.check_box_outline_blank)
                                : (chosen
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked),
                            size: 16,
                            color: chosen ? colors.accent : colors.muted,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: chosen ? colors.accent : colors.ink,
                          ),
                        ),
                      ),
                      if (percent != null)
                        Text(
                          '${percent.round()}%',
                          style: TextStyle(fontSize: 12, color: colors.muted),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.block;
    final colors = context.colors;
    final question = b['mode'] == 'question';
    final multiple = b['multiple'] == true;
    final options = b['options'] is List
        ? (b['options'] as List).whereType<String>().toList()
        : <String>[];
    final responded = state?['responded'] == true;
    final closed = state?['closed'] == true;
    final allowed =
        interactive && state != null && !responded && !closed && !busy;
    final choices = responded
        ? (state?['selections'] as List? ?? []).whereType<int>().toSet()
        : selected;
    final counts = (state?['counts'] as List? ?? []).map(integer).toList();
    final total = multiple
        ? integer(state?['participants'])
        : counts.fold<int>(0, (sum, count) => sum + count);
    final end = DateTime.tryParse('${b['ends_at'] ?? ''}')?.toLocal();
    final type = question
        ? '问答'
        : multiple
        ? '多选投票'
        : '单选投票';
    final loc = MaterialLocalizations.of(context);
    final canSubmit =
        allowed &&
        (question ? answer.text.trim().isNotEmpty : selected.isNotEmpty);
    final meta = [
      if (state != null) '${state!['participants']}人参与',
      if (end != null)
        '${loc.formatShortDate(end)} ${TimeOfDay.fromDateTime(end).format(context)} 截止',
    ].join(' · ');
    // A participant who has answered is told the right answer either way.
    final revealed = state?['correct_answer'] is String
        ? '${state!['correct_answer']}'
        : [
            for (final i in state?['correct_options'] as List? ?? [])
              if (integer(i) >= 0 && integer(i) < options.length)
                options[integer(i)],
          ].join('、');
    final label = responded
        ? (state?['correct'] == true
              ? (revealed.isEmpty ? '恭喜你，答对啦！' : '恭喜你，答对啦！正确答案是：$revealed')
              : state?['correct'] == false
              ? (revealed.isEmpty ? '回答错啦！' : '回答错啦！正确答案是：$revealed')
              : '已投票')
        : closed
        ? '已结束'
        : question
        ? '提交答案'
        : '投票';
    if (widget.embedded) {
      // A single choice is submitted by tapping it; multiple choice and
      // questions keep a small submit button.
      final needsButton = !responded && !closed && (multiple || question);
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (end != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${loc.formatShortDate(end)} ${TimeOfDay.fromDateTime(end).format(context)} 截止',
                  style: TextStyle(fontSize: 12, color: colors.muted),
                ),
              ),
            if (question && allowed)
              TextField(
                controller: answer,
                maxLength: 50,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: '请输入答案'),
              )
            else if (question)
              if (responded || closed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 12, color: colors.muted),
                  ),
                )
              else
                const SizedBox.shrink()
            else
              for (var i = 0; i < options.length; i++)
                compactOption(
                  context,
                  name: options[i],
                  onTap: !allowed
                      ? null
                      : multiple
                      ? () => toggle(i)
                      : () {
                          selected
                            ..clear()
                            ..add(i);
                          vote();
                        },
                  showMark: allowed || responded,
                  chosen: choices.contains(i),
                  multiple: multiple,
                  percent: i < counts.length && total > 0
                      ? counts[i] * 100 / total
                      : (i < counts.length ? 0 : null),
                ),
            if (error != null)
              TextButton(onPressed: load, child: const Text('重新加载投票')),
            if (needsButton && interactive && state != null)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: canSubmit ? vote : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(72, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    backgroundColor: colors.accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: colors.inset,
                    disabledForegroundColor: colors.muted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ).withoutHover(),
                  child: Text(label, textAlign: TextAlign.center),
                ),
              ),
          ],
        ),
      );
    }
    return Container(
      decoration: widget.embedded
          ? null
          : BoxDecoration(
              color: colors.inset,
              borderRadius: BorderRadius.circular(12),
            ),
      padding: widget.embedded
          ? const EdgeInsets.only(top: 6, bottom: 6)
          : const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.embedded) ...[
            Text(type, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 5),
            Text(
              '${b['title'] ?? ''}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
          if (meta.isNotEmpty && !widget.embedded)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                meta,
                style: TextStyle(fontSize: 12, color: colors.muted),
              ),
            ),
          SizedBox(height: widget.embedded ? 0 : 6),
          if (question && allowed)
            TextField(
              controller: answer,
              maxLength: 50,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: '请输入答案'),
            )
          else if (!question)
            for (var i = 0; i < options.length; i++)
              option(
                context,
                index: i,
                name: options[i],
                allowed: allowed,
                showMark: allowed || responded,
                chosen: choices.contains(i),
                multiple: multiple,
                count: i < counts.length ? counts[i] : null,
                percent: i < counts.length && total > 0
                    ? counts[i] * 100 / total
                    : 0,
              ),
          if (error != null)
            TextButton(onPressed: load, child: const Text('重新加载投票')),
          if (interactive && (state != null || busy)) ...[
            const SizedBox(height: 6),
            FilledButton(
              onPressed: canSubmit ? vote : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: colors.accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: widget.embedded
                    ? colors.inset
                    : colors.surface,
                disabledForegroundColor: colors.accent.withValues(alpha: .5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ).withoutHover(),
              child: Text(label),
            ),
          ],
        ],
      ),
    );
  }
}
