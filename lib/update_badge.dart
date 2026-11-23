import 'package:flutter/material.dart';

import 'app_update.dart';

class UpdateBadge extends StatelessWidget {
  const UpdateBadge({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppUpdates.instance,
    child: child,
    builder: (context, child) => Badge(
      isLabelVisible: AppUpdates.instance.hasUpdate,
      backgroundColor: const Color(0xFFE5322D),
      smallSize: 7,
      child: child,
    ),
  );
}
