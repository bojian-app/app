import 'package:flutter/material.dart';

import 'app_store.dart';
import 'design.dart';

const reportReasons = <String, String>{
  'SPAM': '广告或垃圾信息',
  'ABUSE': '辱骂、骚扰或歧视',
  'PORNOGRAPHY': '色情或低俗内容',
  'VIOLENCE': '暴力或违法犯罪',
  'MISINFORMATION': '谣言或虚假信息',
  'PRIVACY': '泄露隐私或侵权',
  'OTHER': '其他违规内容',
};

Future<void> showReportBubble(
  BuildContext context,
  Offset position,
  VoidCallback onReport,
) async {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final point = overlay.globalToLocal(position);
  final selected = await showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromCenter(center: point, width: 1, height: 1),
      Offset.zero & overlay.size,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    items: const [
      PopupMenuItem(
        value: 'report',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_outlined, size: 19),
            SizedBox(width: 10),
            Text('举报'),
          ],
        ),
      ),
    ],
  );
  if (selected == 'report' && context.mounted) onReport();
}

Future<void> reportContent(
  BuildContext context, {
  required AppStore store,
  required String subjectType,
  required int subjectID,
}) async {
  if (!store.isAuthenticated) {
    toast(context, '请先登录后举报');
    return;
  }
  dismissKeyboard();
  final submitted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _ReportForm(
      store: store,
      subjectType: subjectType,
      subjectID: subjectID,
    ),
  );
  if (submitted == true && context.mounted) {
    toast(context, '举报已提交，我们会尽快核查');
  }
}

class ReportArticleButton extends StatelessWidget {
  const ReportArticleButton({
    super.key,
    required this.store,
    required this.articleID,
  });
  final AppStore store;
  final int articleID;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: '更多操作',
    icon: const Icon(Icons.more_horiz),
    onSelected: (_) => reportContent(
      context,
      store: store,
      subjectType: 'ARTICLE',
      subjectID: articleID,
    ),
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'report', child: Text('举报文章')),
    ],
  );
}

class _ReportForm extends StatefulWidget {
  const _ReportForm({
    required this.store,
    required this.subjectType,
    required this.subjectID,
  });
  final AppStore store;
  final String subjectType;
  final int subjectID;

  @override
  State<_ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<_ReportForm> {
  final description = TextEditingController();
  String? reason, error;
  bool sending = false;

  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (sending || reason == null) return;
    setState(() {
      sending = true;
      error = null;
    });
    try {
      await widget.store.request(
        'PostReports',
        body: {
          'subject_type': widget.subjectType,
          'subject_id': widget.subjectID,
          'reason_code': reason,
          'description': description.text.trim(),
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !sending,
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '举报内容',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '请选择举报原因，举报人的信息不会向对方展示。',
            style: TextStyle(color: context.colors.muted),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: reportReasons.entries
                .map(
                  (entry) => ChoiceChip(
                    label: Text(entry.value),
                    selected: reason == entry.key,
                    onSelected: sending
                        ? null
                        : (_) => setState(() => reason = entry.key),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: description,
            enabled: !sending,
            minLines: 2,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: '补充说明（选填）',
              border: OutlineInputBorder(),
            ),
          ),
          if (error != null) ...[
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 8),
          ],
          FilledButton(
            onPressed: sending || reason == null ? null : submit,
            child: Text(sending ? '正在提交…' : '提交举报'),
          ),
        ],
      ),
    ),
  );
}
