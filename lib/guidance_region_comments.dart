import 'dart:async';

import 'user_display_name.dart';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'app_store.dart';
import 'profile_avatar.dart';
import 'resume_updated_label.dart';
import 'design.dart';
import 'resume_guidance_annotations.dart';
import 'user_profile_page.dart';

String _commentAuthor(Map? item) {
  final name = '${item?['reviewer_name'] ?? ''}'.trim();
  return userDisplayName(name);
}

Future<void> showRegionComments(
  BuildContext context, {
  required AppStore store,
  required int id,
  required bool notification,
  required bool owner,
  required String fieldPath,
  required String selected,
  required String original,
  List<Map<String, dynamic>> legacyItems = const [],
  ValueChanged<List<Map<String, dynamic>>>? onCommentsLoaded,
  int focusAnnotationID = 0,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  barrierColor: const Color(0x66000000),
  showDragHandle: false,
  builder: (_) => _RegionComments(
    store: store,
    id: id,
    notification: notification,
    owner: owner,
    fieldPath: fieldPath,
    selected: selected,
    original: original,
    legacyItems: legacyItems,
    onCommentsLoaded: onCommentsLoaded,
    focusAnnotationID: focusAnnotationID,
  ),
);

class _RegionComments extends StatefulWidget {
  const _RegionComments({
    required this.store,
    required this.id,
    required this.notification,
    required this.owner,
    required this.fieldPath,
    required this.selected,
    required this.original,
    this.legacyItems = const [],
    this.onCommentsLoaded,
    this.focusAnnotationID = 0,
  });
  final List<Map<String, dynamic>> legacyItems;
  final ValueChanged<List<Map<String, dynamic>>>? onCommentsLoaded;
  final AppStore store;
  final int id;
  final bool notification, owner;
  final int focusAnnotationID;
  final String fieldPath, selected, original;
  @override
  State<_RegionComments> createState() => _RegionCommentsState();
}

class _CommentThread {
  _CommentThread(this.comment);
  final Map<String, dynamic> comment;
  final replies = <Map<String, dynamic>>[];
}

String _commentKey(Map item) =>
    '${item['legacy'] == true ? 'legacy' : 'comment'}:${integer(item['id']) > 0 ? item['id'] : identityHashCode(item)}';

class _RegionCommentsState extends State<_RegionComments>
    with SingleTickerProviderStateMixin {
  final input = TextEditingController();
  final focus = FocusNode();
  final sheet = DraggableScrollableController();
  final expandedThreads = <String>{};
  final focusedComment = GlobalKey();
  bool focusHandled = false;
  bool highlightFocus = true;
  Timer? highlightTimer;
  late final keyboardMotion = AnimationController.unbounded(vsync: this)
    ..addListener(updateKeyboardLayout);
  double targetKeyboardInset = 0, animatedKeyboardInset = 0;
  double restingExtent = .70, sheetHeight = 0;
  double minimumContentHeight = 200;
  bool keyboardSession = false;
  int keyboardTransition = 0;
  String? sendError;
  List<Map<String, dynamic>>? items;
  Map<String, dynamic>? reply;
  String? error, requestKey, lastPayload;
  bool sending = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    highlightTimer?.cancel();
    input.dispose();
    keyboardMotion.dispose();
    focus.dispose();
    sheet.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    if (inset == targetKeyboardInset) return;
    if (inset > 0 && !keyboardSession) {
      // Restore the user's resting height, including a manually dragged sheet.
      restingExtent = sheet.isAttached ? sheet.size : .70;
      keyboardSession = true;
    }
    targetKeyboardInset = inset;
    final transition = ++keyboardTransition;
    WidgetsBinding.instance.scheduleFrameCallback((_) {
      if (!mounted || transition != keyboardTransition) return;
      // IME metrics may arrive every frame. Preserve velocity when retargeting
      // rather than restarting an easing curve for each metric update.
      keyboardMotion.animateWith(
        SpringSimulation(
          const SpringDescription(mass: 1, stiffness: 1600, damping: 80),
          keyboardMotion.value,
          targetKeyboardInset,
          keyboardMotion.velocity,
          tolerance: const Tolerance(distance: .01, velocity: .1),
          snapToEnd: true,
        ),
      );
    });
  }

  void updateKeyboardLayout() {
    animatedKeyboardInset = keyboardMotion.value.clamp(0.0, double.infinity);
    if (keyboardSession && sheet.isAttached && sheetHeight > 0) {
      // The sheet keeps a stable full-screen parent and an opaque bottom.
      // Only lift its top when the IME leaves too little room for comments.
      final height = (restingExtent * sheetHeight).clamp(
        animatedKeyboardInset + minimumContentHeight,
        double.infinity,
      );
      final extent = (height / sheetHeight).clamp(.45, .94);
      if (sheet.size != extent) sheet.jumpTo(extent);
    }
    if (animatedKeyboardInset == 0 && targetKeyboardInset == 0) {
      keyboardSession = false;
    }
    setState(() {});
  }

  List<_CommentThread> get threads {
    final all = items ?? [];
    final byID = {
      for (final item in all)
        if (item['legacy'] != true && integer(item['id']) > 0)
          integer(item['id']): item,
    };
    final groups = <String, _CommentThread>{};
    for (final item in all) {
      var root = item;
      final visited = <String>{_commentKey(item)};
      while (root['legacy'] != true) {
        final parent = byID[integer(root['parent_id'])];
        if (parent == null || !visited.add(_commentKey(parent))) break;
        root = parent;
      }
      final group = groups.putIfAbsent(
        _commentKey(root),
        () => _CommentThread(root),
      );
      if (!identical(item, root)) group.replies.add(item);
    }
    return groups.values.toList();
  }

  void selectReply(Map<String, dynamic> item) {
    if (sending || item['legacy'] == true) return;
    setState(() {
      reply = item;
      sendError = null;
    });
    focus.requestFocus();
  }

  Future<void> load() async {
    try {
      final result = await widget.store.request(
        annotationMethod(widget.notification, 'Get'),
        path: {'id': '${widget.id}'},
      );
      if (!mounted) return;
      setState(() {
        items =
            [...(result.data['items'] as List? ?? []), ...widget.legacyItems]
                .whereType<Map>()
                .map((v) => Map<String, dynamic>.from(v))
                .where((v) {
                  final quote = '${v['selected_text'] ?? ''}';
                  return '${v['replacement'] ?? ''}'.isEmpty &&
                      v['field_path'] == widget.fieldPath &&
                      (widget.selected.isEmpty ||
                          quote == widget.selected ||
                          quote.isEmpty ||
                          widget.selected.contains(quote));
                })
                .toList()
                .reversed
                .toList();
        error = null;
        final targetThread = threads.where(hasFocusTarget).firstOrNull;
        if (targetThread != null && !isFocusTarget(targetThread.comment)) {
          expandedThreads.add(_commentKey(targetThread.comment));
        }
      });
      scheduleCommentFocus();
      widget.onCommentsLoaded?.call(
        (result.data['items'] as List? ?? [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .where((item) => '${item['replacement'] ?? ''}'.isEmpty)
            .toList(),
      );
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  bool isFocusTarget(Map item) =>
      widget.focusAnnotationID > 0 &&
      item['legacy'] != true &&
      integer(item['id']) == widget.focusAnnotationID;

  bool hasFocusTarget(_CommentThread thread) =>
      isFocusTarget(thread.comment) || thread.replies.any(isFocusTarget);

  void scheduleCommentFocus() {
    if (focusHandled || widget.focusAnnotationID <= 0) return;
    focusHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final target = focusedComment.currentContext;
      if (!mounted ||
          target == null ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      final box = target.findRenderObject();
      final viewport = Scrollable.maybeOf(target)?.position.viewportDimension;
      await Scrollable.ensureVisible(
        target,
        alignment:
            box is RenderBox && viewport != null && box.size.height > viewport
            ? 0
            : .15,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 280),
      );
      if (!mounted) return;
      highlightTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => highlightFocus = false);
      });
    });
  }

  Widget commentsSliver(List<_CommentThread> groups) {
    final index = groups.indexWhere(hasFocusTarget);
    if (index < 0) {
      return SliverList.builder(
        itemCount: groups.length,
        itemBuilder: (_, index) => threadRow(groups[index]),
      );
    }
    // Keep the target thread mounted even when earlier threads are offscreen.
    // The surrounding lists retain their order and their lazy construction.
    return SliverMainAxisGroup(
      slivers: [
        if (index > 0)
          SliverList.builder(
            itemCount: index,
            itemBuilder: (_, before) => threadRow(groups[before]),
          ),
        SliverToBoxAdapter(
          key: const ValueKey('notification-comment-thread'),
          child: threadRow(groups[index]),
        ),
        if (index + 1 < groups.length)
          SliverList.builder(
            itemCount: groups.length - index - 1,
            itemBuilder: (_, after) => threadRow(groups[index + 1 + after]),
          ),
      ],
    );
  }

  Future<void> send() async {
    if (sending ||
        input.text.trim().isEmpty ||
        (widget.owner && reply == null)) {
      return;
    }
    final body = <String, dynamic>{
      'field_path': widget.fieldPath,
      'field_value': widget.original,
      'selected_text': reply?['selected_text'] ?? widget.selected,
      'suggestion': input.text.trim(),
      'replacement': '',
      if (reply != null) 'parent_id': reply!['id'],
    };
    final payload = body.toString();
    if (payload != lastPayload) {
      lastPayload = payload;
      requestKey =
          'comment-${widget.id}-${DateTime.now().microsecondsSinceEpoch}';
    }
    final target = reply;
    setState(() {
      sending = true;
      sendError = null;
    });
    final success = await runRequest(
      context,
      () => widget.store.request(
        annotationMethod(widget.notification, 'Post'),
        path: {'id': '${widget.id}'},
        body: body,
        extra: {'idempotency-key': requestKey!},
      ),
    );
    if (!mounted) return;
    setState(() {
      sending = false;
      sendError = success ? null : '发送失败，请重试';
      if (success) {
        if (target != null) {
          for (final thread in threads) {
            if (_commentKey(thread.comment) == _commentKey(target) ||
                thread.replies.any(
                  (item) => _commentKey(item) == _commentKey(target),
                )) {
              expandedThreads.add(_commentKey(thread.comment));
              break;
            }
          }
        }
        input.clear();
        reply = null;
      }
    });
    if (success) {
      focus.unfocus();
      await load();
    }
  }

  Widget commentRow(
    Map<String, dynamic> item, {
    bool nested = false,
    Map<String, dynamic>? parent,
  }) {
    final own =
        integer(item['reviewer_id']) > 0 &&
        integer(item['reviewer_id']) == widget.store.userID;
    final date = DateTime.tryParse(
      '${item['created_at'] ?? item['updated_at'] ?? ''}',
    );
    final row = Padding(
      key: ValueKey(
        'region-${nested ? 'reply' : 'comment'}-${_commentKey(item)}',
      ),
      padding: EdgeInsets.only(top: nested ? 12 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            key: ValueKey('region-avatar-${_commentKey(item)}'),
            child: ProfileAvatar(
              seed: '${item['reviewer_id'] ?? item['id']}',
              url: '${item['reviewer_avatar_url'] ?? ''}',
              size: nested ? 24 : 32,
              onTap: integer(item['reviewer_id']) > 0
                  ? () => openUserProfile(
                      context,
                      store: widget.store,
                      userID: integer(item['reviewer_id']),
                    )
                  : null,
              semanticsLabel: '查看${_commentAuthor(item)}的主页',
            ),
          ),
          SizedBox(width: nested ? 8 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: _commentAuthor(item)),
                            if (nested && parent != null) ...[
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 3),
                                  child: Icon(
                                    Icons.chevron_right_rounded,
                                    size: 12,
                                    color: (context.isDark
                                        ? context.colors.muted
                                        : Color(0xFFB4B6BA)),
                                  ),
                                ),
                              ),
                              TextSpan(text: _commentAuthor(parent)),
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
                    if (own) ...[
                      const SizedBox(width: 6),
                      Container(
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
                          widget.owner ? '作者' : '我',
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
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: sending || item['legacy'] == true
                      ? null
                      : () => selectReply(item),
                  child: Text(
                    '${item['suggestion'] ?? ''}',
                    style: TextStyle(
                      color: (context.isDark
                          ? context.colors.ink
                          : Color(0xFF24262B)),
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (date != null)
                      Text(
                        resumeUpdatedLabel(date),
                        style: TextStyle(
                          fontSize: 10.5,
                          color: (context.isDark
                              ? context.colors.muted
                              : Color(0xFFB0B3B9)),
                        ),
                      ),
                    if (item['legacy'] != true)
                      TextButton(
                        onPressed: sending ? null : () => selectReply(item),
                        style: TextButton.styleFrom(
                          foregroundColor: (context.isDark
                              ? context.colors.muted
                              : const Color(0xFF878B93)),
                          overlayColor: Colors.transparent,
                          minimumSize: const Size(30, 26),
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: TextStyle(
                            fontFamily: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.fontFamily,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ).withoutHover(),
                        child: const Text('回复'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (!isFocusTarget(item)) return row;
    return KeyedSubtree(
      key: focusedComment,
      child: AnimatedContainer(
        key: ValueKey('notification-comment-${widget.focusAnnotationID}'),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: highlightFocus
              ? context.colors.accentSoft
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(padding: const EdgeInsets.all(8), child: row),
      ),
    );
  }

  Widget threadRow(_CommentThread thread) {
    final key = _commentKey(thread.comment);
    final expanded = expandedThreads.contains(key);
    final byID = {
      for (final item in items ?? <Map<String, dynamic>>[])
        if (item['legacy'] != true) integer(item['id']): item,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          commentRow(thread.comment),
          if (thread.replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 42),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (expanded)
                    for (final item in thread.replies)
                      commentRow(
                        item,
                        nested: true,
                        parent: byID[integer(item['parent_id'])],
                      ),
                  TextButton(
                    key: ValueKey('region-thread-toggle-$key'),
                    onPressed: () => setState(
                      () => expanded
                          ? expandedThreads.remove(key)
                          : expandedThreads.add(key),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: (context.isDark
                          ? context.colors.muted
                          : const Color(0xFF7F8897)),
                      overlayColor: Colors.transparent,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: TextStyle(
                        fontFamily: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ).withoutHover(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 18,
                          height: 1,
                          color: (context.isDark
                              ? context.colors.accentSoft
                              : const Color(0xFFD7DADE)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          expanded ? '收起回复' : '展开 ${thread.replies.length} 条回复',
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget composer(double availableHeight) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.colors.surface,
      border: Border(
        top: BorderSide(
          color: (context.isDark ? context.colors.border : Color(0xFFF0F1F3)),
          width: .5,
        ),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reply != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '回复 ${_commentAuthor(reply)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: (context.isDark
                            ? context.colors.muted
                            : Color(0xFF92969E)),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: sending
                        ? null
                        : () {
                            setState(() {
                              reply = null;
                              sendError = null;
                            });
                            if (widget.owner) {
                              focus.unfocus();
                            }
                          },
                    style: TextButton.styleFrom(
                      foregroundColor: (context.isDark
                          ? context.colors.muted
                          : const Color(0xFF92969E)),
                      overlayColor: Colors.transparent,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(56, 24),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: TextStyle(
                        fontFamily: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.fontFamily,
                        fontSize: 11,
                      ),
                    ).withoutHover(),
                    child: const Text('取消回复'),
                  ),
                ],
              ),
            ),
          if (sendError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                sendError!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          if (widget.owner && reply == null)
            Container(
              key: const ValueKey('region-comment-reply-hint'),
              height: 42,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: (context.isDark
                    ? context.colors.inset
                    : const Color(0xFFF4F5F7)),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                '点击评论进行回复',
                style: TextStyle(
                  fontSize: 13,
                  color: (context.isDark
                      ? context.colors.muted
                      : Color(0xFFA7ABB3)),
                ),
              ),
            ),
          if (!widget.owner || reply != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('region-comment-input'),
                    controller: input,
                    focusNode: focus,
                    enabled: !sending,
                    minLines: 1,
                    maxLines: availableHeight < 280 ? 1 : 3,
                    maxLength: 10000,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: (context.isDark
                          ? context.colors.ink
                          : Color(0xFF24262B)),
                    ),
                    scrollPadding: const EdgeInsets.only(bottom: 20),
                    decoration: InputDecoration(
                      hintText: reply == null
                          ? '写下评论…'
                          : '回复 ${_commentAuthor(reply)}…',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: (context.isDark
                            ? context.colors.muted
                            : Color(0xFFA7ABB3)),
                      ),
                      counterText: '',
                      filled: true,
                      fillColor: (context.isDark
                          ? context.colors.inset
                          : const Color(0xFFF4F5F7)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: input,
                  builder: (_, value, _) => FilledButton(
                    key: const ValueKey('region-comment-send'),
                    onPressed: sending || value.text.trim().isEmpty
                        ? null
                        : send,
                    style: FilledButton.styleFrom(
                      backgroundColor: blue,
                      disabledBackgroundColor: (context.isDark
                          ? context.colors.inset
                          : const Color(0xFFF0F1F4)),
                      disabledForegroundColor: (context.isDark
                          ? context.colors.muted
                          : const Color(0xFFB3B7BE)),
                      minimumSize: const Size(52, 42),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(21),
                      ),
                      textStyle: TextStyle(
                        fontFamily: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ).withoutHover(),
                    child: Text(sending ? '发送中' : '发送'),
                  ),
                ),
              ],
            ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final groups = threads;
    return LayoutBuilder(
      builder: (context, constraints) {
        sheetHeight = constraints.maxHeight;
        minimumContentHeight = MediaQuery.textScalerOf(context).scale(200);
        return DraggableScrollableSheet(
          controller: sheet,
          expand: false,
          initialChildSize: .70,
          minChildSize: .45,
          maxChildSize: .94,
          snap: true,
          snapSizes: const [.70],
          builder: (context, scroll) => Material(
            key: const ValueKey('region-comments-panel'),
            color: context.colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              maintainBottomViewPadding: true,
              child: Padding(
                key: const ValueKey('region-comments-keyboard-padding'),
                padding: EdgeInsets.only(
                  bottom:
                      (animatedKeyboardInset -
                              MediaQuery.viewPaddingOf(context).bottom)
                          .clamp(0.0, double.infinity),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) => Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 9, bottom: 3),
                        child: Container(
                          width: 28,
                          height: 3,
                          decoration: BoxDecoration(
                            color: (context.isDark
                                ? context.colors.inset
                                : const Color(0xFFE0E2E5)),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 56,
                              ),
                              child: Text(
                                '评论${items == null ? '' : '（${items!.length}）'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: (context.isDark
                                      ? context.colors.ink
                                      : Color(0xFF24262B)),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 6,
                              child: IconButton(
                                key: const ValueKey('tour-comment-close'),
                                tooltip: '关闭评论',
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                style: IconButton.styleFrom(
                                  overlayColor: Colors.transparent,
                                ).withoutHover(),
                                icon: Icon(
                                  Icons.close,
                                  size: 21,
                                  color: (context.isDark
                                      ? context.colors.ink
                                      : Color(0xFF34363C)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: CustomScrollView(
                          key: const ValueKey('region-comments-list'),
                          controller: scroll,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          slivers: [
                            if (error != null ||
                                items == null ||
                                groups.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: error != null
                                    ? Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(24),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                error!,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: context.colors.muted,
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: load,
                                                child: const Text('重新加载'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    : items == null
                                    ? const Center(
                                        child: SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          '还没有评论，聊聊你的看法',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: (context.isDark
                                                ? context.colors.muted
                                                : Color(0xFFA3A7AF)),
                                          ),
                                        ),
                                      ),
                              )
                            else
                              SliverPadding(
                                padding: const EdgeInsets.only(
                                  top: 2,
                                  bottom: 14,
                                ),
                                sliver: commentsSliver(groups),
                              ),
                          ],
                        ),
                      ),
                      KeyedSubtree(
                        key: const ValueKey('tour-comment-composer'),
                        child: composer(constraints.maxHeight),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
