import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'design.dart';

const _deletionRed = Color(0xFFB75B5B);

Future<bool?> showAccountDeletionSheet(BuildContext context) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 560),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _AccountDeletionSheet(),
    );

class _AccountDeletionSheet extends StatefulWidget {
  const _AccountDeletionSheet();
  @override
  State<_AccountDeletionSheet> createState() => _AccountDeletionSheetState();
}

class _AccountDeletionSheetState extends State<_AccountDeletionSheet> {
  final phrase = TextEditingController();
  @override
  void dispose() {
    phrase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '注销账号',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
              ),
              IconButton(
                tooltip: '关闭',
                onPressed: () => Navigator.pop(context, false),
                icon: const AppIcon(AppIcons.close, size: 20, color: muted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F3F2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Text(
                  '30',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: _deletionRed,
                  ),
                ),
                SizedBox(width: 6),
                Text('天', style: TextStyle(fontSize: 12, color: _deletionRed)),
                SizedBox(width: 18),
                Expanded(
                  child: Text(
                    '注销申请将在 30 天后执行',
                    style: TextStyle(fontSize: 13, height: 1.5, color: ink),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '提交申请后，所有设备都会退出登录。注销完成后，账号及相关数据将被删除。',
            style: TextStyle(fontSize: 13, height: 1.7, color: ink),
          ),
          const SizedBox(height: 24),
          const Text(
            '输入“我已确认并主动注销此账号”',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: phrase,
            style: const TextStyle(fontSize: 14, color: ink),
            decoration: const InputDecoration(
              hintText: '我已确认并主动注销此账号',
              hintStyle: TextStyle(fontSize: 14, color: muted),
            ),
          ),
          const SizedBox(height: 20),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: phrase,
            builder: (_, value, _) => SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _deletionRed,
                  disabledBackgroundColor: const Color(0xFFF2E9E8),
                  disabledForegroundColor: const Color(0xFFB69C99),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onPressed: value.text.trim() == '我已确认并主动注销此账号'
                    ? () => Navigator.pop(context, true)
                    : null,
                child: const Text('申请注销'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                '暂不注销',
                style: TextStyle(color: muted, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
