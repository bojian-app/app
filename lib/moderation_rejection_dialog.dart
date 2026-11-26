import 'package:flutter/material.dart';

import 'api/bojian_api.dart';

class ModerationRejectionDialog extends StatelessWidget {
  const ModerationRejectionDialog({
    super.key,
    required this.failure,
    this.canLocate,
  });

  final ApiFailure failure;
  final bool Function(ModerationExcerpt)? canLocate;

  @override
  Widget build(BuildContext context) {
    final violations = failure.violations;
    final hasExcerpts = violations.any((v) => v.excerpts.isNotEmpty);
    return AlertDialog(
      title: const Text('内容未通过审核'),
      scrollable: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!hasExcerpts) const Text('审核结果未提供具体原句。'),
          if (violations.isEmpty) Text(failure.message),
          for (final violation in violations) ...[
            const SizedBox(height: 12),
            Text(violation.message),
            if (hasExcerpts && violation.excerpts.isEmpty)
              const Text('这项审核原因未提供具体原句。'),
            for (final excerpt in violation.excerpts)
              _ExcerptCard(
                excerpt: excerpt,
                canLocate: canLocate?.call(excerpt) ?? false,
              ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('返回修改'),
        ),
      ],
    );
  }
}

class _ExcerptCard extends StatelessWidget {
  const _ExcerptCard({required this.excerpt, required this.canLocate});
  final ModerationExcerpt excerpt;
  final bool canLocate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = excerpt.text;
    final match = excerpt.match;
    final blockIndex = excerpt.blockIndex;
    final label = switch (excerpt.field) {
      'title' => '标题',
      'body' when blockIndex != null && blockIndex >= 0 =>
        '正文 · 第${blockIndex + 1}段',
      'body' => '正文',
      _ => '提交内容',
    };
    final index = match.isEmpty ? -1 : text.indexOf(match);
    final unique = index >= 0 && text.indexOf(match, index + 1) < 0;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: unique
                  ? [
                      TextSpan(text: text.substring(0, index)),
                      TextSpan(
                        text: match,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.error,
                        ),
                      ),
                      TextSpan(text: text.substring(index + match.length)),
                    ]
                  : [TextSpan(text: text)],
            ),
          ),
          if (canLocate)
            TextButton(
              onPressed: () => Navigator.pop(context, excerpt),
              child: const Text('定位原文'),
            ),
        ],
      ),
    );
  }
}
