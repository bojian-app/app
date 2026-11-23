import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'design.dart';

enum ArticleNotice {
  ai('含 AI 生成内容'),
  fiction('含虚构内容'),
  promotion('含营销信息'),
  minors('含可能影响未成年人的内容'),
  publicAffairs('涉及时事、公共政策或社会事件'),
  opinion('个人观点，仅供参考'),
  repost('内容为转载，来源见正文'),
  none('无需标注');

  const ArticleNotice(this.label);
  final String label;
}

typedef ArticleDeclaration = ({bool original, ArticleNotice notice});

ArticleDeclaration readArticleDeclaration(Map<String, dynamic> content) {
  final data = content['declaration'];
  return (
    original: data is Map && data['original'] == true,
    notice: ArticleNotice.values.firstWhere(
      (entry) => data is Map && entry.name == data['type'],
      orElse: () => ArticleNotice.none,
    ),
  );
}

extension ArticleDeclarationText on ArticleDeclaration {
  String get label => [
    if (original) '作者声明原创',
    if (notice != ArticleNotice.none) notice.label,
  ].join(' · ');
}

class ArticleDeclarationLabel extends StatelessWidget {
  const ArticleDeclarationLabel(this.content, {super.key});
  final Map<String, dynamic> content;

  @override
  Widget build(BuildContext context) {
    final label = readArticleDeclaration(content).label;
    if (label.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        label,
        style: TextStyle(color: context.colors.muted, fontSize: 12),
      ),
    );
  }
}

Future<ArticleDeclaration?> editArticleDeclaration(
  BuildContext context,
  ArticleDeclaration initial,
) => showModalBottomSheet<ArticleDeclaration>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: context.colors.surface,
  builder: (_) => _DeclarationSheet(initial),
);

class _DeclarationSheet extends StatefulWidget {
  const _DeclarationSheet(this.initial);
  final ArticleDeclaration initial;

  @override
  State<_DeclarationSheet> createState() => _DeclarationSheetState();
}

class _DeclarationSheetState extends State<_DeclarationSheet> {
  late bool original = widget.initial.original;
  late ArticleNotice notice = widget.initial.notice;

  void explain() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      builder: (context) => _SheetFrame(
        title: '内容说明',
        action: '关闭',
        onPressed: () => Navigator.pop(context),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: const [
            Text('选择最能说明这篇动态的标注。发布后，读者会在标题下方看到你的声明。'),
            SizedBox(height: 20),
            Text('原创与转载', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text('分享自己撰写的经历或观点时，可以开启原创声明。转载他人的作品时，请选择转载标注，并在正文写明作者和来源。'),
            SizedBox(height: 20),
            Text('如何选择标注', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text(
              '例如，使用 AI 生成面试示例，可选择「含 AI 生成内容」。分享个人求职判断，可选择「个人观点，仅供参考」。没有合适的标注时，可选择「无需标注」。',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _SheetFrame(
    title: '内容声明',
    action: '确定',
    onPressed: () =>
        Navigator.pop(context, (original: original, notice: notice)),
    child: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('这是我的原创内容'),
          value: original,
          onChanged: (value) => setState(() {
            original = value;
            if (value && notice == ArticleNotice.repost) {
              notice = ArticleNotice.none;
            }
          }),
        ),
        const Divider(),
        Row(
          children: [
            const Expanded(
              child: Text(
                '内容标注',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(onPressed: explain, child: const Text('查看说明')),
          ],
        ),
        RadioGroup<ArticleNotice>(
          groupValue: notice,
          onChanged: (value) => setState(() {
            if (value == null) return;
            notice = value;
            if (value == ArticleNotice.repost) original = false;
          }),
          child: Column(
            children: [
              for (final item in ArticleNotice.values)
                RadioListTile<ArticleNotice>(
                  value: item,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(item.label),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.title,
    required this.child,
    required this.action,
    required this.onPressed,
  });
  final String title, action;
  final Widget child;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .78,
    child: SafeArea(
      top: false,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '关闭面板',
                  onPressed: () => Navigator.pop(context),
                  icon: const AppIcon(AppIcons.close, size: 18),
                ),
              ],
            ),
          ),
          Expanded(child: child),
          const Divider(height: 1),
          SizedBox(
            width: double.infinity,
            child: TextButton(onPressed: onPressed, child: Text(action)),
          ),
        ],
      ),
    ),
  );
}
