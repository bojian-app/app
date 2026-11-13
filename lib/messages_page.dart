import 'app_page_bar.dart';

import 'dart:async';

import 'user_display_name.dart';
import 'playful_refresh.dart';
import 'profile_avatar.dart';

import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'app_store.dart';
import 'design.dart';
import 'my_articles_page.dart';
import 'resume_updated_label.dart';
import 'resume_pages.dart';
import 'discovery.dart';
import 'membership_page.dart';
import 'resume_guidance_view.dart';
import 'resume_guidance_review.dart';
import 'user_profile_page.dart';

String messageTime(Object? value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  return date == null ? '' : resumeUpdatedLabel(date).replaceFirst('今天 ', '');
}

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key, required this.store, this.standalone = false});
  final bool standalone;
  final AppStore store;
  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  bool marking = false;
  @override
  void initState() {
    super.initState();
    if (widget.standalone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.store.alive || !widget.store.isAuthenticated) {
          return;
        }
        unawaited(widget.store.load('messages'));
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final store = widget.store;
      const section = 'messages';
      final empty = store.inbox.isEmpty;
      _markPassiveRead(store);
      final divider = Divider(
        height: 1,
        indent: appPageHorizontalPadding + 56,
        endIndent: appPageHorizontalPadding,
        color: context.isDark ? context.colors.border : const Color(0xFFF0F2F5),
      );
      const gutter = EdgeInsets.symmetric(horizontal: appPageHorizontalPadding);
      final content = AutoPaginate.section(
        store: store,
        section: section,
        child: PlayfulRefresh(
          hasError: () => store.errors[section] != null,
          onRefresh: () => store.load(section),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (!widget.standalone)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    appPageHorizontalPadding,
                    18,
                    appPageHorizontalPadding,
                    8,
                  ),
                  child: SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '消息',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -.5,
                            ),
                          ),
                        ),
                        _markAllReadButton(store),
                      ],
                    ),
                  ),
                ),
              if (store.loading.contains(section) && empty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              if (store.errors[section] != null)
                _status(
                  AppIcons.error,
                  store.errors[section]!,
                  action: '重新加载',
                  onTap: () => store.load(section),
                ),
              if (empty &&
                  !store.loading.contains(section) &&
                  store.errors[section] == null)
                Padding(padding: gutter, child: const EmptyState('暂无系统通知', '')),
              for (var i = 0; i < store.inbox.length; i++) ...[
                if (i > 0) divider,
                _notification(store.inbox[i]),
              ],
              PageLoadingFooter(visible: store.loadingMore.contains(section)),
            ],
          ),
        ),
      );
      return widget.standalone
          ? Scaffold(
              backgroundColor: context.colors.surface,
              appBar: AppPageBar(
                backgroundColor: context.colors.surface,
                title: const Text('消息'),
                actions: [_markAllReadButton(store)],
              ),
              body: content,
            )
          : content;
    },
  );

  Widget _markAllReadButton(AppStore store) => IconButton(
    tooltip: '系统通知全部已读',
    icon: AppIcon(AppIcons.readAll, size: 23, color: context.colors.muted),
    onPressed:
        !store.isAuthenticated || marking || store.notificationUnreadCount == 0
        ? null
        : () async {
            setState(() => marking = true);
            await runRequest(
              context,
              store.markAllRead,
              success: '系统通知已全部标为已读',
            );
            if (mounted) setState(() => marking = false);
          },
  );

  Widget _status(
    AppIconData icon,
    String title, {
    String? action,
    VoidCallback? onTap,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 62),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(22),
          ),
          child: AppIcon(icon, size: 32, color: context.colors.muted),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.muted, fontSize: 14),
        ),
        if (action != null) TextButton(onPressed: onTap, child: Text(action)),
      ],
    ),
  );

  Widget _guidanceTypeBadge(String type) {
    final label = switch (type) {
      'COMMENT' => '评论',
      'REWRITE' => '改写',
      'REPLY' => '回复',
      'MIXED' => '评论·改写',
      _ => '优化建议',
    };
    final color = type == 'REWRITE'
        ? guidanceReplacementColor
        : type == 'MIXED' || type == 'GUIDANCE'
        ? blue
        : guidanceCommentColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          height: 1.2,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// Icon and tint that tell a notification's kind at a glance.
  (AppIconData, Color) _kind(InboxItem item) => switch (item.type) {
    'RESUME_CREATED' => (AppIcons.resume, context.colors.accent),
    'MEMBERSHIP_BENEFIT' => (AppIcons.wallet, const Color(0xFFD9A441)),
    'ARTICLE_APPROVED' => (AppIcons.done, _green),
    'ARTICLE_LIKE' => (AppIcons.like, const Color(0xFFF0587A)),
    'ARTICLE_COMMENT' ||
    'COMMENT_REPLY' ||
    'RESUME_GUIDANCE' => (AppIcons.comment, context.colors.accent),
    'RESUME_CREATION_FAILED' ||
    'ARTICLE_REJECTED' ||
    'CONTENT_REJECTED' => (AppIcons.alert, const Color(0xFFF08A24)),
    _ => (AppIcons.notification, context.colors.accent),
  };

  static const _green = Color(0xFF1FAF7A);

  Widget _unreadDot({required bool visible, required Widget child}) => Stack(
    clipBehavior: Clip.none,
    children: [
      child,
      if (visible)
        Positioned(
          top: -1,
          right: -1,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: const Color(0xFFFF4D4F),
              shape: BoxShape.circle,
              border: Border.all(color: context.colors.surface, width: 2),
            ),
          ),
        ),
    ],
  );

  Widget _notification(InboxItem item) {
    final actionable = _actionable(item);
    final (icon, tone) = _kind(item);
    final time = messageTime(item.time);
    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: appPageHorizontalPadding,
        vertical: 14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _unreadDot(
            visible: !item.read,
            child: item.type == 'RESUME_GUIDANCE_FEEDBACK'
                ? ProfileAvatar(
                    key: ValueKey('notification-actor-avatar-${item.id}'),
                    seed: '${item.actorID}',
                    url: item.actorAvatarURL,
                    size: 44,
                    onTap: item.actorID > 0
                        ? () => openUserProfile(
                            context,
                            store: widget.store,
                            userID: item.actorID,
                          )
                        : null,
                    semanticsLabel: '查看${userDisplayName(item.actorName)}的主页',
                  )
                : Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: context.isDark ? .18 : .1),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: AppIcon(icon, color: tone, size: 22),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: context.colors.ink,
                          fontWeight: item.read
                              ? FontWeight.w500
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (item.type == 'RESUME_GUIDANCE_FEEDBACK' &&
                        item.feedbackType.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _guidanceTypeBadge(item.feedbackType),
                    ],
                    if (time.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
                if (item.body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  // Without a page to open, the list is the only place to
                  // read the message, so it is shown in full.
                  Text(
                    item.body,
                    maxLines: actionable ? 2 : null,
                    overflow: actionable ? TextOverflow.ellipsis : null,
                    style: TextStyle(
                      color: context.colors.muted,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    return actionable
        ? InkWell(onTap: () => _openNotification(item), child: row)
        : row;
  }

  bool _opensResume(InboxItem item) =>
      item.type == 'RESUME_CREATED' &&
      item.subjectType == 'RESUME' &&
      item.subjectID > 0;

  bool _opensGuidance(InboxItem item) =>
      (item.type == 'RESUME_GUIDANCE' ||
          item.type == 'RESUME_GUIDANCE_FEEDBACK' ||
          (item.type == 'CONTENT_REJECTED' &&
              (item.annotationID > 0 ||
                  item.subjectType == 'GUIDANCE_NOTIFICATION'))) &&
      (item.subjectType == 'GUIDANCE_NOTIFICATION' ||
          item.subjectType == 'ARTICLE');

  bool _opensArticle(InboxItem item) =>
      const {
        'ARTICLE_LIKE',
        'ARTICLE_APPROVED',
        'ARTICLE_REJECTED',
        'CONTENT_REJECTED',
        'ARTICLE_COMMENT',
        'COMMENT_REPLY',
      }.contains(item.type) &&
      item.subjectType == 'ARTICLE' &&
      item.subjectID > 0;

  bool _opensWallet(InboxItem item) =>
      item.type == 'MEMBERSHIP_BENEFIT' &&
      item.subjectType == 'MEMBERSHIP_WALLET';

  bool _actionable(InboxItem item) =>
      _opensResume(item) ||
      _opensGuidance(item) ||
      _opensArticle(item) ||
      _opensWallet(item);

  final _passiveReads = <int>{};

  /// Messages with nothing to open count as read once they are listed.
  void _markPassiveRead(AppStore store) {
    final pending = [
      for (final item in store.inbox)
        if (!item.read && !_actionable(item) && _passiveReads.add(item.id))
          item,
    ];
    if (pending.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (final item in pending) {
        try {
          await store.markRead(item);
        } catch (_) {
          // Shown again as unread next time, when the read is retried.
          _passiveReads.remove(item.id);
        }
      }
    });
  }

  Future<void> _openNotification(InboxItem item) async {
    if (_opensWallet(item)) {
      if (!item.read) {
        unawaited(runRequest(context, () => widget.store.markRead(item)));
      }
      await openPage<void>(context, MembershipWalletPage(store: widget.store));
      return;
    }
    if (_opensResume(item)) {
      final epoch = widget.store.epoch;
      await runRequest(context, () async {
        final result = await widget.store.request(
          'GetResumesId',
          path: {'id': '${item.subjectID}'},
        );
        if (!mounted ||
            epoch != widget.store.epoch ||
            !widget.store.isAuthenticated) {
          return;
        }
        if (!item.read) await widget.store.markRead(item);
        if (!mounted ||
            epoch != widget.store.epoch ||
            !widget.store.isAuthenticated) {
          return;
        }
        await openPage(
          context,
          ResumeEditor(store: widget.store, draft: decodeResume(result.data)),
        );
      });
      return;
    }

    if (_opensGuidance(item)) {
      final private = item.subjectType == 'GUIDANCE_NOTIFICATION';
      final guidanceID = item.subjectID > 0 ? item.subjectID : item.id;
      await runRequest(context, () async {
        final result = await widget.store.request(
          private ? 'GetNotificationsIdGuidance' : 'GetArticlesIdGuidance',
          path: {'id': '$guidanceID'},
        );
        if (!mounted) return;
        if (!item.read) await widget.store.markRead(item);
        if (!mounted) return;
        await openPage(
          context,
          ResumeGuidanceView(
            store: widget.store,
            id: guidanceID,
            notification: private,
            initialData: result.data,
            fromNotification: true,
            focusAnnotationID:
                (item.type == 'RESUME_GUIDANCE_FEEDBACK' ||
                    item.type == 'CONTENT_REJECTED')
                ? item.annotationID
                : 0,
            reviewerKey:
                result.data['is_owner'] == true &&
                    item.actorID > 0 &&
                    item.actorID != widget.store.userID
                ? 'user:${item.actorID}'
                : null,
          ),
        );
      });
      return;
    }
    if (_opensArticle(item)) {
      await runRequest(context, () async {
        final result = await widget.store.request(
          'GetArticlesId',
          path: {'id': '${item.subjectID}'},
        );
        if (!mounted) return;
        final story = decodeStory(result.data);
        final guidanceData =
            (item.type == 'ARTICLE_APPROVED' ||
                    item.type == 'CONTENT_REJECTED') &&
                story.hasGuidance
            ? (await widget.store.request(
                'GetArticlesIdGuidance',
                path: {'id': '${item.subjectID}'},
              )).data
            : null;
        if (!mounted) return;
        if (!item.read) {
          await runRequest(context, () => widget.store.markRead(item));
        }
        if (!mounted) return;
        await openPage(
          context,
          item.type == 'ARTICLE_REJECTED'
              ? OwnArticlePreview(
                  store: widget.store,
                  story: story,
                  row: {
                    ...result.data,
                    'status': result.data['status'] ?? 'REJECTED',
                    'review_reason': item.reviewReason,
                  },
                )
              : guidanceData == null
              ? StoryDetail(story: story, store: widget.store)
              : ResumeGuidanceView(
                  store: widget.store,
                  id: item.subjectID,
                  initialData: guidanceData,
                ),
        );
      });
      return;
    }
  }
}
