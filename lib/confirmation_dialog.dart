import 'package:flutter/cupertino.dart';

/// Use the resume deletion dialog's presentation for every app confirmation.
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = false,
}) => showCupertinoDialog<T>(
  context: context,
  barrierDismissible: barrierDismissible,
  builder: builder,
);

Future<bool?> showAppConfirmation(
  BuildContext context, {
  required String title,
  Widget? content,
  String confirmLabel = '确定',
  String? cancelLabel = '取消',
  bool destructive = false,
  bool confirmEnabled = true,
  bool barrierDismissible = true,
  Key? dialogKey,
  Key? confirmKey,
  Key? cancelKey,
}) => showAppDialog<bool>(
  context,
  barrierDismissible: barrierDismissible,
  builder: (context) => AppConfirmationDialog(
    key: dialogKey,
    title: title,
    content: content,
    confirmLabel: confirmLabel,
    cancelLabel: cancelLabel,
    destructive: destructive,
    confirmKey: confirmKey,
    cancelKey: cancelKey,
    onConfirm: confirmEnabled ? () => Navigator.pop(context, true) : null,
    onCancel: () => Navigator.pop(context, false),
  ),
);

class AppConfirmationDialog extends StatelessWidget {
  const AppConfirmationDialog({
    super.key,
    required this.title,
    required this.onConfirm,
    this.content,
    this.confirmLabel = '确定',
    this.cancelLabel = '取消',
    this.onCancel,
    this.destructive = false,
    this.confirmKey,
    this.cancelKey,
  });

  final String title;
  final Widget? content;
  final String confirmLabel;
  final String? cancelLabel;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool destructive;
  final Key? confirmKey;
  final Key? cancelKey;

  @override
  Widget build(BuildContext context) => CupertinoAlertDialog(
    title: Text(title),
    content: content,
    actions: [
      if (cancelLabel != null)
        CupertinoDialogAction(
          key: cancelKey,
          onPressed: onCancel,
          child: Text(cancelLabel!),
        ),
      CupertinoDialogAction(
        key: confirmKey,
        isDestructiveAction: destructive,
        onPressed: onConfirm,
        child: Text(confirmLabel),
      ),
    ],
  );
}
