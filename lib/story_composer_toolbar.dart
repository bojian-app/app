part of 'story_composer.dart';

class _ComposerToolbar extends StatelessWidget {
  const _ComposerToolbar({required this.state});
  final _StoryComposerState state;

  @override
  Widget build(BuildContext context) {
    final panel = state.panel;
    final privacy = state.privacy;
    return TextFieldTapRegion(
      child: SafeArea(
        top: false,
        child: Ink(
          decoration: BoxDecoration(
            color: context.colors.surface,
            border: Border(top: BorderSide(color: context.colors.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (panel == _ToolPanel.format && state.headingPicker)
                state.headingChoices(),
              if (panel == _ToolPanel.format)
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        key: const ValueKey('composer-format-bar'),
                        scrollDirection: Axis.horizontal,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.manual,
                        child: Row(
                          children: [
                            state.format(
                              '粗体',
                              AppIcons.bold,
                              quill.Attribute.bold,
                            ),
                            state.format(
                              '无序列表',
                              AppIcons.bullets,
                              quill.Attribute.ul,
                            ),
                            state.format(
                              '有序列表',
                              AppIcons.numbering,
                              quill.Attribute.ol,
                            ),
                            state.format(
                              '斜体',
                              AppIcons.italic,
                              quill.Attribute.italic,
                            ),
                            state.format(
                              '下划线',
                              AppIcons.underline,
                              quill.Attribute.underline,
                            ),
                            state.headingButton(),
                            state.format(
                              '引用',
                              AppIcons.quote,
                              quill.Attribute.blockQuote,
                            ),
                            IconButton(
                              tooltip: '撤销',
                              icon: const AppIcon(AppIcons.undo, size: 20),
                              onPressed: state.busy || !state.editor.hasUndo
                                  ? null
                                  : state.editor.undo,
                            ),
                            IconButton(
                              tooltip: '重做',
                              icon: const AppIcon(AppIcons.redo, size: 20),
                              onPressed: state.busy || !state.editor.hasRedo
                                  ? null
                                  : state.editor.redo,
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭文字格式',
                      onPressed: () => state.changePanel(_ToolPanel.format),
                      icon: const AppIcon(AppIcons.close, size: 20),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(
                      tooltip: '图片或视频',
                      icon: const AppIcon(AppIcons.imageCache, size: 22),
                      onPressed: state.busy
                          ? null
                          : () => state.insertTool('图片或视频'),
                    ),
                    IconButton(
                      tooltip: '话题',
                      icon: const Icon(Icons.tag, size: 23),
                      onPressed: state.busy
                          ? null
                          : () => state.insertTool('话题'),
                    ),
                    IconButton(
                      tooltip: '文字格式',
                      icon: const Icon(Icons.text_fields, size: 22),
                      onPressed: state.busy
                          ? null
                          : () => state.changePanel(_ToolPanel.format),
                    ),
                    IconButton(
                      tooltip: '更多',
                      icon: const AppIcon(AppIcons.addCircle, size: 22),
                      color: panel == _ToolPanel.insert
                          ? context.colors.accent
                          : null,
                      onPressed: state.busy
                          ? null
                          : () => state.changePanel(_ToolPanel.insert),
                    ),
                    const DismissKeyboardButton(),
                    IconButton(
                      tooltip: '发布设置',
                      icon: const AppIcon(AppIcons.settings, size: 22),
                      color: panel == _ToolPanel.settings
                          ? context.colors.accent
                          : null,
                      onPressed: state.busy
                          ? null
                          : () => state.changePanel(_ToolPanel.settings),
                    ),
                  ],
                ),
              if (panel == _ToolPanel.insert || panel == _ToolPanel.settings)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .32,
                  ),
                  child: SingleChildScrollView(
                    child: panel == _ToolPanel.insert
                        ? Material(
                            color: context.colors.canvas,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 22,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  for (final (name, icon) in [
                                    (
                                      '投票',
                                      const Icon(Icons.poll_outlined, size: 25),
                                    ),
                                    (
                                      '链接',
                                      const AppIcon(AppIcons.link, size: 25),
                                    ),
                                  ])
                                    TextButton(
                                      onPressed: () => state.insertTool(name),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(11),
                                            decoration: BoxDecoration(
                                              color: context.colors.surface,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: icon,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            name,
                                            style: TextStyle(
                                              color: context.colors.ink,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const AppIcon(
                                  AppIcons.privacyPolicy,
                                  size: 20,
                                ),
                                title: const Text('隐私权限'),
                                subtitle: Text(
                                  [
                                    switch (privacy.visibility) {
                                      'PRIVATE' => '私密',
                                      'FRIENDS' => '好友可见',
                                      _ => '公开',
                                    },
                                    if (privacy.followedRepliesOnly) '仅我关注的可回复',
                                  ].join(' · '),
                                ),
                                trailing: const AppIcon(
                                  AppIcons.forward,
                                  size: 16,
                                ),
                                onTap: state.choosePrivacy,
                              ),
                              ListTile(
                                leading: const AppIcon(
                                  AppIcons.about,
                                  size: 20,
                                ),
                                title: const Text('内容声明'),
                                subtitle:
                                    state.declaration.label.isEmpty &&
                                        !state.declaration.watermark
                                    ? null
                                    : Text(
                                        [
                                          if (state
                                              .declaration
                                              .label
                                              .isNotEmpty)
                                            state.declaration.label,
                                          if (state.declaration.watermark)
                                            '图片水印',
                                        ].join(' · '),
                                      ),
                                trailing: const AppIcon(
                                  AppIcons.forward,
                                  size: 16,
                                ),
                                onTap: state.chooseDeclaration,
                              ),
                            ],
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptionEditor extends StatefulWidget {
  const _CaptionEditor({required this.initial});
  final String initial;
  @override
  State<_CaptionEditor> createState() => _CaptionEditorState();
}

class _CaptionEditorState extends State<_CaptionEditor> {
  late final controller = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(child: Text('编辑说明')),
              TextButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('完成'),
              ),
            ],
          ),
          TextField(
            controller: controller,
            autofocus: true,
            minLines: 1,
            maxLines: 3,
            maxLength: 200,
            decoration: const InputDecoration(hintText: '添加说明'),
          ),
        ],
      ),
    ),
  );
}
