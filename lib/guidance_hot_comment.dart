import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'app_store.dart';
import 'content_moderation.dart';
import 'design.dart';

Map<String, dynamic>? popularGuidanceComment(
  List<Map<String, dynamic>> comments,
) {
  final visible = comments
      .where(
        (row) =>
            contentVisible(row) &&
            '${row['suggestion'] ?? ''}'.trim().isNotEmpty &&
            '${row['replacement'] ?? ''}'.isEmpty,
      )
      .toList();
  visible.sort((a, b) {
    final likes = integer(b['like_count']).compareTo(integer(a['like_count']));
    return likes != 0 ? likes : integer(a['id']).compareTo(integer(b['id']));
  });
  return visible.firstOrNull;
}

const hotCommentStyle = TextStyle(fontSize: 11, height: 1.4);

double guidanceHotCommentHeight(
  BuildContext context,
  String text,
  double width,
) {
  final painter = TextPainter(
    text: TextSpan(text: '热门评论：$text', style: hotCommentStyle),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 2,
  )..layout(maxWidth: (width - 78).clamp(1, double.infinity));
  final height = painter.height + 12;
  painter.dispose();
  return height < 36 ? 36 : height;
}

class GuidanceHotComment extends StatelessWidget {
  const GuidanceHotComment({
    super.key,
    required this.record,
    required this.onOpen,
    required this.onLike,
    this.busy = false,
  });
  final Map<String, dynamic> record;
  final VoidCallback onOpen;
  final VoidCallback? onLike;
  final bool busy;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              '热门评论：${record['suggestion'] ?? ''}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: hotCommentStyle.copyWith(color: context.colors.muted),
            ),
          ),
        ),
      ),
      const SizedBox(width: 6),
      Semantics(
        label: '${integer(record['like_count'])}个赞',
        child: TextButton(
          key: ValueKey('hot-comment-like-${record['id']}'),
          onPressed: busy ? null : onLike,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: const Size(44, 36),
            foregroundColor: record['liked'] == true
                ? context.colors.accent
                : context.colors.muted,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(
                AppIcons.like,
                size: 12,
                color: record['liked'] == true
                    ? context.colors.accent
                    : context.colors.muted,
              ),
              const SizedBox(width: 4),
              Text('${integer(record['like_count'])}', style: hotCommentStyle),
            ],
          ),
        ),
      ),
    ],
  );
}
