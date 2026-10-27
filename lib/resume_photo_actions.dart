import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'design.dart';
import 'resume_editor_typography.dart';

enum ResumePhotoAction { delete, modify }

Future<ResumePhotoAction?> showResumePhotoActions(
  BuildContext context, {
  required bool hasPhoto,
}) => showModalBottomSheet<ResumePhotoAction>(
  context: context,
  useRootNavigator: true,
  useSafeArea: true,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  barrierColor: Colors.black.withValues(alpha: .4),
  builder: (context) => _PhotoActionsSheet(hasPhoto: hasPhoto),
);

class _PhotoActionsSheet extends StatelessWidget {
  const _PhotoActionsSheet({required this.hasPhoto});

  final bool hasPhoto;

  @override
  Widget build(BuildContext context) {
    Widget action(String label, AppIconData icon, ResumePhotoAction value) =>
        TextButton(
          key: ValueKey('resume-photo-action-${value.name}'),
          style: TextButton.styleFrom(
            foregroundColor: context.colors.ink,
            minimumSize: const Size.fromHeight(56),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            shape: const RoundedRectangleBorder(),
            textStyle: ResumeEditorTypography.action,
          ).withoutHover(),
          onPressed: () => Navigator.of(context).pop(value),
          child: Row(
            children: [
              AppIcon(icon, size: 22),
              const SizedBox(width: 16),
              Expanded(child: Text(label)),
            ],
          ),
        );

    return Material(
      key: const ValueKey('resume-photo-actions-sheet'),
      color: context.colors.inset,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: (MediaQuery.sizeOf(context).height * .4).clamp(260, 360),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(width: 48),
                    const Expanded(
                      child: Text(
                        '编辑照片',
                        textAlign: TextAlign.center,
                        style: ResumeEditorTypography.title,
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('resume-photo-actions-close'),
                      tooltip: '关闭',
                      constraints: const BoxConstraints.tightFor(
                        width: 48,
                        height: 48,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const AppIcon(AppIcons.close, size: 22),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Material(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasPhoto) ...[
                            action(
                              '删除照片',
                              AppIcons.delete,
                              ResumePhotoAction.delete,
                            ),
                            Divider(
                              height: 1,
                              indent: 54,
                              endIndent: 16,
                              color: context.colors.border,
                            ),
                          ],
                          action(
                            hasPhoto ? '修改照片' : '添加照片',
                            AppIcons.edit,
                            ResumePhotoAction.modify,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
