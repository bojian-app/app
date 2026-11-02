import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'app_action_sheet.dart';
import 'design.dart';
import 'resume_editor_typography.dart';

/// Document actions stay outside the paper and its export layout.
class ResumePreviewTools extends StatelessWidget {
  const ResumePreviewTools({
    super.key,
    required this.onEdit,
    required this.onTemplate,
    required this.onSwitchResume,
    required this.onCopy,
  });

  final VoidCallback onEdit, onTemplate, onSwitchResume;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) => Material(
    color: context.colors.surface,
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              tool(context, '编辑', AppIcons.edit, onEdit),
              tool(context, '模板', AppIcons.templates, onTemplate),
              tool(
                context,
                '切换简历',
                AppIcons.switchResume,
                onSwitchResume,
                key: const ValueKey('resume-toolbar-switch'),
              ),
              tool(
                context,
                '创建副本',
                AppIcons.copy,
                onCopy,
                key: const ValueKey('resume-toolbar-copy'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget tool(
    BuildContext context,
    String label,
    AppIconData icon,
    VoidCallback? onTap, {
    Key? key,
  }) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Semantics(
        button: true,
        enabled: onTap != null,
        child: InkWell(
          key: key,
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(
                    icon,
                    size: 20,
                    color: onTap == null
                        ? context.colors.muted
                        : context.colors.ink,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: ResumeEditorTypography.caption.copyWith(
                      fontWeight: FontWeight.w500,
                      color: onTap == null
                          ? context.colors.muted
                          : context.colors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Same visual height and touch targets as the profile actions capsule.
class ResumePreviewActions extends StatelessWidget {
  const ResumePreviewActions({
    super.key,
    required this.onMore,
    required this.onClose,
    this.closeLabel = '关闭预览',
  });
  final VoidCallback? onMore;
  final VoidCallback? onClose;
  final String closeLabel;
  @override
  Widget build(BuildContext context) {
    final color = context.colors.ink;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            right: 0,
            height: 32,
            child: IgnorePointer(
              child: DecoratedBox(
                key: const ValueKey('resume-actions-capsule'),
                decoration: ShapeDecoration(
                  color: context.isDark
                      ? color.withValues(alpha: .04)
                      : Colors.transparent,
                  shape: StadiumBorder(
                    side: BorderSide(color: color.withValues(alpha: .24)),
                  ),
                ),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 44,
                child: IconButton(
                  key: const ValueKey('resume-more'),
                  tooltip: '更多操作',
                  onPressed: onMore,
                  icon: AppIcon(AppIcons.more, size: 18, color: color),
                ),
              ),
              SizedBox(
                width: 1,
                height: 16,
                child: ColoredBox(color: color.withValues(alpha: .28)),
              ),
              SizedBox.square(
                dimension: 44,
                child: IconButton(
                  key: const ValueKey('resume-close'),
                  tooltip: closeLabel,
                  onPressed: onClose,
                  icon: AppIcon(AppIcons.power, size: 18, color: color),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ResumeEntryActionsSheet extends StatelessWidget {
  const ResumeEntryActionsSheet({
    super.key,
    required this.canDelete,
    this.entryKind = 'work',
    this.entryLabel = '工作经历',
  });

  final bool canDelete;
  final String entryKind, entryLabel;

  @override
  Widget build(BuildContext context) => AppActionSheet(
    title: entryLabel,
    subtitle: '$entryLabel操作',
    cancelKey: ValueKey('$entryKind-menu-cancel'),
    actions: [
      AppSheetAction(
        value: 'add',
        label: entryKind == 'skill' || entryKind == 'certificate'
            ? '新增$entryLabel'
            : '新增经历',
        semanticLabel: '添加$entryLabel',
        icon: AppIcons.add,
        key: ValueKey('$entryKind-action-add'),
      ),
      if (canDelete)
        AppSheetAction(
          value: 'delete',
          label: '删除当前',
          semanticLabel: '删除当前$entryLabel',
          icon: AppIcons.delete,
          destructive: true,
          key: ValueKey('$entryKind-action-delete'),
        ),
    ],
  );
}

class ResumeActionsSheet extends StatelessWidget {
  const ResumeActionsSheet({
    super.key,
    required this.title,
    this.monochrome = false,
  });
  final String title;
  final bool monochrome;

  @override
  Widget build(BuildContext context) => AppActionSheet(
    title: title,
    subtitle: '分享给指定用户',
    onHeaderTap: () => Navigator.pop(context, 'share-to-user'),
    cancelKey: const ValueKey('resume-menu-cancel'),
    actions: [
      AppSheetAction(
        value: 'rename',
        label: '重命名',
        icon: AppIcons.edit,
        key: ValueKey('resume-action-rename'),
      ),
      AppSheetAction(
        value: 'download',
        label: '下载简历',
        icon: AppIcons.download,
        key: ValueKey('resume-action-download'),
      ),
      AppSheetAction(
        value: 'delete',
        label: '删除',
        icon: AppIcons.delete,
        destructive: true,
        key: ValueKey('resume-action-delete'),
      ),
      AppSheetAction(
        value: 'request-help',
        label: '链接分享',
        icon: AppIcons.share,
        key: ValueKey('resume-action-request-help'),
      ),
      AppSheetAction(
        value: 'ai-optimize',
        label: 'AI优化',
        icon: AppIcons.aiOptimize,
        key: ValueKey('resume-action-ai-optimize'),
      ),
      AppSheetAction(
        value: 'share-post',
        label: '发表动态',
        icon: AppIcons.share,
        key: ValueKey('resume-action-share-post'),
      ),
      AppSheetAction(
        value: 'monochrome-preview',
        label: monochrome ? '彩色预览' : '黑白预览',
        icon: AppIcons.monochrome,
        key: ValueKey('resume-action-monochrome-preview'),
      ),
    ],
  );
}
