import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'design.dart';
import 'resume_editor_typography.dart';

class ResumeOverviewCard extends StatelessWidget {
  const ResumeOverviewCard({
    super.key,
    required this.label,
    required this.onEdit,
    required this.child,
    this.title,
  });

  final String label;
  final String? title;
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
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title!,
                          style: ResumeEditorTypography.title,
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
                  const SizedBox(height: 16),
                ],
                child,
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
    this.meta = '',
    this.description = '',
  });

  final String title, meta, description;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (title.isNotEmpty)
        Text(title, style: ResumeEditorTypography.entryTitle),
      if (meta.isNotEmpty) ...[
        if (title.isNotEmpty) const SizedBox(height: 4),
        Text(
          meta,
          style: ResumeEditorTypography.caption.copyWith(
            color: context.colors.muted,
          ),
        ),
      ],
      if (description.isNotEmpty) ...[
        if (title.isNotEmpty || meta.isNotEmpty) const SizedBox(height: 8),
        Text(description, style: ResumeEditorTypography.body),
      ],
    ],
  );
}

class ResumeSectionEditorPage extends StatefulWidget {
  const ResumeSectionEditorPage({
    super.key,
    required this.title,
    required this.changes,
    required this.isBusy,
    required this.fields,
    this.showErrors = false,
  });

  final String title;
  final Listenable changes;
  final bool Function() isBusy;
  final List<Widget> Function() fields;
  final bool showErrors;

  @override
  State<ResumeSectionEditorPage> createState() =>
      _ResumeSectionEditorPageState();
}

class _ResumeSectionEditorPageState extends State<ResumeSectionEditorPage> {
  final formKey = GlobalKey<FormState>();

  void _save() {
    if (widget.isBusy() || !formKey.currentState!.validate()) return;
    dismissKeyboard();
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
      return Scaffold(
        backgroundColor: context.colors.surface,
        appBar: AppBar(
          title: Text(widget.title, style: ResumeEditorTypography.title),
          centerTitle: false,
          backgroundColor: context.colors.surface,
          actions: [
            const DismissKeyboardButton(),
            if (compact)
              TextButton(
                key: const ValueKey('resume-section-save'),
                onPressed: widget.isBusy() ? null : _save,
                child: const Text('保存', style: ResumeEditorTypography.action),
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
                    onPressed: widget.isBusy() ? null : _save,
                    child: const Text(
                      '保存',
                      style: ResumeEditorTypography.action,
                    ),
                  ),
                ),
              ),
        body: Form(
          key: formKey,
          autovalidateMode: widget.showErrors
              ? AutovalidateMode.always
              : AutovalidateMode.onUserInteraction,
          child: NotificationListener<ScrollStartNotification>(
            onNotification: (notification) {
              if (notification.dragDetails != null) dismissKeyboard();
              return false;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
      );
    },
  );
}
