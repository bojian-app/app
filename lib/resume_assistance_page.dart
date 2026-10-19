import 'package:flutter/material.dart';

import 'app_store.dart';
import 'design.dart';
import 'resume_creation.dart';

class ResumeAssistancePage extends StatefulWidget {
  const ResumeAssistancePage({super.key, required this.store});
  final AppStore store;

  @override
  State<ResumeAssistancePage> createState() => _ResumeAssistancePageState();
}

class _ResumeAssistancePageState extends State<ResumeAssistancePage> {
  final description = TextEditingController();
  late final submission = ResumeCreationController(widget.store);
  String? error;

  @override
  void dispose() {
    description.dispose();
    submission.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (submission.submitting) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => error = null);
    try {
      final id = await submission.submit(description.text);
      if (!mounted || id == null) return;
      toast(context, '协助已发起，完成后会通过消息通知你');
      Navigator.pop(context);
    } catch (e) {
      if (mounted && widget.store.isAuthenticated) setState(() => error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([description, submission]),
    builder: (context, _) => Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        title: const Text('协助添加'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: FilledButton(
                key: const ValueKey('resume-assistance-submit'),
                style: FilledButton.styleFrom(
                  foregroundColor: context.colors.accent,
                  backgroundColor: context.colors.accentSoft,
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ).withoutHover(),
                onPressed:
                    submission.submitting ||
                        description.text.trim().runes.length < 10
                    ? null
                    : submit,
                child: Text(submission.submitting ? '提交中…' : '发起协助'),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                '描述你的经历（至少10字），我们来帮你整理成简历。完成后会通过消息通知你。',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: context.colors.muted,
                ),
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(
                  error!,
                  key: const ValueKey('resume-assistance-error'),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            Expanded(
              child: TextField(
                key: const ValueKey('resume-assistance-description'),
                controller: description,
                enabled: !submission.submitting,
                expands: true,
                minLines: null,
                maxLines: null,
                maxLength: 5000,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.7,
                  color: context.colors.ink,
                ),
                decoration: const InputDecoration(
                  hintText: '可以聊聊你的求职方向、教育背景、工作经历、项目和技能。\n\n不用考虑格式，按自己的方式描述就好。',
                  filled: false,
                  contentPadding: EdgeInsets.fromLTRB(20, 16, 20, 16),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
