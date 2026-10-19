import 'package:flutter/widgets.dart';

import 'confirmation_dialog.dart';

Future<bool?> showSignOutDialog(BuildContext context) => showAppConfirmation(
  context,
  dialogKey: const ValueKey('sign-out-dialog'),
  title: '确定要退出登录么？',
  cancelLabel: '我再看看',
  confirmLabel: '狠心离开',
  confirmKey: const ValueKey('confirm-sign-out'),
  destructive: true,
);
