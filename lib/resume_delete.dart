import 'package:flutter/cupertino.dart';

import 'app_store.dart';

Future<void> confirmResumeDeletion(
  BuildContext context, {
  required AppStore store,
  required ResumeDraft resume,
}) => showCupertinoDialog<void>(
  context: context,
  builder: (_) => _DeleteResumeDialog(store: store, resume: resume),
);

class _DeleteResumeDialog extends StatefulWidget {
  const _DeleteResumeDialog({required this.store, required this.resume});
  final AppStore store;
  final ResumeDraft resume;

  @override
  State<_DeleteResumeDialog> createState() => _DeleteResumeDialogState();
}

class _DeleteResumeDialogState extends State<_DeleteResumeDialog> {
  bool deleting = false;
  String? error;

  Future<void> remove() async {
    if (deleting) return;
    setState(() {
      deleting = true;
      error = null;
    });
    try {
      await widget.store.deleteResume(widget.resume.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        deleting = false;
        error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !deleting,
    child: CupertinoAlertDialog(
      title: const Text('删除这份简历？'),
      content: Column(
        children: [
          Text('“${widget.resume.title}”将从简历库移除。'),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              style: const TextStyle(color: CupertinoColors.systemRed),
            ),
          ],
        ],
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: deleting ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: deleting ? null : remove,
          child: Text(deleting ? '删除中…' : '删除'),
        ),
      ],
    ),
  );
}
