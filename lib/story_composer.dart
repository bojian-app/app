import 'app_page_bar.dart';
import 'content_moderation.dart';

import 'dart:convert';

import 'package:flutter/cupertino.dart'
    show CupertinoAlertDialog, CupertinoDialogAction;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import 'app_icons.dart';
import 'app_store.dart';
import 'article_rich_content.dart';
import 'article_declaration.dart';
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

enum _ComposerAction { save, publish }

enum _ExitAction { save, discard }

class _StoryComposerState extends State<StoryComposer> {
  final title = TextEditingController();
  late final quill.QuillController editor;
  final bodyFocus = FocusNode();
  final bodyScroll = ScrollController();
  _ComposerAction? pendingAction;
  bool get busy => pendingAction != null;
  bool allowExit = false;
  late final String initialTitle, initialDelta;
  late final ArticleDeclaration initialDeclaration;
  late ArticleDeclaration declaration;
  late final int session;
  Map<String, dynamic> get originalContent =>
      Map<String, dynamic>.from(widget.draft?['content'] as Map? ?? {});
  bool get guidance => originalContent['kind'] == 'RESUME_GUIDANCE';
  int? createdDraftID;
  int get draftID => createdDraftID ?? integer(widget.draft?['id']);
  bool get dirty =>
      declaration != initialDeclaration ||
      title.text != initialTitle ||
      jsonEncode(editor.document.toDelta().toJson()) != initialDelta;
  @override
  void initState() {
    super.initState();
    session = widget.store.epoch;
    declaration = initialDeclaration = readArticleDeclaration(originalContent);
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
    if (busy) return;
    if (dirty) {
      final existing = widget.draft != null;
      final action = await showAppDialog<_ExitAction>(
        context,
        barrierDismissible: true,
        builder: (dialog) => CupertinoAlertDialog(
          title: Text(existing ? '保存这次修改？' : '放弃这篇文章？'),
          actions: [
            if (existing)
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.pop(dialog, _ExitAction.save),
                child: const Text('保存草稿'),
              ),
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('继续编辑'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(dialog, _ExitAction.discard),
              child: Text(existing ? '放弃修改' : '放弃'),
            ),
          ],
        ),
      );
      if (!mounted || action == null) return;
      if (action == _ExitAction.save) {
        await publish(submit: false);
        return;
      }
    }
    setState(() => allowExit = true);
    Navigator.pop(context);
  }

  Future<void> chooseDeclaration() async {
    dismissKeyboard();
    final selected = await editArticleDeclaration(context, declaration);
    if (mounted && selected != null) setState(() => declaration = selected);
  }

  Future<void> publish({bool submit = true}) async {
    if (busy) return;
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
    if (declaration != initialDeclaration) {
      if (declaration.label.isEmpty) {
        content.remove('declaration');
      } else {
        content['declaration'] = {
          'original': declaration.original,
          'type': declaration.notice.name,
        };
      }
    }
    editor.readOnly = true;
    setState(
      () => pendingAction = submit
          ? _ComposerAction.publish
          : _ComposerAction.save,
    );
    var status = SubmissionStatus.pending;
    final saved = await runRequest(context, () async {
      if (draftID == 0) {
        status = await widget.store.publish(
          title.text.trim(),
          text,
          '动态',
          content: content,
          onDraftSaved: (id) => createdDraftID = id,
        );
      } else {
        await widget.store.saveArticleDraft(
          id: draftID,
          title: title.text.trim(),
          content: content,
          resumeID: widget.draft?['resume_id'] as int?,
          expectedEpoch: session,
        );
        if (submit) {
          status = await widget.store.submitArticleDraft(
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
      toast(context, submit ? articleSubmissionMessage(status) : '草稿已保存');
    } else {
      editor.readOnly = false;
      setState(() => pendingAction = null);
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
            ? context.colors.accent.withValues(alpha: .08)
            : Colors.transparent,
      ).withoutHover(),
      onPressed: busy
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
      canPop: allowExit || (!dirty && !busy),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) exit();
      },
      child: Scaffold(
        backgroundColor: context.colors.surface,
        appBar: AppPageBar(
          title: Text(widget.draft == null ? '写动态' : '编辑草稿'),
          leading: IconButton(
            tooltip: '返回',
            onPressed: busy ? null : exit,
            icon: const AppIcon(AppIcons.back, size: 22),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Tooltip(
                  message: '提交审核',
                  child: TextButton(
                    onPressed:
                        busy ||
                            title.text.trim().isEmpty ||
                            (!guidance &&
                                editor.document.toPlainText().trim().isEmpty)
                        ? null
                        : () => publish(),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(56, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      backgroundColor: context.colors.palette.seed,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: context.colors.inset,
                      disabledForegroundColor: context.colors.muted,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
                    ).withoutHover(),
                    child: Text(
                      pendingAction == _ComposerAction.publish
                          ? '发布中…'
                          : widget.draft == null
                          ? '发布'
                          : '重新发布',
                    ),
                  ),
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
              padding: const EdgeInsets.fromLTRB(
                appPageHorizontalPadding,
                12,
                appPageHorizontalPadding,
                32,
              ),
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
                  enabled: !busy,
                  maxLength: widget.draft == null ? 60 : 200,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => bodyFocus.requestFocus(),
                  style: const TextStyle(
                    fontSize: 22,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: '标题',
                    hintStyle: TextStyle(
                      fontSize: 22,
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
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 16),
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
                      // Selection handles and the copy menu live in the root
                      // overlay, outside the editor's tap region. Unfocusing
                      // on them would collapse a selection while it is being
                      // dragged, so only a caret is dismissed by outside taps.
                      onTapOutside: (_, focus) {
                        if (editor.selection.isCollapsed) focus.unfocus();
                      },
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
                    child: Ink(
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        border: Border(
                          top: BorderSide(color: context.colors.border),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  key: const ValueKey('composer-format-bar'),
                                  scrollDirection: Axis.horizontal,
                                  // The app dismisses the keyboard on drag; this
                                  // bar sits on the keyboard and must keep it.
                                  keyboardDismissBehavior:
                                      ScrollViewKeyboardDismissBehavior.manual,
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
                                        onPressed: busy || !editor.hasUndo
                                            ? null
                                            : editor.undo,
                                        icon: const AppIcon(
                                          AppIcons.undo,
                                          size: 20,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: '重做',
                                        onPressed: busy || !editor.hasRedo
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
                              if (MediaQuery.viewInsetsOf(context).bottom > 0)
                                IconButton(
                                  tooltip: '内容声明',
                                  onPressed: busy ? null : chooseDeclaration,
                                  icon: const AppIcon(AppIcons.about, size: 20),
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
                          if (MediaQuery.viewInsetsOf(context).bottom == 0)
                            ListTile(
                              enabled: !busy,
                              onTap: chooseDeclaration,
                              leading: const AppIcon(AppIcons.about, size: 19),
                              title: const Text(
                                '内容声明',
                                style: TextStyle(fontSize: 14),
                              ),
                              trailing: const AppIcon(
                                AppIcons.forward,
                                size: 16,
                              ),
                              subtitle: declaration.label.isEmpty
                                  ? null
                                  : Text(declaration.label),
                            ),
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
