import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'design.dart';

enum ResumeAddSource { assistance, manual, wechat, local }

Future<ResumeAddSource?> showResumeAddSheet(
  BuildContext context,
) => showModalBottomSheet<ResumeAddSource>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  backgroundColor: context.colors.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  ),
  builder: (context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              '添加简历',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          for (final (source, title, subtitle, icon) in [
            (
              ResumeAddSource.assistance,
              'AI生成简历',
              '问答创建或描述经历，生成专业简历',
              AppIcons.profileEdit,
            ),
            (ResumeAddSource.manual, '手动添加', '从空白简历开始填写', AppIcons.add),
            (ResumeAddSource.wechat, '从微信导入', '导入微信中的简历文件', AppIcons.wechat),
            (
              ResumeAddSource.local,
              '从手机文件导入',
              '选择 PDF、DOC 或 DOCX 文件',
              AppIcons.folder,
            ),
          ])
            ListTile(
              key: ValueKey('resume-add-${source.name}'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 2,
              ),
              leading: AppIcon(icon, size: 22, color: context.colors.accent),
              title: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: context.colors.muted),
              ),
              trailing: AppIcon(
                AppIcons.forward,
                size: 12,
                color: context.colors.muted,
              ),
              onTap: () => Navigator.pop(context, source),
            ),
        ],
      ),
    ),
  ),
);
