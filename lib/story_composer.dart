import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import 'app_icons.dart';
import 'app_store.dart';
import 'article_rich_content.dart';
import 'design.dart';

class StoryComposer extends StatefulWidget {
  const StoryComposer({super.key, required this.store});
  final AppStore store;
  @override
  State<StoryComposer> createState() => _StoryComposerState();
}

class _StoryComposerState extends State<StoryComposer> {
  final title = TextEditingController();
  final editor = quill.QuillController.basic();
  final bodyFocus = FocusNode();
  final bodyScroll = ScrollController();
  bool publishing = false, allowExit = false;
  bool get dirty =>
      title.text.isNotEmpty || editor.document.toPlainText().trim().isNotEmpty;
  @override
  void initState() {
    super.initState();
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
        await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('放弃这篇文章？'),
                content: const Text('离开后，尚未提交的内容不会保存。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('继续编辑'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('放弃'),
                  ),
                ],
              ),
            ) ==
            true;
    if (!discard || !mounted) return;
    setState(() => allowExit = true);
    Navigator.pop(context);
  }

  Future<void> publish() async {
    if (publishing) return;
    final text = editor.document.toPlainText().trim();
    if (title.text.trim().isEmpty || text.isEmpty) {
      toast(context, '请填写标题和正文');
      return;
    }
    dismissKeyboard();
    final content = articleContentFromDelta(editor.document.toDelta().toJson());
    editor.readOnly = true;
    setState(() => publishing = true);
    final saved = await runRequest(
      context,
      () => widget.store.publish(
        title.text.trim(),
        text,
        '经验分享',
        content: content,
      ),
    );
    if (!mounted) return;
    if (saved) {
      setState(() => allowExit = true);
      Navigator.pop(context);
      toast(context, '已提交审核');
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
      ),
      onPressed: publishing
          ? null
          : () {
              editor.formatSelection(
                active ? quill.Attribute.clone(attribute, null) : attribute,
              );
              bodyFocus.requestFocus();
            },
      icon: AppIcon(icon, size: 20, color: active ? blue : ink),
    );
  }

  quill.DefaultTextBlockStyle style(
    double size, {
    bool bold = false,
    Color color = ink,
  }) => quill.DefaultTextBlockStyle(
    TextStyle(
      fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
      fontSize: size,
      height: ArticleRichBody.lineHeight,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      color: color,
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
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          leading: IconButton(
            tooltip: '关闭',
            onPressed: publishing ? null : exit,
            icon: const AppIcon(AppIcons.close, size: 22),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton(
                tooltip: '提交审核',
                onPressed: publishing ? null : publish,
                icon: publishing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: blue,
                        ),
                      )
                    : const AppIcon(
                        AppIcons.submitReview,
                        size: 22,
                        color: blue,
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
                TextField(
                  key: const ValueKey('composer-title'),
                  controller: title,
                  enabled: !publishing,
                  maxLength: 60,
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
                      color: muted.withValues(alpha: .6),
                    ),
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    counterText: '',
                    suffix: Text(
                      '${title.text.characters.length}/60',
                      style: const TextStyle(fontSize: 10, color: muted),
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
                      placeholder: '写下你的经历与想法…',
                      customStyles: quill.DefaultStyles(
                        paragraph: style(16),
                        h1: style(23, bold: true),
                        h2: style(19, bold: true),
                        placeHolder: style(16, color: muted),
                      ),
                      onTapOutside: (_, focus) => focus.unfocus(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: TextFieldTapRegion(
            child: SafeArea(
              top: false,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: borderColor)),
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
                            format('粗体', AppIcons.bold, quill.Attribute.bold),
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
                            format('小标题', AppIcons.heading, quill.Attribute.h2),
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
                              icon: const AppIcon(AppIcons.undo, size: 20),
                            ),
                            IconButton(
                              tooltip: '重做',
                              onPressed: publishing || !editor.hasRedo
                                  ? null
                                  : editor.redo,
                              icon: const AppIcon(AppIcons.redo, size: 20),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '收起键盘',
                      onPressed: dismissKeyboard,
                      icon: const AppIcon(
                        AppIcons.hideKeyboard,
                        size: 20,
                        color: muted,
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
