import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'panel_sheet.dart';

enum ResumePhotoAction { delete, modify }

Future<ResumePhotoAction?> showResumePhotoActions(
  BuildContext context, {
  required bool hasPhoto,
}) => showPanelSheet<ResumePhotoAction>(
  context,
  useRootNavigator: true,
  builder: (context) => _PhotoActionsSheet(hasPhoto: hasPhoto),
);

class _PhotoActionsSheet extends StatelessWidget {
  const _PhotoActionsSheet({required this.hasPhoto});

  final bool hasPhoto;

  @override
  Widget build(BuildContext context) {
    Widget action(String label, AppIconData icon, ResumePhotoAction value) =>
        PanelAction(
          key: ValueKey('resume-photo-action-${value.name}'),
          label: label,
          icon: icon,
          onPressed: () => Navigator.of(context).pop(value),
        );

    return PanelSheet(
      key: const ValueKey('resume-photo-actions-sheet'),
      title: '编辑照片',
      closeKey: const ValueKey('resume-photo-actions-close'),
      child: SingleChildScrollView(
        child: PanelGroup(
          children: [
            if (hasPhoto)
              action('删除照片', AppIcons.delete, ResumePhotoAction.delete),
            action(
              hasPhoto ? '修改照片' : '添加照片',
              AppIcons.edit,
              ResumePhotoAction.modify,
            ),
          ],
        ),
      ),
    );
  }
}
