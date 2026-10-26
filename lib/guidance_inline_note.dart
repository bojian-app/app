import 'app_theme.dart';
import 'content_moderation.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'resume_guidance_review.dart';

bool _canDecide(Map record) =>
    contentVisible(record) &&
    (record['status'] ?? 'PENDING') == 'PENDING' &&
    record['legacy'] != true;

class _NoteMetrics {
  _NoteMetrics(BuildContext context, double paperScale)
    : scaler = MediaQuery.textScalerOf(context),
      direction = Directionality.of(context),
      text = TextStyle(
        fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
        fontSize: math.max(7.5, 10.5 * paperScale),
        height: 1.38,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        wordSpacing: 0,
      );

  final TextScaler scaler;
  final TextDirection direction;
  final TextStyle text;
  static const padding = EdgeInsets.symmetric(vertical: 2);
  static const cardPadding = EdgeInsets.fromLTRB(8, 5, 8, 3);
  static const reasonGap = 2.0, actionGap = 1.0, buttonGap = 8.0;
  TextStyle get reason =>
      text.copyWith(fontSize: math.max(7, text.fontSize! - .5));
  TextStyle get action => text.copyWith(
    fontSize: math.max(8, text.fontSize!),
    height: 1.25,
    fontWeight: FontWeight.w500,
  );

  Size measure(String value, TextStyle style, double width) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: direction,
      textScaler: scaler,
    )..layout(maxWidth: math.max(1, width));
    final size = painter.size;
    painter.dispose();
    return size;
  }

  double buttonWidth(String label) =>
      math.max(40, measure(label, action, double.infinity).width + 8);
  double get actionHeight =>
      math.max(28, measure('不采纳', action, double.infinity).height + 8);
  double actionsHeight(double width) =>
      buttonWidth('不采纳') + buttonWidth('采纳') + buttonGap <= width
      ? actionHeight
      : actionHeight * 2 + reasonGap;
}

// Measure exactly the typography and spacing rendered by GuidanceInlineNote.
double guidanceNoteHeight(
  BuildContext context,
  Map record,
  double width, {
  bool canDecide = true,
  double paperScale = 1,
}) {
  final metrics = _NoteMetrics(context, paperScale);
  final replacement = '${record['replacement'] ?? ''}';
  final comment = '${record['suggestion'] ?? ''}';
  final contentWidth = math.max(
    1.0,
    width - (replacement.isNotEmpty ? _NoteMetrics.cardPadding.horizontal : 0),
  );
  var height =
      _NoteMetrics.padding.vertical +
      (replacement.isNotEmpty ? _NoteMetrics.cardPadding.vertical : 0) +
      metrics
          .measure(
            replacement.isEmpty ? comment : replacement,
            metrics.text,
            contentWidth,
          )
          .height;
  if (replacement.isNotEmpty) {
    if (comment.isNotEmpty) {
      height +=
          _NoteMetrics.reasonGap +
          metrics.measure(comment, metrics.reason, contentWidth).height;
    }
    height +=
        _NoteMetrics.actionGap +
        (_canDecide(record) && canDecide
            ? metrics.actionsHeight(contentWidth)
            : metrics
                  .measure(
                    _statusText(record, canDecide),
                    metrics.reason,
                    contentWidth,
                  )
                  .height);
  }
  return height;
}

String _statusText(Map record, bool canDecide) => record['legacy'] == true
    ? '早期建议，可在简历编辑页中调整。'
    : !canDecide && _canDecide(record)
    ? '等待作者确认'
    : record['status'] == 'ACCEPTED'
    ? '已采纳'
    : '未采纳';

class GuidanceInlineNote extends StatelessWidget {
  const GuidanceInlineNote({
    super.key,
    required this.record,
    required this.onDecide,
    this.busy = false,
    this.disabled = false,
    this.active = false,
    this.canDecide = true,
    this.paperScale = 1,
  });
  final Map<String, dynamic> record;
  final void Function(bool) onDecide;
  final bool busy, disabled, active, canDecide;
  final double paperScale;

  @override
  Widget build(BuildContext context) {
    final metrics = _NoteMetrics(context, paperScale);
    final replacement = '${record['replacement'] ?? ''}';
    final comment = '${record['suggestion'] ?? ''}';
    final modifying = replacement.isNotEmpty;
    final color = modifying ? guidanceReplacementColor : guidanceCommentColor;
    final buttonStyle = TextButton.styleFrom(
      foregroundColor: color,
      disabledForegroundColor: color.withValues(alpha: .35),
      overlayColor: Colors.transparent,
      minimumSize: Size(0, metrics.actionHeight),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: metrics.action,
    ).withoutHover();
    Widget decision(bool accept) => SizedBox(
      width: metrics.buttonWidth(accept ? '采纳' : '不采纳'),
      height: metrics.actionHeight,
      child: TextButton(
        key: ValueKey(accept ? 'tour-accept' : 'tour-reject'),
        onPressed: disabled || busy ? null : () => onDecide(accept),
        style: accept
            ? buttonStyle
            : buttonStyle.copyWith(
                foregroundColor: const WidgetStatePropertyAll(
                  Color(0xFF94969E),
                ),
              ),
        child: busy && accept
            ? SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.3,
                  color: color,
                ),
              )
            : Text(accept ? '采纳' : '不采纳', textScaler: metrics.scaler),
      ),
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          modifying ? replacement : comment,
          textScaler: metrics.scaler,
          style: metrics.text.copyWith(color: color),
        ),
        if (modifying && comment.isNotEmpty) ...[
          const SizedBox(height: _NoteMetrics.reasonGap),
          Text(
            comment,
            textScaler: metrics.scaler,
            style: metrics.reason.copyWith(color: color.withValues(alpha: .75)),
          ),
        ],
        if (modifying) ...[
          const SizedBox(height: _NoteMetrics.actionGap),
          if (_canDecide(record) && canDecide)
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: _NoteMetrics.buttonGap,
                runSpacing: _NoteMetrics.reasonGap,
                children: [decision(false), decision(true)],
              ),
            )
          else
            Text(
              _statusText(record, canDecide),
              textScaler: metrics.scaler,
              style: metrics.reason.copyWith(
                color: color.withValues(alpha: .75),
              ),
            ),
        ],
      ],
    );
    return Semantics(
      label: modifying ? '改写建议' : '评论',
      child: modifying
          ? Padding(
              padding: _NoteMetrics.padding,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: DecoratedBox(
                  key: const ValueKey('guidance-rewrite-card'),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F6FC),
                    border: Border.all(
                      color: guidanceReplacementColor.withValues(alpha: .12),
                      width: .5,
                    ),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: SingleChildScrollView(
                    padding: _NoteMetrics.cardPadding,
                    child: content,
                  ),
                ),
              ),
            )
          : SingleChildScrollView(
              padding: _NoteMetrics.padding,
              child: content,
            ),
    );
  }
}
