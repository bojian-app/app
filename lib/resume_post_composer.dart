import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api/bojian_api.dart';
import 'app_icons.dart';
import 'app_page_bar.dart';
import 'app_store.dart';
import 'confirmation_dialog.dart';
import 'content_moderation.dart';
import 'design.dart';

class ResumePostComposer extends StatefulWidget {
  const ResumePostComposer({
    super.key,
    required this.store,
    required this.resume,
  });

  final AppStore store;
  final ResumeDraft resume;
  static const defaultText = '分享我的简历，欢迎交流。';

  @override
  State<ResumePostComposer> createState() => _ResumePostComposerState();
}

class _ResumePostComposerState extends State<ResumePostComposer> {
  final content = TextEditingController();
  late final int accountEpoch;
  bool publishing = false, allowExit = false;
  String? error, lastText, requestKey;

  @override
  void initState() {
    super.initState();
    accountEpoch = widget.store.epoch;
    content.addListener(changed);
  }

  void changed() => setState(() {});

  @override
  void dispose() {
    content.removeListener(changed);
    content.dispose();
    super.dispose();
  }

  Future<void> exit() async {
    if (publishing) return;
    if (content.text.trim().isNotEmpty) {
      final discard = await showAppConfirmation(
        context,
        title: '放弃发表动态？',
        content: const Text('离开后，已填写的动态文字不会保存。'),
        cancelLabel: '继续编辑',
        confirmLabel: '放弃',
        destructive: true,
      );
      if (discard != true || !mounted) return;
    }
    setState(() => allowExit = true);
    Navigator.pop(context);
  }

  Future<void> publish() async {
    if (publishing) return;
    final text = content.text.trim().isEmpty
        ? ResumePostComposer.defaultText
        : content.text.trim();
    // Reuse the key after a lost response; edited content is a new submission.
    if (text != lastText) {
      lastText = text;
      requestKey =
          'mobile-resume-post-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    }
    dismissKeyboard();
    setState(() {
      publishing = true;
      error = null;
    });
    try {
      final result = await widget.store.request(
        'PostResumesIdGuidance',
        path: {'id': '${widget.resume.id}'},
        body: {
          'version': 2,
          'destination': 'CIRCLE',
          'question': text,
          'hidden_fields': [
            'personal_info',
            'photo',
            'projects.url',
            'educations.institution',
            'work_experiences.company',
            'projects.name',
            'certifications.issuer',
          ],
        },
        extra: {'idempotency-key': requestKey!},
        expectedEpoch: accountEpoch,
      );
      final status = submissionStatus(
        result.data,
        fallback: SubmissionStatus.pending,
      );
      if (integer(result.data['id']) <= 0) {
        throw const ApiFailure('发表结果暂不可用，请重试');
      }
      unawaited(widget.store.load('feed'));
      if (!mounted) return;
      setState(() => allowExit = true);
      Navigator.pop(context);
      toast(
        context,
        status == SubmissionStatus.published ? '动态已发表' : '已提交审核，通过后展示在社区',
      );
    } catch (failure) {
      if (!mounted) return;
      setState(() {
        publishing = false;
        error = '$failure';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: allowExit || (!publishing && content.text.trim().isEmpty),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) exit();
    },
    child: Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppPageBar(
        title: const Text('发表动态'),
        leading: IconButton(
          tooltip: '返回',
          onPressed: publishing ? null : exit,
          icon: const AppIcon(AppIcons.back, size: 22),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      TextField(
                        key: const ValueKey('resume-post-content'),
                        controller: content,
                        enabled: !publishing,
                        minLines: 6,
                        maxLines: 12,
                        maxLength: 1000,
                        maxLengthEnforcement:
                            MaxLengthEnforcement.truncateAfterCompositionEnds,
                        style: const TextStyle(fontSize: 15, height: 1.6),
                        decoration: const InputDecoration(
                          hintText: ResumePostComposer.defaultText,
                          counterText: '',
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          error!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('resume-post-submit'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: publishing ? null : publish,
                      child: Text(publishing ? '发表中…' : '发表'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
