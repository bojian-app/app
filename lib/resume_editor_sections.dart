import 'app_page_bar.dart';

import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'design.dart';
import 'resume_editor_typography.dart';
import 'resume_preview_controls.dart';

class ResumeOverviewCard extends StatelessWidget {
  const ResumeOverviewCard({
    super.key,
    required this.label,
    required this.onEdit,
    required this.child,
    this.title,
    this.draggable = false,
    this.compact = false,
  });

  final String label;
  final String? title;
  final bool draggable;
  final bool compact;
  final VoidCallback? onEdit;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        label: label,
        button: true,
        child: InkWell(
          onTap: onEdit,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: compact ? 16 : 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title != null) ...[
                  Row(
                    children: [
                      if (draggable) ...[
                        AppIcon(
                          AppIcons.drag,
                          size: 16,
                          color: context.colors.muted,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          title!,
                          style: ResumeEditorTypography.sectionTitle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      AppIcon(
                        AppIcons.edit,
                        size: 18,
                        color: context.colors.muted,
                      ),
                    ],
                  ),
                  if (!compact) const SizedBox(height: 16),
                ],
                if (!compact) child,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class ResumeOverviewEntry extends StatelessWidget {
  const ResumeOverviewEntry({
    super.key,
    required this.title,
    this.meta = const [],
    this.description = '',
    this.titleMuted = false,
    this.descriptionMuted = false,
    this.onTap,
  });

  final String title, description;
  final List<String> meta;
  final bool titleMuted, descriptionMuted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Text(
            title,
            style: ResumeEditorTypography.entryTitle.copyWith(
              color: titleMuted ? context.colors.muted : context.colors.ink,
            ),
          ),
        if (meta.isNotEmpty) ...[
          if (title.isNotEmpty) const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final item in meta)
                Text(
                  item,
                  style: ResumeEditorTypography.caption.copyWith(
                    color: context.colors.muted,
                  ),
                ),
            ],
          ),
        ],
        if (description.isNotEmpty) ...[
          if (title.isNotEmpty || meta.isNotEmpty) const SizedBox(height: 8),
          Text(
            description,
            style: ResumeEditorTypography.body.copyWith(
              color: descriptionMuted
                  ? context.colors.muted
                  : context.colors.ink,
            ),
          ),
        ],
      ],
    );
    return onTap == null
        ? content
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: content,
          );
  }
}

class ResumeSectionEditorPage extends StatefulWidget {
  const ResumeSectionEditorPage({
    super.key,
    required this.title,
    required this.changes,
    required this.isBusy,
    required this.fields,
    this.body,
    this.validate,
    this.onSave,
    this.onMore,
    this.showErrors = false,
  });

  final String title;
  final Listenable changes;
  final bool Function() isBusy;
  final List<Widget> Function() fields;
  final Widget Function()? body;
  final bool Function()? validate;
  final Future<bool> Function()? onSave;
  final void Function(BuildContext)? onMore;
  final bool showErrors;

  @override
  State<ResumeSectionEditorPage> createState() =>
      _ResumeSectionEditorPageState();
}

class _ResumeSectionEditorPageState extends State<ResumeSectionEditorPage> {
  final formKey = GlobalKey<FormState>();
  bool _showErrors = false;
  bool _submitting = false;

  Future<void> _save() async {
    if (_submitting || widget.isBusy()) return;
    final valid = widget.validate?.call() ?? true;
    final formValid = formKey.currentState!.validate();
    if (!valid || !formValid) {
      setState(() => _showErrors = true);
      return;
    }
    dismissKeyboard();
    setState(() => _submitting = true);
    final saved = await (widget.onSave?.call() ?? Future.value(true));
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!saved) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.changes,
    builder: (context, _) {
      final compact =
          MediaQuery.sizeOf(context).height -
              MediaQuery.viewInsetsOf(context).bottom <
          280;
      return PopScope(
        canPop: !_submitting,
        child: Scaffold(
          backgroundColor: context.colors.surface,
          appBar: AppPageBar(
            title: Text(widget.title),
            actions: [
              if (widget.onMore == null) const DismissKeyboardButton(),
              if (compact)
                TextButton(
                  key: const ValueKey('resume-section-save'),
                  onPressed: _submitting || widget.isBusy() ? null : _save,
                  child: Text(
                    _submitting ? '保存中…' : '保存',
                    style: ResumeEditorTypography.action,
                  ),
                ),
              if (widget.onMore != null)
                ResumePreviewActions(
                  onMore: _submitting || widget.isBusy()
                      ? null
                      : () => widget.onMore!(context),
                  onClose: _submitting || widget.isBusy()
                      ? null
                      : () => Navigator.maybePop(context),
                  closeLabel: '关闭编辑',
                ),
            ],
          ),
          bottomNavigationBar: compact
              ? null
              : Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: FilledButton(
                      key: const ValueKey('resume-section-save'),
                      onPressed: _submitting || widget.isBusy() ? null : _save,
                      child: Text(
                        _submitting ? '保存中…' : '保存',
                        style: ResumeEditorTypography.action,
                      ),
                    ),
                  ),
                ),
          body: Form(
            key: formKey,
            autovalidateMode: widget.showErrors || _showErrors
                ? AutovalidateMode.always
                : AutovalidateMode.onUserInteraction,
            child: NotificationListener<ScrollStartNotification>(
              onNotification: (notification) {
                if (notification.dragDetails != null) dismissKeyboard();
                return false;
              },
              child:
                  widget.body?.call() ??
                  ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: widget.fields(),
                      ),
                    ],
                  ),
            ),
          ),
        ),
      );
    },
  );
}

/// Each entry has its own vertical scroll area within a horizontal pager.
/// Controllers are owned by the editor so offscreen entries retain all edits.
class ResumeEntryPager extends StatefulWidget {
  const ResumeEntryPager({
    super.key,
    required this.count,
    required this.index,
    required this.onChanged,
    required this.itemKey,
    required this.itemBuilder,
    required this.emptyState,
    this.entryKind = 'work',
    this.entryLabel = '工作经历',
  });

  final int count, index;
  final String entryKind, entryLabel;
  final ValueChanged<int> onChanged;
  final Key Function(int) itemKey;
  final Widget Function(int) itemBuilder;
  final Widget emptyState;

  @override
  State<ResumeEntryPager> createState() => _ResumeEntryPagerState();
}

class _ResumeEntryPagerState extends State<ResumeEntryPager> {
  late PageController _controller = PageController(
    initialPage: widget.index,
    keepPage: false,
  );

  @override
  void didUpdateWidget(ResumeEntryPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count != oldWidget.count) {
      // Recreate the position when adding/removing entries. Jumping before the
      // lazy viewport updates its extent can report an intermediate page and
      // overwrite the requested new-entry index.
      final previous = _controller;
      _controller = PageController(initialPage: widget.index, keepPage: false);
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
      return;
    }
    if (widget.index != oldWidget.index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_controller.hasClients || widget.count == 0) return;
        if (_controller.page!.round() != widget.index) {
          _controller.jumpToPage(widget.index);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (!_controller.hasClients || index < 0 || index >= widget.count) return;
    dismissKeyboard();
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _pageArrow(int index, {required bool previous}) {
    final target = index + (previous ? -1 : 1);
    final enabled = target >= 0 && target < widget.count;
    return IconButton(
      key: ValueKey(
        '${widget.entryKind}-${previous ? 'previous' : 'next'}-$index',
      ),
      tooltip: previous ? '上一条${widget.entryLabel}' : '下一条${widget.entryLabel}',
      onPressed: enabled ? () => _goTo(target) : null,
      icon: AppIcon(
        previous ? AppIcons.back : AppIcons.forward,
        size: 18,
        color: enabled
            ? context.colors.accent
            : context.colors.muted.withValues(alpha: .4),
      ),
    );
  }

  Widget _page(int? index) => ListView(
    key: index == null ? null : widget.itemKey(index),
    primary: false,
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
    children: [
      // Keep the entire form laid out for validation and large text support.
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (index != null) widget.itemBuilder(index),
          if (widget.count > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Semantics(
                liveRegion: true,
                label:
                    '第 ${index! + 1} 条${widget.entryLabel}，共 ${widget.count} 条，左右滑动切换',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _pageArrow(index, previous: true),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          '左右滑动切换',
                          textAlign: TextAlign.center,
                          style: ResumeEditorTypography.caption.copyWith(
                            color: context.colors.muted,
                          ),
                        ),
                      ),
                    ),
                    _pageArrow(index, previous: false),
                  ],
                ),
              ),
            ),
          if (index == null) widget.emptyState,
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => widget.count == 0
      ? _page(null)
      : KeyedSubtree(
          key: ObjectKey(_controller),
          child: PageView.builder(
            key: ValueKey('resume-${widget.entryKind}-pager'),
            controller: _controller,
            itemCount: widget.count,
            onPageChanged: widget.onChanged,
            itemBuilder: (context, index) => _page(index),
          ),
        );
}
