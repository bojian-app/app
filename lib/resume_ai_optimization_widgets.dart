import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_icons.dart';
import 'app_theme.dart';
import 'resume_ai_optimization_models.dart';
import 'resume_text_diff.dart';

const _radius = 16.0;

/// Colors shared by the AI optimization page, derived from the app theme.
extension PolishColors on BuildContext {
  Color get polishWarning =>
      isDark ? const Color(0xFFF0B46B) : const Color(0xFFC46A12);
  Color polishLevel(PolishLevel level) => switch (level) {
    PolishLevel.good => colors.success,
    PolishLevel.fair => colors.accent,
    PolishLevel.weak => polishWarning,
  };
  Color polishLevelSoft(PolishLevel level) => switch (level) {
    PolishLevel.good => colors.successSoft,
    PolishLevel.fair => colors.accentSoft,
    PolishLevel.weak => colors.warningSoft,
  };
}

class PolishCard extends StatelessWidget {
  const PolishCard({
    super.key,
    required this.child,
    this.borderColor,
    this.padding = const EdgeInsets.all(18),
  });
  final Widget child;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    margin: const EdgeInsets.only(bottom: 12),
    padding: padding,
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(_radius),
      border: Border.all(
        color: borderColor ?? context.colors.border,
        width: borderColor == null ? 1 : 1.4,
      ),
    ),
    child: child,
  );
}

class PolishSectionHeading extends StatelessWidget {
  const PolishSectionHeading(
    this.title, {
    super.key,
    this.caption,
    this.trailing,
  });
  final String title;
  final String? caption;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 0, 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: context.colors.ink,
                ),
              ),
              if (caption != null) ...[
                const SizedBox(height: 4),
                Text(
                  caption!,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: context.colors.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class PolishPill extends StatelessWidget {
  const PolishPill(this.text, {super.key, required this.color, this.soft});
  final String text;
  final Color color;
  final Color? soft;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: soft ?? color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.3,
      ),
    ),
  );
}

/// Overall verdict shown first, the way a resume consultant opens a review.
class PolishDiagnosisCard extends StatefulWidget {
  const PolishDiagnosisCard({
    super.key,
    required this.summary,
    required this.diagnosis,
    required this.changeCount,
    required this.issueCount,
    required this.onReanalyze,
    this.onShowChanges,
    this.onShowIssues,
  });
  final String summary;
  final PolishDiagnosis? diagnosis;
  final int changeCount, issueCount;
  final VoidCallback? onReanalyze, onShowChanges, onShowIssues;
  @override
  State<PolishDiagnosisCard> createState() => _PolishDiagnosisCardState();
}

class _PolishDiagnosisCardState extends State<PolishDiagnosisCard> {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final diagnosis = widget.diagnosis;
    final overall = diagnosis?.overall ?? '';
    final dimensions = diagnosis?.dimensions ?? const <PolishDimension>[];
    final score = diagnosis?.score;
    // With a structured diagnosis the prose summary is supporting detail.
    final foldSummary = dimensions.isNotEmpty || overall.isNotEmpty;
    final summaryStyle = TextStyle(
      fontSize: 14,
      height: 1.65,
      color: colors.ink,
    );
    return PolishCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '诊断结论',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: colors.ink,
                  ),
                ),
              ),
              if (score != null)
                Text.rich(
                  key: const ValueKey('resume-ai-score'),
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$score',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: score >= 8
                              ? context.polishLevel(PolishLevel.good)
                              : score >= 6
                              ? context.polishLevel(PolishLevel.fair)
                              : context.polishWarning,
                        ),
                      ),
                      TextSpan(
                        text: ' / 10',
                        style: TextStyle(fontSize: 13, color: colors.muted),
                      ),
                    ],
                  ),
                ),
              TextButton.icon(
                key: const ValueKey('resume-ai-reanalyze'),
                onPressed: widget.onReanalyze,
                icon: const AppIcon(AppIcons.refresh, size: 16),
                label: const Text('重新分析'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (overall.isNotEmpty) ...[
            Text(
              overall,
              style: TextStyle(
                fontSize: 15,
                height: 1.55,
                fontWeight: FontWeight.w600,
                color: colors.ink,
              ),
            ),
            const SizedBox(height: 6),
          ],
          if (widget.summary.isNotEmpty && !foldSummary)
            Text(widget.summary, style: summaryStyle),
          if (dimensions.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final d in dimensions) _DimensionRow(d),
          ],
          _DiagnosisList(
            title: '亮点',
            items: diagnosis?.highlights ?? const [],
            color: context.polishLevel(PolishLevel.good),
          ),
          _DiagnosisList(
            title: '面试可能追问',
            items: diagnosis?.risks ?? const [],
            color: context.polishWarning,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  key: const ValueKey('resume-ai-stat-changes'),
                  value: widget.changeCount,
                  label: '处修改',
                  color: colors.accent,
                  onTap: widget.changeCount > 0 ? widget.onShowChanges : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Stat(
                  key: const ValueKey('resume-ai-stat-issues'),
                  value: widget.issueCount,
                  label: '项待补充',
                  color: widget.issueCount > 0
                      ? context.polishWarning
                      : colors.muted,
                  onTap: widget.issueCount > 0 ? widget.onShowIssues : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A short titled list inside the diagnosis card; hidden when empty.
class _DiagnosisList extends StatelessWidget {
  const _DiagnosisList({
    required this.title,
    required this.items,
    required this.color,
  });
  final String title;
  final List<String> items;
  final Color color;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.ink,
            ),
          ),
          const SizedBox(height: 6),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 8),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.55,
                        color: colors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One rating as a three-step meter: weak fills one step, good fills all.
class _DimensionRow extends StatelessWidget {
  const _DimensionRow(this.dimension);
  final PolishDimension dimension;
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = context.polishLevel(dimension.level);
    final filled = switch (dimension.level) {
      PolishLevel.good => 3,
      PolishLevel.fair => 2,
      PolishLevel.weak => 1,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 84,
                child: Text(
                  dimension.title,
                  style: TextStyle(fontSize: 14, color: colors.ink),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      Expanded(
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: i < filled ? color : colors.inset,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(
                width: 52,
                child: Text(
                  dimension.levelLabel,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          if (dimension.level != PolishLevel.good) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 84),
              child: Text(
                dimension.comment,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.55,
                  color: colors.muted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    super.key,
    required this.value,
    required this.label,
    required this.color,
    this.onTap,
  });
  final int value;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: context.colors.inset,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$value',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    TextSpan(
                      text: ' $label',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (onTap != null)
              AppIcon(AppIcons.forward, size: 14, color: context.colors.muted),
          ],
        ),
      ),
    ),
  );
}

/// A single rewrite with its reason, highlighted revision and the choice to
/// adopt or ignore it.
class PolishChangeCard extends StatefulWidget {
  const PolishChangeCard({
    super.key,
    required this.change,
    required this.location,
    required this.adopted,
    required this.onChanged,
    this.placeholders = 0,
    this.relatedIssues = 0,
    this.onShowIssues,
  });
  final PolishChange change;
  final PolishLocation location;
  final bool adopted;
  final ValueChanged<bool>? onChanged;

  /// How many "【待补充】" facts the user must fill before adopting.
  final int placeholders;

  /// Open questions about the same experience, shown so nobody adopts a
  /// rewrite without seeing the contradiction next to it.
  final int relatedIssues;
  final VoidCallback? onShowIssues;
  @override
  State<PolishChangeCard> createState() => _PolishChangeCardState();
}

class _PolishChangeCardState extends State<PolishChangeCard> {
  bool showOriginal = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final change = widget.change;
    final diff = change.diff;
    final marked = diff != null && diff.readable;
    final path = change.path;
    return PolishCard(
      borderColor: widget.adopted ? colors.accent.withValues(alpha: .55) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.location.title,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                    color: colors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (widget.placeholders > 0)
                PolishPill(
                  widget.adopted ? '已补充' : '需补充 ${widget.placeholders} 处',
                  color: context.polishWarning,
                  soft: colors.warningSoft,
                )
              else if (!marked)
                PolishPill('整段重写', color: colors.muted, soft: colors.inset),
            ],
          ),
          if (change.reason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: colors.inset,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '原因  ',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: colors.accent,
                      ),
                    ),
                    TextSpan(text: change.reason),
                  ],
                ),
                style: TextStyle(fontSize: 13, height: 1.6, color: colors.ink),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (widget.relatedIssues > 0) ...[
            Material(
              color: colors.warningSoft,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                key: ValueKey('resume-ai-related-$path'),
                borderRadius: BorderRadius.circular(10),
                onTap: widget.onShowIssues,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
                  child: Row(
                    children: [
                      AppIcon(
                        AppIcons.alert,
                        size: 16,
                        color: context.polishWarning,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '这段经历还有 ${widget.relatedIssues} 处待核对',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: colors.ink,
                          ),
                        ),
                      ),
                      AppIcon(AppIcons.forward, size: 14, color: colors.muted),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 2),
          Row(
            children: [
              _Label('优化后', color: colors.accent),
              const Spacer(),
              if (change.lengthNote case final note?)
                Text(
                  note,
                  key: ValueKey('resume-ai-length-$path'),
                  style: TextStyle(fontSize: 12, color: colors.muted),
                ),
            ],
          ),
          const SizedBox(height: 6),
          _DiffText(
            foldKey: ValueKey('resume-ai-fold-$path'),
            segments: marked
                ? diff.revised.toList()
                : [TextDiffSegment(TextDiffKind.equal, change.after)],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: ValueKey('resume-ai-original-$path'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 36),
                foregroundColor: colors.muted,
              ),
              onPressed: () => setState(() => showOriginal = !showOriginal),
              icon: AnimatedRotation(
                turns: showOriginal ? .5 : 0,
                duration: const Duration(milliseconds: 160),
                child: const AppIcon(AppIcons.expand, size: 16),
              ),
              label: Text(showOriginal ? '收起原文' : '对比原文'),
            ),
          ),
          if (showOriginal) ...[
            _Label('原文', color: colors.muted),
            const SizedBox(height: 6),
            _DiffText(
              muted: true,
              segments: marked
                  ? diff.original.toList()
                  : [TextDiffSegment(TextDiffKind.equal, change.before)],
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ChoiceButton(
                  key: ValueKey('resume-ai-ignore-$path'),
                  label: '忽略',
                  selected: !widget.adopted,
                  onTap: widget.onChanged == null
                      ? null
                      : () => widget.onChanged!(false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ChoiceButton(
                  key: ValueKey('resume-ai-adopt-$path'),
                  label: widget.placeholders == 0
                      ? '采纳'
                      : widget.adopted
                      ? '修改补充'
                      : '补充并采纳',
                  primary: true,
                  selected: widget.adopted,
                  onTap: widget.onChanged == null
                      ? null
                      : () => widget.onChanged!(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Asks for the user's real facts in place of each placeholder; returns null
/// when cancelled.
Future<List<String>?> showPolishFillDialog(
  BuildContext context,
  PolishChange change, {
  List<String>? initial,
}) => showDialog<List<String>>(
  context: context,
  builder: (_) => _PolishFillDialog(change: change, initial: initial),
);

class _PolishFillDialog extends StatefulWidget {
  const _PolishFillDialog({required this.change, this.initial});
  final PolishChange change;
  final List<String>? initial;
  @override
  State<_PolishFillDialog> createState() => _PolishFillDialogState();
}

class _PolishFillDialogState extends State<_PolishFillDialog> {
  late final controllers = [
    for (var i = 0; i < widget.change.placeholders.length; i++)
      TextEditingController(text: widget.initial?.elementAtOrNull(i) ?? '')
        ..addListener(() => setState(() {})),
  ];

  @override
  void dispose() {
    for (final c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hints = widget.change.placeholders;
    final ready = controllers.every((c) => c.text.trim().isNotEmpty);
    return AlertDialog(
      title: const Text('补充真实信息'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '填写后替换建议中的待补充内容。没有对应信息时请忽略这条建议，不要编造。',
              style: TextStyle(fontSize: 13, height: 1.6, color: colors.muted),
            ),
            for (var i = 0; i < hints.length; i++) ...[
              const SizedBox(height: 12),
              TextField(
                key: ValueKey('resume-ai-fill-$i'),
                controller: controllers[i],
                autofocus: i == 0,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(labelText: hints[i]),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('resume-ai-fill-confirm'),
          onPressed: ready
              ? () => Navigator.pop(context, [
                  for (final c in controllers) c.text.trim(),
                ])
              : null,
          child: const Text('采纳'),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
  );
}

/// Diff text that folds long unchanged stretches so the edit is on screen.
class _DiffText extends StatefulWidget {
  const _DiffText({required this.segments, this.muted = false, this.foldKey});
  final List<TextDiffSegment> segments;
  final bool muted;
  final Key? foldKey;
  @override
  State<_DiffText> createState() => _DiffTextState();
}

class _DiffTextState extends State<_DiffText> {
  static final _layoutOnly = RegExp(r'^[\s•·]+$');
  bool expanded = false;
  static const _minLines = 7;

  static List<List<TextDiffSegment>> lines(List<TextDiffSegment> segments) {
    final out = <List<TextDiffSegment>>[[]];
    for (final s in segments) {
      final parts = s.text.split('\n');
      for (var i = 0; i < parts.length; i++) {
        if (i > 0) out.add([]);
        if (parts[i].isNotEmpty) {
          out.last.add(TextDiffSegment(s.kind, parts[i]));
        }
      }
    }
    return out;
  }

  TextSpan span(BuildContext context, List<List<TextDiffSegment>> rows) {
    final colors = context.colors;
    return TextSpan(
      style: TextStyle(
        fontSize: 15,
        height: 1.7,
        color: widget.muted ? colors.muted : colors.ink,
      ),
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const TextSpan(text: '\n'),
          for (final s in rows[i])
            TextSpan(
              text: s.text,
              style: switch (s.kind) {
                // Bullet markers and line breaks are layout, not content.
                _ when _layoutOnly.hasMatch(s.text) => null,
                TextDiffKind.insert => TextStyle(
                  color: colors.accent,
                  backgroundColor: colors.accentSoft,
                ),
                TextDiffKind.delete => TextStyle(
                  color: context.polishWarning,
                  backgroundColor: colors.warningSoft,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: context.polishWarning,
                ),
                TextDiffKind.equal => null,
              },
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = lines(widget.segments);
    final changed = [
      for (final row in rows) row.any((s) => s.kind != TextDiffKind.equal),
    ];
    if (expanded || rows.length < _minLines || !changed.contains(true)) {
      return SelectableText.rich(span(context, rows));
    }
    // Keep each changed line plus one line of context on either side.
    final visible = List.generate(
      rows.length,
      (i) =>
          changed[i] ||
          (i > 0 && changed[i - 1]) ||
          (i + 1 < rows.length && changed[i + 1]),
    );
    final blocks = <Widget>[];
    var i = 0;
    while (i < rows.length) {
      var j = i;
      while (j < rows.length && visible[j] == visible[i]) {
        j++;
      }
      final run = rows.sublist(i, j);
      if (visible[i] || run.length == 1) {
        blocks.add(SelectableText.rich(span(context, run)));
      } else {
        blocks.add(
          _FoldButton(
            key: blocks.isEmpty ? widget.foldKey : null,
            count: run.length,
            onTap: () => setState(() => expanded = true),
          ),
        );
      }
      i = j;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: blocks,
    );
  }
}

class _FoldButton extends StatelessWidget {
  const _FoldButton({super.key, required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: colors.inset,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                AppIcon(AppIcons.expand, size: 14, color: colors.muted),
                const SizedBox(width: 6),
                Text(
                  '展开 $count 行未改动内容',
                  style: TextStyle(fontSize: 13, color: colors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.primary = false,
  });
  final String label;
  final bool selected, primary;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final active = primary ? colors.accent : colors.ink;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? (primary ? colors.accent : colors.inset)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected
                ? (primary ? colors.accent : colors.border)
                : colors.border,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          child: SizedBox(
            height: 40,
            child: Center(
              child: Text(
                selected && primary ? '已采纳' : (selected ? '已忽略' : label),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? (primary ? Colors.white : colors.ink)
                      : (onTap == null ? colors.muted : active),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PolishIssueCard extends StatefulWidget {
  const PolishIssueCard({
    super.key,
    required this.issue,
    required this.location,
    this.onEdit,
  });
  final PolishIssue issue;
  final PolishLocation location;
  final VoidCallback? onEdit;
  @override
  State<PolishIssueCard> createState() => _PolishIssueCardState();
}

class _PolishIssueCardState extends State<PolishIssueCard> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final warning = context.polishWarning;
    final issue = widget.issue;
    final location = widget.location;
    final messageStyle = TextStyle(
      fontSize: 14,
      height: 1.65,
      color: colors.ink,
    );
    return PolishCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  location.section,
                  style: TextStyle(fontSize: 12, color: colors.muted),
                ),
              ),
              PolishPill(
                issue.typeLabel,
                color: warning,
                soft: colors.warningSoft,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            location.title,
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w700,
              color: colors.ink,
            ),
          ),
          // The question is what to do; the reasoning is on request.
          if (issue.question.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(issue.question, style: messageStyle),
          ],
          if (issue.message.isNotEmpty && issue.question.isEmpty) ...[
            const SizedBox(height: 8),
            Text(issue.message, style: messageStyle),
          ],
          if (issue.message.isNotEmpty &&
              issue.question.isNotEmpty &&
              expanded) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: colors.inset,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                issue.message,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: colors.muted,
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              if (issue.message.isNotEmpty && issue.question.isNotEmpty)
                TextButton(
                  key: ValueKey('resume-ai-why-${issue.path}'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 36),
                    foregroundColor: colors.muted,
                  ),
                  onPressed: () => setState(() => expanded = !expanded),
                  child: Text(expanded ? '收起原因' : '查看原因'),
                ),
              const Spacer(),
              if (widget.onEdit != null)
                TextButton.icon(
                  key: ValueKey('resume-ai-edit-${issue.path}'),
                  onPressed: widget.onEdit,
                  iconAlignment: IconAlignment.end,
                  icon: const AppIcon(AppIcons.forward, size: 14),
                  label: const Text('去补充'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

enum PolishStep { start, queued, analyzing }

/// Progress while the server works, with honest steps instead of a bare
/// spinner so waiting a minute feels expected.
class PolishProgressCard extends StatelessWidget {
  const PolishProgressCard({
    super.key,
    required this.step,
    required this.onCancel,
  });
  final PolishStep step;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final steps = [
      ('读取简历', PolishStep.start),
      ('排队中', PolishStep.queued),
      ('逐条分析经历', PolishStep.analyzing),
    ];
    return PolishCard(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '正在分析',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.ink,
            ),
          ),
          const SizedBox(height: 18),
          for (final (text, value) in steps)
            _StepRow(
              text: text,
              state: value.index < step.index
                  ? _StepState.done
                  : value == step
                  ? _StepState.active
                  : _StepState.pending,
            ),
          const _StepRow(text: '生成修改建议', state: _StepState.pending),
          const SizedBox(height: 10),
          Text(
            '离开此页不影响，结果会保留。',
            style: TextStyle(fontSize: 12, height: 1.5, color: colors.muted),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: colors.muted,
              ),
              onPressed: onCancel,
              child: const Text('取消本次优化'),
            ),
          ),
        ],
      ),
    );
  }
}

enum _StepState { done, active, pending }

class _StepRow extends StatelessWidget {
  const _StepRow({required this.text, required this.state});
  final String text;
  final _StepState state;
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: switch (state) {
              _StepState.done => AppIcon(
                AppIcons.done,
                size: 18,
                color: colors.success,
              ),
              _StepState.active => Padding(
                padding: const EdgeInsets.all(2),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.accent,
                  backgroundColor: colors.accentSoft,
                ),
              ),
              _StepState.pending => Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.border, width: 2),
                  ),
                ),
              ),
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: state == _StepState.active
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: state == _StepState.pending ? colors.muted : colors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Centered message used for failure, cancellation and completion.
class PolishStatusCard extends StatelessWidget {
  const PolishStatusCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.message,
    this.children = const [],
  });
  final AppIconData icon;
  final Color iconColor, iconBackground;
  final String title, message;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PolishCard(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: iconBackground,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: AppIcon(icon, size: 28, color: iconColor),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.ink,
            ),
          ),
          if (message.isNotEmpty) const SizedBox(height: 8),
          if (message.isNotEmpty)
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.6, color: colors.muted),
            ),
          if (children.isNotEmpty) const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}

/// Inline error that keeps the current content visible.
class PolishErrorBanner extends StatelessWidget {
  const PolishErrorBanner({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final warning = context.polishWarning;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: colors.warningSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          AppIcon(AppIcons.alert, size: 18, color: warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, height: 1.5, color: colors.ink),
            ),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

enum PolishView { overview, changes, issues }

/// Shrinks [child] away with a slight springy swell first; reversing plays
/// the same motion backwards, so the card pops back with a small overshoot.
class PolishFold extends StatelessWidget {
  const PolishFold({super.key, required this.animation, required this.child});
  final Animation<double> animation;
  final Widget child;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) {
      final t = animation.value;
      if (t == 0) return child!;
      final scale = 1 - Curves.easeInBack.transform(t);
      final height = (1 - Curves.easeInCubic.transform(t)).clamp(0.0, 1.0);
      return ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: height,
          child: Opacity(
            opacity: (1 - t * 1.3).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: scale.clamp(0.0, 2.0),
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        ),
      );
    },
  );
}

/// Fades and lifts a newly opened view into place.
class PolishEntrance extends StatelessWidget {
  const PolishEntrance({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOutBack,
    child: child,
    builder: (context, t, child) => Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.translate(offset: Offset(0, 28 * (1 - t)), child: child),
    ),
  );
}

/// Page title that rolls: the old text slides up and out while the new one
/// rises from below.
class PolishRollingTitle extends StatelessWidget {
  const PolishRollingTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => ClipRect(
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) {
        final incoming = child.key == ValueKey(text);
        final slide = Tween(
          begin: Offset(0, incoming ? 1 : -1),
          end: Offset.zero,
        ).animate(animation);
        return SlideTransition(
          position: slide,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: Text(text, key: ValueKey(text)),
    ),
  );
}
