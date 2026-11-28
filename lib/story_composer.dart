import 'app_page_bar.dart';
import 'user_display_name.dart';
import 'content_moderation.dart';

import 'dart:convert';

import 'package:flutter/cupertino.dart'
    show CupertinoAlertDialog, CupertinoDialogAction;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import 'app_icons.dart';
import 'app_store.dart';
import 'api/bojian_api.dart';
import 'article_rich_content.dart';
import 'article_link.dart';
import 'article_media_picker.dart';
import 'article_photo.dart';
import 'article_poll.dart';
import 'article_privacy.dart';
import 'article_tags.dart';
import 'article_topic.dart';

import 'package:flutter_quill/quill_delta.dart' show Delta;

import 'article_declaration.dart';
import 'confirmation_dialog.dart';
import 'design.dart';

part 'story_composer_toolbar.dart';

class _ArticleBlockEmbed extends quill.EmbedBuilder {
  const _ArticleBlockEmbed(this.state);
  final _StoryComposerState state;
  @override
  String get key => 'bojian-block';
  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final block = Map<String, dynamic>.from(
      jsonDecode(embedContext.node.value.data as String),
    );
    final kind = block['kind'];
    final media = kind == 'image' || kind == 'video';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ArticleRichBody(
          store: state.widget.store,
          articleID: state.draftID > 0 ? state.draftID : null,
          editing: true,
          content: {
            'blocks': [block],
            if (state.declaration.watermark)
              'declaration': {
                'watermark': true,
                'watermark_label': state.watermarkLabel,
              },
          },
        ),
        if (media || kind == 'link' || kind == 'poll')
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (media)
                TextButton(
                  onPressed: state.busy
                      ? null
                      : () => state.editCaption(embedContext, block),
                  child: const Text('编辑说明'),
                ),
              if (kind == 'poll')
                IconButton(
                  tooltip: block['mode'] == 'question' ? '编辑问答' : '编辑投票',
                  icon: const AppIcon(AppIcons.edit, size: 18),
                  onPressed: state.busy
                      ? null
                      : () => state.editPoll(embedContext, block),
                ),
              if (kind == 'link')
                IconButton(
                  tooltip: '编辑链接',
                  icon: const AppIcon(AppIcons.link, size: 18),
                  onPressed: state.busy
                      ? null
                      : () => state.editLink(embedContext, block),
                ),
              IconButton(
                tooltip: '移除卡片',
                icon: const AppIcon(AppIcons.delete, size: 18),
                onPressed: state.busy
                    ? null
                    : () => state.removeBlock(embedContext),
              ),
            ],
          ),
      ],
    );
  }
}

enum _ToolPanel { none, format, insert, settings }

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
  final titleFocus = FocusNode();
  late final quill.QuillController editor;
  final bodyFocus = FocusNode();
  final bodyScroll = ScrollController();
  final pageScroll = ScrollController();
  final editorKey = GlobalKey<quill.EditorState>();
  _ComposerAction? pendingAction;
  bool choosing = false;

  /// Set while picked pictures and videos are on their way up.
  ({int done, int total})? uploading;
  bool get busy => pendingAction != null || choosing;
  _ToolPanel panel = _ToolPanel.none;
  bool headingPicker = false;
  late final ArticlePrivacy initialPrivacy;
  late ArticlePrivacy privacy;
  String get watermarkLabel => 'Z优简 · ${userDisplayName(widget.store.name)}';
  bool allowExit = false;
  late final String initialTitle, initialDelta;
  late final List<String> initialTags;

  /// Chosen apart from the writing, and listed under it.
  final tags = <String>[];
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
      privacy != initialPrivacy ||
      title.text != initialTitle ||
      tagsChanged ||
      jsonEncode(editor.document.toDelta().toJson()) != initialDelta;
  bool get tagsChanged => !listEquals(tags, initialTags);
  @override
  void initState() {
    super.initState();
    session = widget.store.epoch;
    privacy = initialPrivacy = ArticlePrivacy.fromDraft(widget.draft);
    declaration = initialDeclaration = readArticleDeclaration(originalContent);
    title.text = initialTitle = '${widget.draft?['title'] ?? ''}';
    final split = splitArticleTags(originalContent);
    if (!guidance) tags.addAll(split.tags);
    initialTags = [...tags];
    editor = widget.draft == null
        ? quill.QuillController.basic()
        : quill.QuillController(
            document: quill.Document.fromJson(
              articleDeltaFromContent(
                guidance
                    ? richContent('${originalContent['question'] ?? ''}')
                    : split.body,
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
    titleFocus.dispose();
    pageScroll.dispose();
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
          title: Text(existing ? '保存这次修改？' : '要保存草稿吗？'),
          actions: [
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

  bool get hasPublishableContent => guidance
      ? title.text.trim().isNotEmpty
      : editor.document.toDelta().toList().any(
          (op) =>
              op.data is Map ||
              (op.data is String && (op.data as String).trim().isNotEmpty),
        );
  bool get hasDraftContent =>
      title.text.trim().isNotEmpty || tags.isNotEmpty || hasPublishableContent;

  void changePanel(_ToolPanel next) {
    if (busy) return;
    setState(() {
      panel = panel == next ? _ToolPanel.none : next;
      headingPicker = false;
    });
    if (next == _ToolPanel.format) {
      bodyFocus.requestFocus();
    } else {
      dismissKeyboard();
    }
  }

  Future<void> choosePrivacy() async {
    final result = await editArticlePrivacy(context, privacy);
    if (mounted && result != null) setState(() => privacy = result);
  }

  /// Puts [blocks] on their own lines at [selection], replacing what it spans.
  void placeBlocks(TextSelection selection, List<Map<String, dynamic>> blocks) {
    final (start, end) = selectedRange(selection);
    final plain = editor.document
        .toDelta()
        .map((op) => op.data is String ? op.data as String : '\uFFFC')
        .join();
    final delta = Delta()
      ..retain(start)
      ..delete(end - start);
    var cursor = start;
    if (start > 0 && plain[start - 1] != '\n') {
      delta.insert('\n');
      cursor++;
    }
    for (final block in blocks) {
      delta.insert({'bojian-block': jsonEncode(block)});
      delta.insert('\n');
      cursor += 2;
    }
    applyDelta(delta, cursor);
  }

  /// How many more pictures and videos the post has room for.
  int get mediaRoom =>
      maxArticleMedia -
      articleMediaCount(
        articleContentFromDelta(editor.document.toDelta().toJson()),
      );

  Future<void> insertTool(String tool) async {
    if (busy) return;
    final room = tool == '图片或视频' ? mediaRoom : 0;
    if (tool == '图片或视频' && room <= 0) {
      toast(context, '一条动态最多添加 $maxArticleMedia 个图片或视频');
      return;
    }
    final selection = editor.selection;
    dismissKeyboard();
    setState(() {
      choosing = true;
      panel = _ToolPanel.none;
    });
    try {
      if (tool == '话题') {
        final name = await pickArticleTopic(context, widget.store);
        if (!mounted || name == null || widget.store.epoch != session) return;
        if (!tags.contains(name)) setState(() => tags.add(name));
      } else {
        final List<Map<String, dynamic>> blocks;
        if (tool == '图片或视频') {
          blocks = await pickArticlePhotos(
            context,
            widget.store,
            limit: room,
            onProgress: (done, total) {
              if (mounted) {
                setState(() => uploading = (done: done, total: total));
              }
            },
          );
        } else if (tool == '投票') {
          // It joins the writing, and is published along with it.
          final poll = await openArticlePollComposer(context, widget.store);
          blocks = [?poll];
        } else {
          final url = await editArticleLink(context);
          blocks = [
            if (url != null) {'kind': 'link', 'url': url.toString()},
          ];
        }
        if (!mounted || blocks.isEmpty || widget.store.epoch != session) return;
        placeBlocks(selection, blocks);
      }
      bodyFocus.requestFocus();
    } catch (error) {
      if (mounted) await showRequestFailure(context, error);
    } finally {
      if (mounted) {
        setState(() {
          choosing = false;
          uploading = null;
        });
      }
    }
  }

  Widget uploadStatus(int done, int total) => Padding(
    key: const ValueKey('composer-uploading'),
    padding: const EdgeInsets.fromLTRB(
      appPageHorizontalPadding,
      8,
      appPageHorizontalPadding,
      8,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Text(
          '正在上传 $done/$total',
          style: TextStyle(fontSize: 12, color: context.colors.muted),
        ),
        LinearProgressIndicator(
          // Moves on its own until the first one is up.
          value: done == 0 ? null : done / total,
          minHeight: 3,
          borderRadius: BorderRadius.circular(2),
        ),
      ],
    ),
  );

  (int, int) selectedRange(TextSelection selection) {
    final last = editor.document.length - 1;
    if (!selection.isValid) return (last, last);
    return (selection.start.clamp(0, last), selection.end.clamp(0, last));
  }

  void applyDelta(Delta delta, int cursor) {
    final after = TextSelection.collapsed(offset: cursor);
    editor.compose(delta, after, quill.ChangeSource.local);
    editor.updateSelection(after, quill.ChangeSource.local);
  }

  void removeBlock(quill.EmbedContext embed) {
    final offset = embed.node.documentOffset;
    final canRemoveLine =
        offset + 2 < editor.document.length &&
        editor.document.getPlainText(offset + 1, 1) == '\n';
    final delta = Delta()
      ..retain(offset)
      ..delete(canRemoveLine ? 2 : 1);
    applyDelta(delta, offset);
  }

  Future<void> editCaption(
    quill.EmbedContext embed,
    Map<String, dynamic> block,
  ) async {
    final kind = block['kind'] as String;
    final media = Map<String, dynamic>.from(block[kind] as Map? ?? {});
    final caption = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CaptionEditor(initial: '${media['caption'] ?? ''}'),
    );
    if (!mounted || caption == null || embed.node.parent == null) return;
    media['caption'] = caption;
    replaceBlock(embed, {...block, kind: media});
  }

  Future<void> editLink(
    quill.EmbedContext embed,
    Map<String, dynamic> block,
  ) async {
    final url = await editArticleLink(
      context,
      initial: '${block['url'] ?? ''}',
    );
    if (!mounted || url == null || embed.node.parent == null) return;
    replaceBlock(embed, {...block, 'url': url.toString()});
  }

  /// A saved poll never changes: finishing its form makes a new one, which
  /// takes the old one's place.
  Future<void> editPoll(
    quill.EmbedContext embed,
    Map<String, dynamic> block,
  ) async {
    dismissKeyboard();
    final poll = await openArticlePollComposer(
      context,
      widget.store,
      initial: block,
    );
    if (!mounted ||
        poll == null ||
        widget.store.epoch != session ||
        embed.node.parent == null) {
      return;
    }
    replaceBlock(embed, poll);
  }

  /// A poll's time runs from when it is made, so one left in a draft may have
  /// closed before the post goes out.
  static bool hasClosedPoll(Map<String, dynamic> content) =>
      (content['blocks'] as List? ?? const []).whereType<Map>().any((block) {
        if (block['kind'] != 'poll') return false;
        final end = DateTime.tryParse('${block['ends_at'] ?? ''}');
        return end != null && !end.isAfter(DateTime.now());
      });

  void replaceBlock(quill.EmbedContext embed, Map<String, dynamic> block) {
    final offset = embed.node.documentOffset;
    applyDelta(
      Delta()
        ..retain(offset)
        ..delete(1)
        ..insert({'bojian-block': jsonEncode(block)}),
      offset + 1,
    );
  }

  Future<void> chooseDeclaration() async {
    dismissKeyboard();
    final selected = await editArticleDeclaration(context, declaration);
    if (mounted && selected != null) setState(() => declaration = selected);
  }

  Future<void> publish({bool submit = true}) async {
    if (busy) return;
    final text = editor.document.toPlainText().trim();
    if (!(submit ? hasPublishableContent : hasDraftContent)) {
      toast(context, submit ? '请写下正文或插入内容' : '请先填写标题或正文');
      return;
    }
    dismissKeyboard();
    final operations = editor.document.toDelta().toJson();
    final Map<String, dynamic> content;
    if (guidance) {
      content = {...originalContent, 'question': text};
    } else if (widget.draft != null &&
        !tagsChanged &&
        jsonEncode(operations) == initialDelta) {
      content = originalContent;
    } else {
      final written = articleContentFromDelta(operations);
      content = {
        ...originalContent,
        ...written,
        if (tags.isNotEmpty)
          'blocks': [...written['blocks'] as List, articleTagBlock(tags)],
      };
    }
    if (declaration != initialDeclaration) {
      if (declaration.label.isEmpty && !declaration.watermark) {
        content.remove('declaration');
      } else {
        content['declaration'] = {
          'original': declaration.original,
          if (declaration.watermark) 'watermark': true,
          if (declaration.watermark) 'watermark_label': watermarkLabel,
          'type': declaration.notice.name,
        };
      }
    }
    final excess = articleMediaCount(content) - maxArticleMedia;
    if (excess > 0) {
      toast(context, '一条动态最多 $maxArticleMedia 个图片或视频，请删掉 $excess 个');
      return;
    }
    if (submit && hasClosedPoll(content)) {
      toast(context, '投票或问答已过截止时间，请重新设置后发布');
      return;
    }
    editor.readOnly = true;
    setState(
      () => pendingAction = submit
          ? _ComposerAction.publish
          : _ComposerAction.save,
    );
    var status = SubmissionStatus.pending;
    try {
      if (draftID == 0) {
        createdDraftID = await widget.store.createArticleDraft(
          title: title.text.trim(),
          content: content,
          visibility: privacy.visibility,
          followedRepliesOnly: privacy.followedRepliesOnly,
          expectedEpoch: session,
        );
      } else {
        await widget.store.saveArticleDraft(
          id: draftID,
          title: title.text.trim(),
          content: content,
          resumeID: widget.draft?['resume_id'] as int?,
          visibility: privacy.visibility,
          followedRepliesOnly: privacy.followedRepliesOnly,
          expectedEpoch: session,
        );
      }
      if (submit) {
        status = await widget.store.submitArticleDraft(
          draftID,
          expectedEpoch: session,
        );
      }
    } catch (error) {
      if (!mounted) return;
      // Quill offsets count UTF-16 text and one character per embedded block.
      final plainBody = operations.map((op) {
        final insert = op['insert'];
        return insert is String ? insert : '\uFFFC';
      }).join();
      final locations = <ModerationExcerpt, TextSelection>{};
      if (error is ApiFailure && error.code == 'CONTENT_REJECTED') {
        for (final violation in error.violations) {
          for (final excerpt in violation.excerpts) {
            final selection = _findExcerpt(excerpt, plainBody);
            if (selection != null) locations[excerpt] = selection;
          }
        }
      }
      final chosen = await showRequestFailure(
        context,
        error,
        canLocate: locations.containsKey,
      );
      if (!mounted) return;
      editor.readOnly = false;
      setState(() => pendingAction = null);
      if (chosen != null && locations[chosen] != null) {
        _revealExcerpt(chosen.field == 'title', locations[chosen]!);
      }
      return;
    }
    if (!mounted) return;
    setState(() => allowExit = true);
    Navigator.pop(context);
    toast(context, submit ? articleSubmissionMessage(status) : '草稿已保存');
  }

  TextSelection? _findExcerpt(ModerationExcerpt excerpt, String plainBody) {
    if (excerpt.field != 'title' && excerpt.field != 'body') return null;
    final inTitle = excerpt.field == 'title';
    var source = inTitle ? title.text : plainBody;
    var offset = 0;
    final block = excerpt.blockIndex;
    if (!inTitle && guidance && block != null && block != 0) return null;
    if (!inTitle && block != null) {
      final lines = source.split('\n');
      if (block < 0 || block >= lines.length) return null;
      for (var i = 0; i < block; i++) {
        offset += lines[i].length + 1;
      }
      source = lines[block];
    }
    final start = excerpt.indexIn(
      source,
      trimmed: inTitle || (guidance && block == null),
    );
    if (start == null) return null;
    return TextSelection(
      baseOffset: offset + start,
      extentOffset: offset + start + excerpt.text.length,
    );
  }

  void _revealExcerpt(bool inTitle, TextSelection selection) {
    if (pageScroll.hasClients) {
      if (inTitle) {
        pageScroll.jumpTo(0);
      } else if (editorKey.currentState == null) {
        pageScroll.jumpTo(pageScroll.position.maxScrollExtent);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (inTitle) {
        titleFocus.requestFocus();
        title.selection = selection;
        final field = titleFocus.context;
        if (field != null) Scrollable.ensureVisible(field);
      } else {
        bodyFocus.requestFocus();
        editor.updateSelection(selection, quill.ChangeSource.local);
        final render = editorKey.currentState?.renderEditor;
        if (render != null && render.attached && render.hasSize) {
          render.showOnScreen(
            rect: render.getLocalRectForCaret(selection.base),
          );
        }
      }
    });
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

  static const headingLevels = [
    quill.Attribute.h2,
    quill.Attribute.h3,
    quill.Attribute.h4,
    quill.Attribute.h5,
    quill.Attribute.h6,
  ];

  Object? get currentHeading =>
      editor.getSelectionStyle().attributes[quill.Attribute.header.key]?.value;

  /// The heading button opens a row of levels instead of applying one.
  Widget headingButton() {
    final active = currentHeading != null;
    return IconButton(
      tooltip: '标题',
      isSelected: active || headingPicker,
      style: IconButton.styleFrom(
        backgroundColor: active || headingPicker
            ? context.colors.accent.withValues(alpha: .08)
            : Colors.transparent,
      ).withoutHover(),
      onPressed: busy
          ? null
          : () {
              setState(() => headingPicker = !headingPicker);
              bodyFocus.requestFocus();
            },
      icon: AppIcon(
        AppIcons.heading,
        size: 20,
        color: active || headingPicker
            ? context.colors.accent
            : context.colors.ink,
      ),
    );
  }

  Widget headingChoices() => Row(
    key: const ValueKey('composer-heading-levels'),
    children: [
      for (final attribute in headingLevels)
        Expanded(
          child: Builder(
            builder: (context) {
              final active = currentHeading == attribute.value;
              return TextButton(
                key: ValueKey('composer-heading-${attribute.value}'),
                onPressed: busy
                    ? null
                    : () {
                        editor.formatSelection(
                          active
                              ? quill.Attribute.clone(attribute, null)
                              : attribute,
                        );
                        setState(() => headingPicker = false);
                        bodyFocus.requestFocus();
                      },
                style: TextButton.styleFrom(
                  foregroundColor: active
                      ? context.colors.accent
                      : context.colors.ink,
                  backgroundColor: active
                      ? context.colors.accent.withValues(alpha: .08)
                      : Colors.transparent,
                  minimumSize: const Size(0, 40),
                ).withoutHover(),
                child: Text(
                  'H${attribute.value}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            },
          ),
        ),
    ],
  );

  /// A chosen tag as it will look on the post, with a way to drop it.
  Widget tagChip(String tag) => ArticleHangTag(
    tag,
    key: ValueKey('composer-tag-$tag'),
    shade: tags.indexOf(tag).isOdd,
    onRemove: busy ? () {} : () => setState(() => tags.remove(tag)),
  );

  quill.DefaultTextBlockStyle style(
    double size, {
    bool bold = false,
    Color? color,
  }) => quill.DefaultTextBlockStyle(
    TextStyle(
      fontSize: size,
      height: ArticleRichBody.lineHeight,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      shadows: bold
          ? articleBoldShadows(context, color ?? context.colors.ink, size: size)
          : null,
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
      canPop: allowExit || (!dirty && !busy && panel == _ToolPanel.none),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (!busy && panel != _ToolPanel.none) {
          setState(() => panel = _ToolPanel.none);
          return;
        }
        exit();
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
                    onPressed: busy || !hasPublishableContent
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
              controller: pageScroll,
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
                  focusNode: titleFocus,
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
                Listener(
                  onPointerDown: (_) {
                    if (panel == _ToolPanel.insert ||
                        panel == _ToolPanel.settings) {
                      setState(() => panel = _ToolPanel.none);
                    }
                  },
                  child: ConstrainedBox(
                    // Tags sit right under the writing, so leave them in view.
                    constraints: BoxConstraints(
                      minHeight: tags.isEmpty ? 280 : 160,
                    ),
                    child: quill.QuillEditor.basic(
                      key: const ValueKey('composer-body'),
                      controller: editor,
                      focusNode: bodyFocus,
                      scrollController: bodyScroll,
                      config: quill.QuillEditorConfig(
                        editorKey: editorKey,
                        onLaunchUrl: (link) {
                          final topic = articleTopicName(link);
                          if (topic != null) {
                            openArticleTopic(context, widget.store, topic);
                          } else {
                            final url = articleWebLink(link);
                            if (url != null) openArticleLink(context, url);
                          }
                        },
                        scrollable: false,
                        minHeight: tags.isEmpty ? 280 : 160,
                        placeholder: guidance ? '想请教的问题…' : '写下你的经历与想法…',
                        embedBuilders: [_ArticleBlockEmbed(this)],
                        customStyles: quill.DefaultStyles(
                          bold: TextStyle(
                            fontWeight: FontWeight.w700,
                            shadows: articleBoldShadows(
                              context,
                              context.colors.ink,
                            ),
                          ),
                          paragraph: style(16),
                          h1: style(22, bold: true),
                          h2: style(19, bold: true),
                          h3: style(18, bold: true),
                          h4: style(17, bold: true),
                          h5: style(16, bold: true),
                          h6: style(15, bold: true),
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
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    key: const ValueKey('composer-tags'),
                    spacing: 6,
                    runSpacing: 8,
                    children: [for (final tag in tags) tagChip(tag)],
                  ),
                ],
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (uploading case final progress?)
                      uploadStatus(progress.done, progress.total),
                    _ComposerToolbar(state: this),
                  ],
                ),
              ),
      ),
    ),
  );
}
