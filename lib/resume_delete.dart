import 'package:flutter/cupertino.dart';

import 'app_store.dart';
import 'confirmation_dialog.dart';

Future<void> confirmResumeDeletion(
  BuildContext context, {
  required AppStore store,
  required ResumeDraft resume,
}) => showAppDialog<void>(
  context,
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
    child: AppConfirmationDialog(
      title: '删除这份简历？',
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
      confirmLabel: deleting ? '删除中…' : '删除',
      destructive: true,
      onConfirm: deleting ? null : remove,
      onCancel: deleting ? null : () => Navigator.pop(context),
    ),
  );
}
