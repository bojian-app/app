import 'package:flutter/material.dart';

import 'app_action_sheet.dart';
import 'design.dart';

enum ProfileEditAction {
  avatar('更改头像'),
  nickname('更改昵称'),
  bio('编辑个人简介');

  const ProfileEditAction(this.label);
  final String label;
}

Future<ProfileEditAction?> showProfileEditActions(BuildContext context) {
  dismissKeyboard();
  return showAppListSheet<ProfileEditAction>(
    context,
    sheet: AppListSheet(
      key: const ValueKey('profile-edit-actions'),
      cancelKey: const ValueKey('profile-edit-cancel'),
      items: [
        for (final item in ProfileEditAction.values)
          AppListSheetItem(
            label: item.label,
            key: ValueKey('profile-edit-${item.name}'),
            value: item,
          ),
      ],
    ),
  );
}
