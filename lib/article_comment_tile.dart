import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'app_store.dart';
import 'design.dart';
import 'profile_avatar.dart';
import 'resume_updated_label.dart';
import 'user_display_name.dart';

class ArticleCommentTile extends StatelessWidget {
  const ArticleCommentTile({
    super.key,
    required this.comment,
    required this.articleAuthorID,
    this.currentUserID = 0,
    this.nested = false,
    this.onReply,
    this.onLike,
    this.onDislike,
    this.pending = false,
  });
  final ArticleComment comment;
  final int articleAuthorID, currentUserID;
  final bool nested;
  final VoidCallback? onReply, onLike, onDislike;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final isAuthor =
        !comment.deleted &&
        articleAuthorID > 0 &&
        comment.authorID == articleAuthorID;
    final isOwn =
        !comment.deleted &&
        currentUserID > 0 &&
        comment.authorID == currentUserID;
    final actionStyle = TextButton.styleFrom(
      foregroundColor: (context.isDark
          ? context.colors.muted
          : const Color(0xFF878B93)),
      overlayColor: Colors.transparent,
      minimumSize: const Size(30, 26),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: TextStyle(
        fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    ).withoutHover();
    Widget reaction(bool dislike) {
      final active = dislike ? comment.disliked : comment.liked;
      final count = dislike ? comment.dislikes : comment.likes;
      final color = active ? blue : const Color(0xFF9B9FA7);
      return TextButton(
        key: ValueKey('comment-${dislike ? 'dislike' : 'like'}-${comment.id}'),
        onPressed: pending ? null : (dislike ? onDislike : onLike),
        style: actionStyle,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              dislike ? AppIcons.thumbDown : AppIcons.thumbUp,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              count > 0 ? '$count' : (dislike ? '踩' : '赞'),
              style: TextStyle(color: color, fontSize: 11),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: comment.deleted
                ? Container(
                    width: nested ? 24 : 32,
                    height: nested ? 24 : 32,
                    color: context.colors.canvas,
                    child: Center(
                      child: AppIcon(
                        AppIcons.comment,
                        color: context.colors.muted,
                        size: 16,
                      ),
                    ),
                  )
                : ProfileAvatar(
                    seed: comment.authorID > 0
                        ? '${comment.authorID}'
                        : comment.author,
                    url: comment.avatarURL,
                    size: nested ? 24 : 32,
                  ),
          ),
          SizedBox(width: nested ? 8 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!comment.deleted) ...[
                  Row(
                    children: [
                      Flexible(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: userDisplayName(comment.author)),
                              if (nested && comment.replyToName.isNotEmpty) ...[
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    child: Icon(
                                      Icons.chevron_right_rounded,
                                      size: 12,
                                      color: (context.isDark
                                          ? context.colors.muted
                                          : Color(0xFFB4B6BA)),
                                    ),
                                  ),
                                ),
                                TextSpan(
                                  text: userDisplayName(comment.replyToName),
                                ),
                              ],
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: (context.isDark
                                ? context.colors.muted
                                : Color(0xFF93969C)),
                            fontSize: 12,
                            height: 1.25,
                          ),
                        ),
                      ),
                      if (isAuthor || isOwn) ...[
                        const SizedBox(width: 6),
                        Container(
                          key: ValueKey(
                            'comment-${isAuthor ? 'author' : 'own'}-${comment.id}',
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: (context.isDark
                                ? context.colors.inset
                                : const Color(0xFFF1F2F4)),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            isAuthor ? '作者' : '我',
                            style: TextStyle(
                              fontSize: 9,
                              color: (context.isDark
                                  ? context.colors.muted
                                  : Color(0xFF8F939A)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                ],
                GestureDetector(
                  key: ValueKey('comment-conversation-${comment.id}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: comment.deleted ? null : onReply,
                  child: Text(
                    comment.deleted ? '该评论已删除' : comment.content,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: comment.deleted
                          ? context.colors.muted
                          : (context.isDark
                                ? context.colors.ink
                                : const Color(0xFF24262B)),
                    ),
                  ),
                ),
                if (!comment.deleted) ...[
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (comment.createdAt != null)
                        Text(
                          resumeUpdatedLabel(comment.createdAt!),
                          style: TextStyle(
                            fontSize: 10.5,
                            color: (context.isDark
                                ? context.colors.muted
                                : Color(0xFFB0B3B9)),
                          ),
                        ),
                      if (onReply != null)
                        TextButton(
                          onPressed: onReply,
                          style: actionStyle,
                          child: const Text('回复'),
                        ),
                      if (onLike != null) reaction(false),
                      if (onDislike != null) reaction(true),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
