import 'dart:async';

import 'user_display_name.dart';
import 'playful_refresh.dart';
import 'profile_avatar.dart';

import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'app_store.dart';
import 'chat_history.dart';
import 'design.dart';
import 'my_articles_page.dart';
import 'resume_updated_label.dart';
import 'resume_pages.dart';
import 'discovery.dart';
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
  bool chats = false, marking = false;
  @override
  void initState() {
    super.initState();
    if (widget.standalone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.store.alive || !widget.store.isAuthenticated) {
          return;
        }
        unawaited(widget.store.load('messages'));
        unawaited(widget.store.load('chats'));
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final store = widget.store;
      final section = chats ? 'chats' : 'messages';
      final empty = chats ? store.conversations.isEmpty : store.inbox.isEmpty;
      final content = PlayfulRefresh(
        hasError: () => store.errors[section] != null,
        onRefresh: () => store.load(section),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          children: [
            if (!widget.standalone) ...[
              SizedBox(
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
                    if (!chats) _markAllReadButton(store),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: (context.isDark
                    ? context.colors.accentSoft
                    : const Color(0xFFEDEFF4)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _tab('系统通知', false, store.notificationUnreadCount),
                  _tab(
                    '聊天记录',
                    true,
                    store.conversations.fold<int>(
                      0,
                      (sum, row) => sum + integer(row['unread_count']),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (store.loading.contains(section) && empty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
              _status(
                chats ? AppIcons.messages : AppIcons.notification,
                chats ? '暂无聊天记录' : '暂无系统通知',
              ),
            if (!empty)
              Material(
                color: context.colors.surface,
                clipBehavior: Clip.antiAlias,
                borderRadius: BorderRadius.circular(18),
                child: Column(
                  children: [
                    if (chats)
                      for (var i = 0; i < store.conversations.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            indent: 76,
                            endIndent: 16,
                            color: (context.isDark
                                ? context.colors.border
                                : Color(0xFFEDF1F7)),
                          ),
                        _conversation(store.conversations[i]),
                      ]
                    else
                      for (var i = 0; i < store.inbox.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            indent: 76,
                            endIndent: 16,
                            color: (context.isDark
                                ? context.colors.border
                                : Color(0xFFEDF1F7)),
                          ),
                        _notification(store.inbox[i]),
                      ],
                  ],
                ),
              ),
            if ((store.cursors[section] ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextButton(
                  onPressed: store.loading.contains(section)
                      ? null
                      : () => store.load(section, more: true),
                  child: Text(
                    store.loading.contains(section) ? '加载中…' : '加载更多',
                  ),
                ),
              ),
          ],
        ),
      );
      return widget.standalone
          ? Scaffold(
              appBar: AppBar(
                title: const Text('消息'),
                actions: [if (!chats) _markAllReadButton(store)],
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

  Widget _tab(String title, bool value, int unread) => Expanded(
    child: Material(
      color: chats == value ? context.colors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: () {
          dismissKeyboard();
          setState(() => chats = value);
          final section = value ? 'chats' : 'messages';
          if (!widget.store.loading.contains(section)) {
            widget.store.load(section);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: chats == value
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: chats == value
                        ? context.colors.ink
                        : context.colors.muted,
                  ),
                ),
              ),
              if (unread > 0) ...[const SizedBox(width: 6), _badge(unread)],
            ],
          ),
        ),
      ),
    ),
  );

  Widget _badge(int count) => Container(
    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: blue,
      borderRadius: BorderRadius.circular(9),
    ),
    alignment: Alignment.center,
    child: Text(
      count > 99 ? '99+' : '$count',
      style: const TextStyle(
        fontSize: 10,
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
    ),
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

  Widget _notification(InboxItem item) => InkWell(
    onTap: () => _openNotification(item),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.type == 'RESUME_GUIDANCE_FEEDBACK')
            ProfileAvatar(
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
          else
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (context.isDark
                    ? context.colors.accentSoft
                    : const Color(0xFFEEF4FF)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: AppIcon(
                  item.type == 'ARTICLE_LIKE'
                      ? AppIcons.like
                      : AppIcons.notification,
                  color: context.colors.accent,
                  size: 22,
                ),
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          fontWeight: item.read
                              ? FontWeight.w500
                              : FontWeight.w700,
                        ),
                      ),
                    ),
                    if (item.type == 'RESUME_GUIDANCE_FEEDBACK' &&
                        item.feedbackType.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _guidanceTypeBadge(item.feedbackType),
                    ],
                    if (!item.read) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                if (item.body.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    item.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.colors.muted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
                if (messageTime(item.time).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    messageTime(item.time),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: context.colors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _openNotification(InboxItem item) async {
    if (item.type == 'RESUME_CREATED' &&
        item.subjectType == 'RESUME' &&
        item.subjectID > 0) {
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

    if ((item.type == 'RESUME_GUIDANCE' ||
            item.type == 'RESUME_GUIDANCE_FEEDBACK') &&
        (item.subjectType == 'GUIDANCE_NOTIFICATION' ||
            item.subjectType == 'ARTICLE')) {
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
            focusAnnotationID: item.type == 'RESUME_GUIDANCE_FEEDBACK'
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
    if (const {
          'ARTICLE_LIKE',
          'ARTICLE_APPROVED',
          'ARTICLE_REJECTED',
          'ARTICLE_COMMENT',
          'COMMENT_REPLY',
        }.contains(item.type) &&
        item.subjectType == 'ARTICLE' &&
        item.subjectID > 0) {
      await runRequest(context, () async {
        final result = await widget.store.request(
          'GetArticlesId',
          path: {'id': '${item.subjectID}'},
        );
        if (!mounted) return;
        final story = decodeStory(result.data);
        final guidanceData =
            item.type == 'ARTICLE_APPROVED' && story.hasGuidance
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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .75,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '系统通知',
                  style: TextStyle(fontSize: 12, color: context.colors.accent),
                ),
                const SizedBox(height: 12),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  messageTime(item.time),
                  style: TextStyle(fontSize: 11, color: context.colors.muted),
                ),
                if (item.body.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  SelectableText(
                    item.body,
                    style: const TextStyle(fontSize: 14, height: 1.8),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    if (!item.read) runRequest(context, () => widget.store.markRead(item));
  }

  Widget _conversation(Map<String, dynamic> row) {
    final peer = row['peer'] is Map ? row['peer'] as Map : const {};
    final name = userDisplayName(peer['display_name']);
    final unread = integer(row['unread_count']);
    final summary = row['last_message_id'] == null
        ? '暂无消息'
        : chatMessageText({
            'type': row['last_message_type'],
            'payload': row['last_message_payload'],
          });
    return InkWell(
      onTap: () =>
          openPage(context, ChatPage(store: widget.store, conversation: row)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ProfileAvatar(
              seed: '${peer['id'] ?? name}',
              url: peer['avatar_url']?.toString() ?? '',
              size: 44,
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
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        messageTime(
                          row['last_message_at'] ?? row['updated_at'],
                        ),
                        style: TextStyle(
                          fontSize: 10,
                          color: context.colors.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.muted,
                          ),
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 10),
                        _badge(unread),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.store, required this.conversation});
  final AppStore store;
  final Map<String, dynamic> conversation;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final history = ChatHistory(
    widget.store,
    integer(widget.conversation['id']),
  );
  final input = TextEditingController();
  final scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    history.addListener(_clearExpiredDraft);
    history.load();
  }

  void _clearExpiredDraft() {
    if (!history.valid) input.clear();
  }

  Future<void> _send() async {
    final text = input.text;
    final sent = await history.send(text);
    if (!mounted || !sent) return;
    if (input.text == text) input.clear();
    await widget.store.load('chats');
  }

  @override
  Widget build(BuildContext context) {
    final peer = widget.conversation['peer'] is Map
        ? widget.conversation['peer'] as Map
        : const {};
    final name = userDisplayName(peer['display_name']);
    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          const DismissKeyboardButton(),
          IconButton(
            tooltip: '刷新聊天记录',
            onPressed: () => history.load(),
            icon: const AppIcon(AppIcons.refresh, size: 21),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: history,
        builder: (context, _) => Column(
          children: [
            if (history.error != null || history.readError != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        history.error ?? '未能更新已读状态',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.muted,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: history.loading ? null : () => history.load(),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: PlayfulRefresh(
                onRefresh: () => history.load(),
                hasError: () => history.error != null,
                child: ListView.builder(
                  controller: scroll,
                  reverse: true,
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(16),
                  itemCount: history.messages.length + 1,
                  itemBuilder: (context, index) {
                    if (index < history.messages.length) {
                      return _bubble(
                        history.messages[history.messages.length - index - 1],
                      );
                    }
                    if (history.loading) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    if (history.cursor.isNotEmpty) {
                      return TextButton(
                        onPressed: () => history.load(more: true),
                        child: const Text('查看更早消息'),
                      );
                    }
                    if (history.messages.isEmpty && history.error == null) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 100),
                        child: Center(
                          child: Text(
                            '暂无聊天记录',
                            style: TextStyle(color: context.colors.muted),
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  border: Border(
                    top: BorderSide(
                      color: (context.isDark
                          ? context.colors.border
                          : Color(0xFFEDF1F7)),
                    ),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: input,
                        enabled: history.valid && !history.sending,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 4000,
                        textInputAction: TextInputAction.newline,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: '输入消息',
                          counterText: '',
                          filled: true,
                          fillColor: context.colors.canvas,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: input,
                      builder: (_, value, _) => IconButton.filled(
                        tooltip: '发送消息',
                        onPressed:
                            history.valid &&
                                !history.sending &&
                                value.text.trim().isNotEmpty
                            ? _send
                            : null,
                        icon: history.sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const AppIcon(AppIcons.send, size: 20),
                      ),
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

  Widget _bubble(Map row) {
    final own = integer(row['sender_id']) == widget.store.userID;
    final payload = row['payload'] is Map ? row['payload'] as Map : const {};
    final url = payload['url']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: own
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            messageTime(row['created_at']),
            style: TextStyle(fontSize: 10, color: context.colors.muted),
          ),
          const SizedBox(height: 6),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * .78,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: own ? blue : context.colors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child:
                row['type'] == 'IMAGE' && Uri.tryParse(url)?.scheme == 'https'
                ? Image.network(
                    url,
                    cacheWidth: 540,
                    width: 180,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Text(
                      '[图片无法加载]',
                      style: TextStyle(
                        color: own ? Colors.white : context.colors.muted,
                      ),
                    ),
                  )
                : SelectableText(
                    chatMessageText(row),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: own ? Colors.white : context.colors.ink,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    history.removeListener(_clearExpiredDraft);
    history.dispose();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }
}
