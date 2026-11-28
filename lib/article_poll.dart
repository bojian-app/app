import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import 'app_page_bar.dart';
import 'app_store.dart';
import 'confirmation_dialog.dart';
import 'app_icons.dart';
import 'design.dart';

/// Opens the form for a new poll or question, and returns its public block.
/// [initial] is the block of one being changed: the form starts from it, and
/// finishing makes a new poll (a saved one never changes, so its votes do not
/// carry over).
Future<Map<String, dynamic>?> openArticlePollComposer(
  BuildContext context,
  AppStore store, {
  Map<String, dynamic>? initial,
}) => openPage<Map<String, dynamic>>(
  context,
  _PollComposer(store: store, initial: initial),
);

class _PollComposer extends StatefulWidget {
  const _PollComposer({required this.store, this.initial});
  final AppStore store;
  final Map<String, dynamic>? initial;
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
  String deadline = '一周';
  DateTime? picked;
  String? lastData, requestKey;
  DateTime? requestDeadline;

  /// Answer keys are never sent back to the client, so changing a poll means
  /// setting its answer again.
  bool get keyLost => widget.initial?['has_correct_answer'] == true;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial == null) return;
    question = initial['mode'] == 'question';
    (question ? questionTitle : pollTitle).text = '${initial['title'] ?? ''}';
    final values = [
      for (final value in initial['options'] as List? ?? const [])
        if (value is String) value,
    ];
    if (values.length >= 2) {
      for (final c in options) {
        c.dispose();
      }
      options
        ..clear()
        ..addAll([
          for (final value in values) TextEditingController(text: value),
        ]);
    }
    multiple = initial['multiple'] == true;
    quiz = !question && keyLost;
    final end = DateTime.tryParse('${initial['ends_at'] ?? ''}')?.toLocal();
    if (initial['ends_at'] == null) {
      deadline = '从不';
    } else if (end != null && end.isAfter(DateTime.now())) {
      deadline = '自定义';
      picked = end;
    }
  }

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
        // Any number of options may be picked, so the cap is every option.
        if (multiple) 'max_selections': values.length,
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

  /// Field drawn straight on its card: the card is the field's surface.
  InputDecoration bare(String hint) => InputDecoration(
    hintText: hint,
    filled: false,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(vertical: 15),
  );

  /// Rows on one bordered card, split by hairlines from [inset].
  Widget card(List<Widget> rows, {double inset = 16}) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: inset,
                    color: colors.border,
                  ),
                rows[i],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget settingRow(String title, {String? subtitle, Widget? trailing}) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: colors.ink,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: colors.muted),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing],
        ],
      ),
    );
  }

  Widget toggle(bool value, ValueChanged<bool> onChanged) => SizedBox(
    height: 26,
    child: FittedBox(
      child: Switch.adaptive(
        padding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        value: value,
        activeTrackColor: context.colors.palette.seed,
        onChanged: onChanged,
      ),
    ),
  );

  /// Equal-width segments on a sunken track; the chosen one is raised.
  Widget segmented(
    List<(String, String)> items,
    String selected,
    ValueChanged<String> onTap, {
    double height = 40,
  }) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.inset,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final (value, label) in items)
            Expanded(
              child: Semantics(
                button: true,
                selected: value == selected,
                inMutuallyExclusiveGroup: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: value == selected
                          ? (dark ? colors.border : colors.canvas)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: value == selected && !dark
                          ? const [
                              BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 6,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: value == selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: value == selected ? colors.ink : colors.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget optionRow(int i) {
    final colors = context.colors, option = options[i];
    final right = correct.contains(option);
    final Widget lead = quiz
        ? Semantics(
            label: '选项${i + 1}正确',
            checked: right,
            button: true,
            child: InkResponse(
              radius: 18,
              onTap: () => change(() {
                if (right) {
                  correct.remove(option);
                } else {
                  if (!multiple) correct.clear();
                  correct.add(option);
                }
              }),
              child: Icon(
                right
                    ? (multiple
                          ? Icons.check_box_rounded
                          : Icons.check_circle_rounded)
                    : (multiple
                          ? Icons.check_box_outline_blank_rounded
                          : Icons.radio_button_unchecked_rounded),
                size: 22,
                color: right ? colors.success : colors.muted,
              ),
            ),
          )
        : Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.inset,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${i + 1}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.muted,
              ),
            ),
          );
    return Padding(
      key: ObjectKey(option),
      padding: EdgeInsets.only(left: 16, right: options.length > 2 ? 4 : 16),
      child: Row(
        children: [
          SizedBox(width: 22, child: lead),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: option,
              onChanged: markEdited,
              decoration: bare('选项 ${i + 1}'),
            ),
          ),
          if (options.length > 2)
            IconButton(
              tooltip: '删除选项 ${i + 1}',
              onPressed: () => removeOption(option),
              icon: Icon(Icons.close_rounded, size: 18, color: colors.muted),
            ),
        ],
      ),
    );
  }

  void removeOption(TextEditingController option) {
    change(() {
      options.remove(option);
      correct.remove(option);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => option.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final type = question ? '问答' : '投票';
    final colors = context.colors;
    return PopScope(
      canPop: leaving || !saving && !dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) close();
      },
      child: Scaffold(
        appBar: AppPageBar(
          // The theme's text buttons have no side padding, so inset them to the gutter.
          leadingWidth: appPageHorizontalPadding + 96,
          leading: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: appPageHorizontalPadding),
              child: TextButton(
                onPressed: saving ? null : close,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: [AppIcon(AppIcons.back, size: 20), Text('返回')],
                ),
              ),
            ),
          ),
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
                if (keyLost)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: colors.warningSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '为保护答案，重新发布前需再设置一次正确答案',
                      style: TextStyle(fontSize: 13, color: colors.ink),
                    ),
                  ),
                segmented(
                  const [('poll', '投票'), ('question', '问答')],
                  question ? 'question' : 'poll',
                  (v) => setState(() => question = v == 'question'),
                ),
                const SizedBox(height: 16),
                card(inset: question ? 16 : 50, [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: question ? questionTitle : pollTitle,
                      onChanged: markEdited,
                      minLines: 1,
                      maxLines: 3,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.ink,
                      ),
                      decoration: bare('$type标题'),
                    ),
                  ),
                  if (question)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: TextField(
                        controller: answer,
                        maxLength: 50,
                        minLines: 2,
                        maxLines: 4,
                        onChanged: markEdited,
                        decoration: bare('请输入正确答案'),
                      ),
                    )
                  else ...[
                    for (var i = 0; i < options.length; i++) optionRow(i),
                    InkWell(
                      onTap: () =>
                          change(() => options.add(TextEditingController())),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 22,
                              child: Icon(
                                Icons.add_rounded,
                                size: 20,
                                color: colors.accent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '添加选项',
                              style: TextStyle(
                                fontSize: 15,
                                color: colors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ]),
                if (question)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                    child: Text(
                      '答题者需输入完全匹配的答案，才算回答正确',
                      style: TextStyle(fontSize: 12, color: colors.muted),
                    ),
                  ),
                const SizedBox(height: 20),
                card([
                  if (!question) ...[
                    settingRow(
                      '多选',
                      subtitle: '投票者可选择任意个选项',
                      trailing: toggle(
                        multiple,
                        (v) => change(() {
                          multiple = v;
                          if (!v && correct.length > 1) correct.clear();
                        }),
                      ),
                    ),
                    settingRow(
                      '设置正确答案',
                      subtitle: quiz
                          ? (multiple ? '在选项前勾选所有正确答案' : '在选项前选择正确答案')
                          : '投票变为答题，可判断对错',
                      trailing: toggle(quiz, (v) => change(() => quiz = v)),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        settingRow(
                          '结束时间',
                          trailing: deadline == '自定义' && picked != null
                              ? Text(
                                  '${MaterialLocalizations.of(context).formatShortMonthDay(picked!)} ${TimeOfDay.fromDateTime(picked!).format(context)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colors.muted,
                                  ),
                                )
                              : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: segmented(
                            const [
                              ('一天', '1 天'),
                              ('一周', '1 周'),
                              ('从不', '不限'),
                              ('自定义', '自定义'),
                            ],
                            deadline,
                            (d) => d == '自定义'
                                ? customDate()
                                : change(() => deadline = d),
                            height: 36,
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: colors.muted,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$type保存后内容不可再修改',
                          style: TextStyle(fontSize: 12, color: colors.muted),
                        ),
                      ),
                    ],
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

class ArticlePollCard extends StatefulWidget {
  const ArticlePollCard({
    super.key,
    required this.block,
    this.store,
    this.articleID,
    this.embedded = false,
  });

  /// Inside a feed card: the vote or quiz question sits directly on the card,
  /// stating its wording above the options or the answer line.
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

  /// Submits the typed answer, asking for one first.
  void submitAnswer() {
    if (answer.text.trim().isEmpty) {
      toast(context, '请先输入答案');
      return;
    }
    vote();
  }

  /// How long a question stays open, as its tag says it.
  static String timeLeft(Duration left) {
    if (left.inDays >= 1) return '还剩${left.inDays}天';
    if (left.inHours >= 1) return '还剩${left.inHours}小时';
    if (left.inMinutes >= 1) return '还剩${left.inMinutes}分钟';
    return '即将截止';
  }

  /// A vote or question on its feed card: a tag naming its [kind] and time
  /// left, its wording, then [children], with no panel of its own behind them.
  Widget feedBox(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String kind,
    required DateTime? end,
    required bool closed,
    required List<Widget> children,
    Widget? stamp,
  }) {
    final colors = context.colors;
    final left = end?.difference(DateTime.now());
    final status = isOver(closed, end)
        ? '已结束'
        : left == null
        ? ''
        : timeLeft(left);
    final title = '${widget.block['title'] ?? ''}'.trim();
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: colors.accent),
                  // The corner bracket brings its own space before the word.
                  const SizedBox(width: 2),
                  Text(
                    '「$kind」$status',
                    style: TextStyle(fontSize: 12, color: colors.accent),
                  ),
                ],
              ),
              if (title.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    color: colors.ink,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              ...children,
            ],
          ),
          // A watermark over the card: it takes no room, the text runs on
          // beneath it.
          if (stamp != null) Positioned(top: 0, right: 0, child: stamp),
        ],
      ),
    );
  }

  static bool isOver(bool closed, DateTime? end) =>
      closed || (end != null && !end.isAfter(DateTime.now()));

  /// The round accent button of a feed vote, faded while it cannot be used.
  ButtonStyle feedButtonStyle(BuildContext context) => FilledButton.styleFrom(
    minimumSize: const Size(60, 34),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    backgroundColor: context.colors.accent,
    foregroundColor: Colors.white,
    disabledBackgroundColor: context.colors.accent.withValues(alpha: .4),
    disabledForegroundColor: Colors.white,
    shape: const StadiumBorder(),
  ).withoutHover();

  /// A question on its feed card. Once answered, a stamp says whether rightly
  /// and a line gives the right answer; once closed unanswered, a row says so.
  Widget questionBox(
    BuildContext context, {
    required bool responded,
    required bool closed,
    required bool allowed,
    required DateTime? end,
    required String revealed,
  }) {
    final colors = context.colors;
    final over = isOver(closed, end);
    final length = answer.text.characters.length;
    final correct = responded ? state!['correct'] : null;
    final Widget? body;
    if (responded) {
      // The label steps back and the answer takes the green of a right one, so
      // neither reads as more of the question above. An answer nobody graded
      // gets no stamp, only word that it arrived.
      body = revealed.isNotEmpty
          ? Text.rich(
              TextSpan(
                text: '正确答案：',
                style: TextStyle(color: colors.muted),
                children: [
                  TextSpan(
                    text: revealed,
                    style: TextStyle(
                      color: colors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 14),
            )
          : correct is bool
          ? null
          : Text('已提交答案', style: TextStyle(fontSize: 14, color: colors.muted));
    } else if (over) {
      body = answerResult(
        context,
        icon: Icons.schedule,
        tint: colors.muted,
        text: revealed.isEmpty ? '本题已结束' : '本题已结束，正确答案是：$revealed',
      );
    } else {
      body = answerField(context, allowed: allowed);
    }
    return feedBox(
      context,
      key: const ValueKey('feed-question'),
      icon: Icons.help_outline,
      kind: '问答',
      end: end,
      closed: closed,
      stamp: correct is bool ? _AnswerStamp(correct: correct) : null,
      children: [
        ?body,
        if (!responded && !over && length >= 40)
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 8),
            child: Text(
              '$length/50',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12, color: colors.muted),
            ),
          ),
        if (error != null)
          TextButton(onPressed: load, child: const Text('重新加载题目')),
      ],
    );
  }

  /// The answer and its submit button in one rounded line.
  Widget answerField(BuildContext context, {required bool allowed}) {
    final colors = context.colors;
    final signedOut = widget.store?.isAuthenticated != true;
    return Material(
      color: colors.inset,
      borderRadius: BorderRadius.circular(22),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: answer,
              enabled: allowed,
              maxLength: 50,
              // The count shows under the box, and only near the limit.
              buildCounter: (
                _, {
                required currentLength,
                required isFocused,
                maxLength,
              }) => null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => submitAnswer(),
              onChanged: (_) => setState(() {}),
              style: TextStyle(fontSize: 14, color: colors.ink),
              decoration: InputDecoration(
                hintText: signedOut ? '登录后可以作答' : '请输入答案',
                filled: false,
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: FilledButton(
              onPressed: allowed ? submitAnswer : null,
              style: feedButtonStyle(context),
              child: busy
                  ? const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('提交'),
            ),
          ),
        ],
      ),
    );
  }

  Widget answerResult(
    BuildContext context, {
    required IconData icon,
    required Color tint,
    required String text,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: context.colors.inset,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(icon, size: 16, color: tint),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, color: context.colors.ink),
          ),
        ),
      ],
    ),
  );

  /// One option: name on the left, votes and share on the right, and a bar
  /// showing the share underneath once results are known.
  Widget option(
    BuildContext context, {
    required int index,
    required String name,
    required bool allowed,
    required bool showMark,
    required bool chosen,
    bool wrong = false,
    required bool multiple,
    required int? count,
    required double percent,
  }) {
    final colors = context.colors;
    // Picked choices are always green and ones the answer key rules out red,
    // whatever accent colour the app is themed with.
    final tint = wrong ? Theme.of(context).colorScheme.error : colors.success;
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
                      color: chosen ? tint : colors.muted,
                    ),
                  ),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: chosen ? tint : colors.ink,
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
                color: chosen ? tint : colors.muted.withValues(alpha: .5),
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
    bool wrong = false,
    required bool multiple,
    required double? percent,
  }) {
    final colors = context.colors;
    // Picked choices are always green and ones the answer key rules out red,
    // whatever accent colour the app is themed with.
    final tint = wrong ? Theme.of(context).colorScheme.error : colors.success;
    return Material(
      color: colors.inset,
      borderRadius: BorderRadius.circular(10),
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
                  // Grey for the others, so only the chosen row is coloured.
                  child: ColoredBox(
                    color: chosen
                        ? tint.withValues(alpha: .22)
                        : colors.muted.withValues(alpha: .18),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                height: 38,
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
                          color: chosen ? tint : colors.muted,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: chosen ? tint : colors.ink,
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
    final key = {
      for (final i in state?['correct_options'] as List? ?? [])
        if (i is num) i.toInt(),
    };
    // Only picks that the revealed answer key rules out are wrong.
    bool isWrong(int i) =>
        responded && key.isNotEmpty && choices.contains(i) && !key.contains(i);
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
    if (widget.embedded && question) {
      return questionBox(
        context,
        responded: responded,
        closed: closed,
        allowed: allowed,
        end: end,
        revealed: revealed,
      );
    }
    if (widget.embedded) {
      // A single choice is submitted by tapping it; multiple choice keeps a
      // small submit button.
      // Past its deadline a vote takes no more choices, as its tag says.
      final open = allowed && !isOver(closed, end);
      final needsButton = !responded && !isOver(closed, end) && multiple;
      return feedBox(
        context,
        key: const ValueKey('feed-vote'),
        icon: Icons.poll_outlined,
        kind: multiple ? '多选投票' : '投票',
        end: end,
        closed: closed,
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            compactOption(
              context,
              name: options[i],
              onTap: !open
                  ? null
                  : multiple
                  ? () => toggle(i)
                  : () {
                      selected
                        ..clear()
                        ..add(i);
                      vote();
                    },
              showMark: open || responded,
              chosen: choices.contains(i),
              wrong: isWrong(i),
              multiple: multiple,
              percent: i < counts.length && total > 0
                  ? counts[i] * 100 / total
                  : (i < counts.length ? 0 : null),
            ),
          ],
          if (error != null)
            TextButton(onPressed: load, child: const Text('重新加载投票')),
          if (needsButton && interactive && state != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: !allowed
                      ? null
                      : () {
                          if (selected.isEmpty) {
                            toast(context, '请先选择选项');
                            return;
                          }
                          vote();
                        },
                  style: feedButtonStyle(context),
                  child: Text(label),
                ),
              ),
            ),
        ],
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
                wrong: isWrong(i),
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

/// The round seal pressed over an answered question: right or wrong.
class _AnswerStamp extends StatelessWidget {
  const _AnswerStamp({required this.correct});
  final bool correct;

  @override
  Widget build(BuildContext context) {
    final label = correct ? '回答正确' : '回答错误';
    // Faded like ink on paper, so the text it crosses stays readable.
    final ink =
        (correct ? context.colors.success : Theme.of(context).colorScheme.error)
            .withValues(alpha: .55);
    Widget ring(double width, Widget child) => DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ink, width: width),
      ),
      child: Padding(padding: const EdgeInsets.all(3), child: child),
    );
    return Semantics(
      key: const ValueKey('answer-stamp'),
      label: label,
      excludeSemantics: true,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: -pi / 12,
          child: SizedBox.square(
            dimension: 62,
            child: ring(
              2,
              ring(
                1,
                Center(
                  child: Text(
                    '${label.substring(0, 2)}\n${label.substring(2)}',
                    textAlign: TextAlign.center,
                    // The seal has a fixed size.
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
