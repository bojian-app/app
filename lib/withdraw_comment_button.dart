import 'package:flutter/material.dart';

import 'app_store.dart';
import 'confirmation_dialog.dart';
import 'design.dart';

class WithdrawCommentButton extends StatefulWidget {
  const WithdrawCommentButton({
    super.key,
    required this.store,
    required this.method,
    required this.submissionMethod,
    required this.path,
    required this.commentID,
    required this.onWithdrawn,
  });
  factory WithdrawCommentButton.guidance({
    required AppStore store,
    required int id,
    required bool notification,
    required Map<String, dynamic> item,
    required Future<void> Function() onWithdrawn,
  }) {
    final legacy = item['legacy'] == true;
    final scope = notification ? 'Notifications' : 'Articles';
    final commentID = integer(item['id']);
    return WithdrawCommentButton(
      store: store,
      commentID: commentID,
      method: legacy
          ? 'DeleteArticlesIdGuidanceSuggestionsSuggestionId'
          : 'Delete${scope}IdGuidanceAnnotationsAnnotationId',
      submissionMethod: legacy
          ? 'PostArticlesIdGuidanceSuggestions'
          : 'Post${scope}IdGuidanceAnnotations',
      path: {
        'id': '$id',
        (legacy ? 'suggestion_id' : 'annotation_id'): '$commentID',
      },
      onWithdrawn: onWithdrawn,
    );
  }
  final AppStore store;
  final String method, submissionMethod;
  final Map<String, String> path;
  final int commentID;
  final Future<void> Function() onWithdrawn;

  @override
  State<WithdrawCommentButton> createState() => _WithdrawCommentButtonState();
}

class _WithdrawCommentButtonState extends State<WithdrawCommentButton> {
  bool busy = false;

  Future<void> withdraw() async {
    if (busy) return;
    final store = widget.store;
    final session = store.epoch;
    setState(() => busy = true);
    try {
      final confirmed = await showAppConfirmation(
        context,
        title: '撤回这条评论？',
        confirmLabel: '撤回',
        destructive: true,
      );
      if (confirmed != true || !mounted || session != store.epoch) return;
      final action = widget;
      await runRequest(context, () async {
        await store.request(
          action.method,
          path: action.path,
          expectedEpoch: session,
        );
        if (session != store.epoch || !store.alive) return;
        final local = store
            .localContent(
              action.submissionMethod,
              int.parse(action.path['id']!),
            )
            .where((row) => integer(row['id']) == action.commentID)
            .toSet();
        if (local.isNotEmpty) {
          store.contentSubmissions.removeWhere(local.contains);
          await store.saveContentSubmissions();
        }
        if (mounted) await action.onWithdrawn();
      }, success: '评论已撤回');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: busy ? null : withdraw,
    style: TextButton.styleFrom(
      foregroundColor: context.colors.muted,
      minimumSize: const Size(32, 28),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(fontSize: 11),
    ),
    child: const Text('撤回'),
  );
}
