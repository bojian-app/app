import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import 'app_icons.dart';
import 'app_store.dart';
import 'article_rich_content.dart';
import 'confirmation_dialog.dart';
import 'design.dart';

class _ArticleBlockEmbed extends quill.EmbedBuilder {
  const _ArticleBlockEmbed();

  @override
  String get key => 'bojian-block';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) =>
      ArticleRichBody(
        content: {
          'blocks': [jsonDecode(embedContext.node.value.data as String)],
        },
      );
}

class StoryComposer extends StatefulWidget {
  const StoryComposer({super.key, required this.store, this.draft});
  final AppStore store;
  final Map<String, dynamic>? draft;
  @override
  State<StoryComposer> createState() => _StoryComposerState();
}

class _StoryComposerState extends State<StoryComposer> {
  final title = TextEditingController();
  late final quill.QuillController editor;
  final bodyFocus = FocusNode();
  final bodyScroll = ScrollController();
  bool publishing = false, allowExit = false;
  late final String initialTitle, initialDelta;
  late final int session;
  Map<String, dynamic> get originalContent =>
      Map<String, dynamic>.from(widget.draft?['content'] as Map? ?? {});
  bool get guidance => originalContent['kind'] == 'RESUME_GUIDANCE';
  int get draftID => integer(widget.draft?['id']);
  bool get dirty =>
      title.text != initialTitle ||
      jsonEncode(editor.document.toDelta().toJson()) != initialDelta;
  @override
  void initState() {
    super.initState();
    session = widget.store.epoch;
    title.text = initialTitle = '${widget.draft?['title'] ?? ''}';
    editor = widget.draft == null
        ? quill.QuillController.basic()
        : quill.QuillController(
            document: quill.Document.fromJson(
              articleDeltaFromContent(
                guidance
                    ? richContent('${originalContent['question'] ?? ''}')
                    : originalContent,
              ),
            ),
            selection: const TextSelection.collapsed(offset: 0),
          );
    initialDelta = jsonEncode(editor.document.toDelta().toJson());
    title.addListener(changed);
    editor.addListener(changed);
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    title.removeListener(changed);
    editor.removeListener(changed);
    title.dispose();
    editor.dispose();
    bodyFocus.dispose();
    bodyScroll.dispose();
    super.dispose();
  }

  Future<void> exit() async {
    if (publishing) return;
    final discard =
        !dirty ||
        await showAppConfirmation(
              context,
              title: widget.draft == null ? '放弃这篇文章？' : '放弃本次修改？',
              content: Text(
                widget.draft == null ? '离开后，尚未提交的内容不会保存。' : '离开后，本次修改不会保存。',
              ),
              cancelLabel: '继续编辑',
              confirmLabel: '放弃',
              destructive: true,
            ) ==
            true;
    if (!discard || !mounted) return;
    setState(() => allowExit = true);
    Navigator.pop(context);
  }

  Future<void> publish({bool submit = true}) async {
    if (publishing) return;
    final text = editor.document.toPlainText().trim();
    if (title.text.trim().isEmpty || (!guidance && text.isEmpty)) {
      toast(context, '请填写标题和正文');
      return;
    }
    dismissKeyboard();
    final operations = editor.document.toDelta().toJson();
    final content = guidance
        ? {...originalContent, 'question': text}
        : widget.draft != null && jsonEncode(operations) == initialDelta
        ? originalContent
        : {...originalContent, ...articleContentFromDelta(operations)};
    editor.readOnly = true;
    setState(() => publishing = true);
    final saved = await runRequest(context, () async {
      if (widget.draft == null) {
        await widget.store.publish(
          title.text.trim(),
          text,
          '经验分享',
          content: content,
        );
      } else {
        await widget.store.saveArticleDraft(
          id: draftID,
          title: title.text.trim(),
          content: content,
          resumeID: widget.draft!['resume_id'] as int?,
          expectedEpoch: session,
        );
        if (submit) {
          await widget.store.submitArticleDraft(
            draftID,
            expectedEpoch: session,
          );
        }
      }
    });
    if (!mounted) return;
    if (saved) {
      setState(() => allowExit = true);
      Navigator.pop(context);
      toast(context, submit ? '已提交审核' : '草稿已保存');
    } else {
      editor.readOnly = false;
      setState(() => publishing = false);
    }
  }

  Widget format(String label, AppIconData icon, quill.Attribute attribute) {
    final active =
        editor.getSelectionStyle().attributes[attribute.key]?.value ==
        attribute.value;
    return IconButton(
      tooltip: label,
      isSelected: active,
      style: IconButton.styleFrom(
        backgroundColor: active
            ? blue.withValues(alpha: .08)
            : Colors.transparent,
      ).withoutHover(),
      onPressed: publishing
          ? null
          : () {
              editor.formatSelection(
                active ? quill.Attribute.clone(attribute, null) : attribute,
              );
              bodyFocus.requestFocus();
            },
      icon: AppIcon(
        icon,
        size: 20,
        color: active ? context.colors.accent : context.colors.ink,
      ),
    );
  }

  quill.DefaultTextBlockStyle style(
    double size, {
    bool bold = false,
    Color? color,
  }) => quill.DefaultTextBlockStyle(
    TextStyle(
      fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
      fontSize: size,
      height: ArticleRichBody.lineHeight,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      color: color ?? context.colors.ink,
    ),
    const quill.HorizontalSpacing(0, 0),
    const quill.VerticalSpacing(0, 0),
    const quill.VerticalSpacing(0, 0),
    null,
  );
  @override
  Widget build(BuildContext context) => Localizations.override(
    context: context,
    locale: const Locale('zh'),
    delegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      quill.FlutterQuillLocalizations.delegate,
    ],
    child: PopScope(
      canPop: allowExit || (!dirty && !publishing),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) exit();
      },
      child: Scaffold(
        backgroundColor: context.colors.surface,
        appBar: AppBar(
          backgroundColor: context.colors.surface,
          leading: IconButton(
            tooltip: '关闭',
            onPressed: publishing ? null : exit,
            icon: const AppIcon(AppIcons.close, size: 22),
          ),
          actions: [
            if (widget.draft != null)
              TextButton(
                onPressed: publishing ? null : () => publish(submit: false),
                child: const Text('保存'),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton(
                tooltip: '提交审核',
                onPressed: publishing ? null : () => publish(),
                icon: publishing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: blue,
                        ),
                      )
                    : AppIcon(
                        AppIcons.submitReview,
                        size: 22,
                        color: context.colors.accent,
                      ),
              ),
            ),
          ],
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              key: const ValueKey('composer-page'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              children: [
                if ('${widget.draft?['review_reason'] ?? ''}'
                    .trim()
                    .isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '审核意见：${widget.draft!['review_reason']}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                TextField(
                  key: const ValueKey('composer-title'),
                  controller: title,
                  enabled: !publishing,
                  maxLength: widget.draft == null ? 60 : 200,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => bodyFocus.requestFocus(),
                  style: const TextStyle(
                    fontSize: 28,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: '标题',
                    hintStyle: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: context.colors.muted.withValues(alpha: .6),
                    ),
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    counterText: '',
                    suffix: Text(
                      '${title.text.characters.length}/${widget.draft == null ? 60 : 200}',
                      style: TextStyle(
                        fontSize: 10,
                        color: context.colors.muted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 22),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 280),
                  child: quill.QuillEditor.basic(
                    key: const ValueKey('composer-body'),
                    controller: editor,
                    focusNode: bodyFocus,
                    scrollController: bodyScroll,
                    config: quill.QuillEditorConfig(
                      scrollable: false,
                      placeholder: guidance ? '想请教的问题…' : '写下你的经历与想法…',
                      embedBuilders: const [_ArticleBlockEmbed()],
                      customStyles: quill.DefaultStyles(
                        paragraph: style(16),
                        h1: style(23, bold: true),
                        h2: style(19, bold: true),
                        placeHolder: style(16, color: context.colors.muted),
                      ),
                      onTapOutside: (_, focus) => focus.unfocus(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: guidance
            ? null
            : Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: TextFieldTapRegion(
                  child: SafeArea(
                    top: false,
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        border: Border(
                          top: BorderSide(color: context.colors.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Row(
                                children: [
                                  format(
                                    '粗体',
                                    AppIcons.bold,
                                    quill.Attribute.bold,
                                  ),
                                  format(
                                    '斜体',
                                    AppIcons.italic,
                                    quill.Attribute.italic,
                                  ),
                                  format(
                                    '下划线',
                                    AppIcons.underline,
                                    quill.Attribute.underline,
                                  ),
                                  const SizedBox(width: 8),
                                  format(
                                    '小标题',
                                    AppIcons.heading,
                                    quill.Attribute.h2,
                                  ),
                                  format(
                                    '无序列表',
                                    AppIcons.bullets,
                                    quill.Attribute.ul,
                                  ),
                                  format(
                                    '有序列表',
                                    AppIcons.numbering,
                                    quill.Attribute.ol,
                                  ),
                                  format(
                                    '引用',
                                    AppIcons.quote,
                                    quill.Attribute.blockQuote,
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: '撤销',
                                    onPressed: publishing || !editor.hasUndo
                                        ? null
                                        : editor.undo,
                                    icon: const AppIcon(
                                      AppIcons.undo,
                                      size: 20,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '重做',
                                    onPressed: publishing || !editor.hasRedo
                                        ? null
                                        : editor.redo,
                                    icon: const AppIcon(
                                      AppIcons.redo,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: '收起键盘',
                            onPressed: dismissKeyboard,
                            icon: AppIcon(
                              AppIcons.hideKeyboard,
                              size: 20,
                              color: context.colors.muted,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    ),
  );
}
