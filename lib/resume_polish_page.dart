import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'app_store.dart';
import 'design.dart';
import 'resume_document.dart';
import 'resume_market_document.dart';
import 'resume_polish.dart';

class ResumePolishPage extends StatefulWidget {
  const ResumePolishPage({
    super.key,
    required this.store,
    required this.resume,
  });
  final AppStore store;
  final ResumeDraft resume;
  @override
  State<ResumePolishPage> createState() => _ResumePolishPageState();
}

class _ResumePolishPageState extends State<ResumePolishPage> {
  late final model = ResumePolishController(widget.store, widget.resume.id);
  final instructions = TextEditingController();
  String direction = '清晰专业';
  static const directions = {
    '清晰专业': '优化语句逻辑，表达清晰、专业，去除口语化与重复表述。',
    '精简表达': '精简冗余措辞，在保留原有事实与关键信息的前提下提高可读性。',
    '突出成果': '突出原文已有的职责、行动和成果，不补充原文未出现的数据或业绩。',
  };
  @override
  void initState() {
    super.initState();
    model.initialize();
  }

  @override
  void dispose() {
    model.dispose();
    instructions.dispose();
    super.dispose();
  }

  void preview() {
    final draft = model.preview;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('优化预览')),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                color: const Color(0xFFEFF4FF),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: const Text(
                  '仅预览已勾选的修改，保存后才会更新简历。',
                  style: TextStyle(fontSize: 12, color: blue),
                ),
              ),
              Expanded(
                child: draft.usesMarketTemplate
                    ? ResumeMarketDocumentView(
                        store: widget.store,
                        resume: draft,
                      )
                    : ResumeDocumentView(store: widget.store, resume: draft),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: model,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('AI 简历优化'),
        actions: [
          if (model.jobID != null && model.phase != ResumePolishPhase.saved)
            TextButton(
              onPressed:
                  (model.busy && model.phase != ResumePolishPhase.generating) ||
                      !model.validSession ||
                      model.cancelRequested
                  ? null
                  : model.discard,
              child: Text(model.cancelRequested ? '正在停止…' : '放弃本次'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.resume.title,
                    style: const TextStyle(fontSize: 13, color: muted),
                  ),
                  const SizedBox(height: 18),
                  if (model.phase == ResumePolishPhase.setup) ...setup(),
                  if (model.phase == ResumePolishPhase.generating)
                    ...generating(),
                  if (model.phase == ResumePolishPhase.review) ...review(),
                  if (model.phase == ResumePolishPhase.saved) ...[
                    const SizedBox(height: 36),
                    const AppIcon(AppIcons.resume, size: 42, color: blue),
                    const SizedBox(height: 20),
                    const Text(
                      '优化已保存',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '所选修改已更新到简历，可返回简历库预览和导出。',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, height: 1.6, color: muted),
                    ),
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('返回简历库'),
                    ),
                  ],
                  if (model.error != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      key: const ValueKey('polish-error'),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3EF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        model.error!,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: Color(0xFF9E5845),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar:
          model.phase == ResumePolishPhase.review && model.changes.isNotEmpty
          ? SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: model.busy || !model.validSession
                          ? null
                          : preview,
                      child: const Text('预览简历'),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('polish-save'),
                        onPressed:
                            model.busy ||
                                model.selected.isEmpty ||
                                model.conflict ||
                                !model.validSession
                            ? null
                            : model.save,
                        child: Text(
                          model.busy
                              ? '正在保存…'
                              : '保存 ${model.selected.length} 项修改',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    ),
  );

  List<Widget> setup() => [
    const Text(
      '让经历表达得更好',
      style: TextStyle(fontSize: 25, fontWeight: FontWeight.w600, height: 1.4),
    ),
    const SizedBox(height: 10),
    const Text(
      '基于已有经历优化措辞。先对比，再由你决定采用哪些修改。',
      style: TextStyle(fontSize: 14, color: muted, height: 1.7),
    ),
    const SizedBox(height: 28),
    const Text(
      '优化方向',
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
    const SizedBox(height: 12),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final title in directions.keys)
          ChoiceChip(
            label: Text(title),
            selected: direction == title,
            onSelected: model.busy
                ? null
                : (_) => setState(() => direction = title),
            showCheckmark: false,
            selectedColor: const Color(0xFFE9F0FF),
            backgroundColor: Colors.white,
            side: BorderSide(
              color: direction == title
                  ? blue.withValues(alpha: .3)
                  : borderColor,
            ),
            labelStyle: TextStyle(color: direction == title ? blue : ink),
          ),
      ],
    ),
    const SizedBox(height: 24),
    const Text(
      '补充要求（选填）',
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
    const SizedBox(height: 12),
    TextField(
      key: const ValueKey('polish-instructions'),
      controller: instructions,
      enabled: !model.busy,
      minLines: 3,
      maxLines: 6,
      maxLength: 800,
      decoration: const InputDecoration(
        hintText: '例如：面向产品经理岗位，精简项目描述，突出已有成果。',
        fillColor: Colors.white,
      ),
    ),
    const SizedBox(height: 16),
    FilledButton(
      key: const ValueKey('polish-start'),
      onPressed: model.busy || !model.validSession
          ? null
          : () => model.start(
              '${directions[direction]}\n${instructions.text.trim()}',
            ),
      child: Text(model.busy ? '正在准备…' : '开始优化'),
    ),
    const SizedBox(height: 12),
    const Text(
      '开始后，将通过现有 AI 服务处理这份简历；请在保存前核对修改内容。',
      style: TextStyle(fontSize: 12, color: muted, height: 1.6),
    ),
  ];

  List<Widget> generating() => [
    const SizedBox(height: 38),
    if (model.busy)
      const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    const SizedBox(height: 24),
    Text(
      model.busy ? '正在优化表达' : '优化任务已保留',
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
    ),
    const SizedBox(height: 12),
    const Text(
      '正在整理已有经历中的表达与重点。\n生成结果不会自动覆盖原简历。',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 14, color: muted, height: 1.8),
    ),
    const SizedBox(height: 28),
    if (!model.busy && model.validSession)
      FilledButton(
        onPressed: model.conflict ? null : model.refresh,
        child: const Text('继续查看结果'),
      ),
    TextButton(
      onPressed: () => Navigator.pop(context),
      child: const Text('稍后查看'),
    ),
    const Text(
      '再次从这份简历的「AI 简历优化」入口进入，可继续查看本次任务。',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, color: muted, height: 1.6),
    ),
  ];

  List<Widget> review() => [
    const Text(
      '逐项确认修改',
      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
    ),
    const SizedBox(height: 10),
    Text(
      model.changes.isEmpty
          ? '本次没有可采纳的文字修改，原简历保持不变。'
          : '共 ${model.changes.length} 处建议。取消勾选即可保留原文。',
      style: const TextStyle(fontSize: 14, color: muted, height: 1.6),
    ),
    const SizedBox(height: 22),
    for (final change in model.changes)
      Container(
        key: ValueKey('polish-change-${change.path}'),
        margin: const EdgeInsets.only(bottom: 16),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CheckboxListTile(
                contentPadding: const EdgeInsets.fromLTRB(16, 6, 8, 0),
                title: Text(
                  change.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                value: model.selected.contains(change.path),
                onChanged: model.busy || !model.validSession
                    ? null
                    : (value) => model.select(change.path, value == true),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '原文',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      change.before,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.7,
                        color: Color(0xFF707987),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(height: 1),
                    ),
                    const Text(
                      '优化后',
                      style: TextStyle(fontSize: 12, color: blue),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      change.after,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.7,
                        color: ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    if (model.changes.isEmpty)
      TextButton(
        onPressed: model.busy ? null : model.discard,
        child: const Text('返回调整优化要求'),
      ),
  ];
}
