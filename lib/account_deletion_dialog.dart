import 'package:flutter/cupertino.dart';

import 'confirmation_dialog.dart';

Future<bool?> showAccountDeletionDialog(BuildContext context) =>
    showAppDialog<bool>(
      context,
      barrierDismissible: true,
      builder: (_) => const _AccountDeletionDialog(),
    );

class _AccountDeletionDialog extends StatefulWidget {
  const _AccountDeletionDialog();

  @override
  State<_AccountDeletionDialog> createState() => _AccountDeletionDialogState();
}

class _AccountDeletionDialogState extends State<_AccountDeletionDialog> {
  static const confirmationPhrase = '我已确认并主动注销此账号';
  final phrase = TextEditingController();

  @override
  void dispose() {
    phrase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: phrase,
        builder: (context, value, _) => AppConfirmationDialog(
          title: '注销账号',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '注销申请将在 30 天后执行',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const Text('提交申请后，所有设备都会退出登录。注销完成后，账号及相关数据将被删除。'),
              const SizedBox(height: 12),
              const Text('输入“$confirmationPhrase”'),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: phrase,
                placeholder: confirmationPhrase,
                style: const TextStyle(fontSize: 14),
                padding: const EdgeInsets.all(10),
              ),
            ],
          ),
          cancelLabel: '暂不注销',
          confirmLabel: '申请注销',
          destructive: true,
          onCancel: () => Navigator.pop(context, false),
          onConfirm: value.text.trim() == confirmationPhrase
              ? () => Navigator.pop(context, true)
              : null,
        ),
      );
}
