import 'package:flutter/material.dart';

import 'design.dart';

enum ProfileEditAction {
  avatar('更改头像'),
  bio('编辑个人简介'),
  settings('设置个人资料');

  const ProfileEditAction(this.label);
  final String label;
}

Future<ProfileEditAction?> showProfileEditActions(BuildContext context) {
  dismissKeyboard();
  return showModalBottomSheet<ProfileEditAction>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .3),
    builder: (context) => _ProfileEditActions(),
  );
}

class _ProfileEditActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget action(String label, String key, ProfileEditAction? value) =>
        TextButton(
          key: ValueKey(key),
          style: TextButton.styleFrom(
            foregroundColor: context.colors.ink,
            minimumSize: const Size.fromHeight(58),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            shape: const RoundedRectangleBorder(),
            textStyle: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontSize: 17, fontWeight: FontWeight.w500),
          ).withoutHover(),
          onPressed: () => Navigator.of(context).pop(value),
          child: Text(label, textAlign: TextAlign.center),
        );

    return Material(
      key: const ValueKey('profile-edit-actions'),
      color: context.colors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final item in ProfileEditAction.values) ...[
                      if (item != ProfileEditAction.values.first)
                        Divider(
                          height: 1,
                          thickness: .5,
                          color: context.colors.border,
                        ),
                      action(item.label, 'profile-edit-${item.name}', item),
                    ],
                  ],
                ),
              ),
            ),
            ColoredBox(
              color: context.colors.canvas,
              child: const SizedBox(height: 8),
            ),
            action('取消', 'profile-edit-cancel', null),
          ],
        ),
      ),
    );
  }
}
