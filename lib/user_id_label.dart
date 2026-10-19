import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_icons.dart';
import 'design.dart';

class UserIDLabel extends StatelessWidget {
  const UserIDLabel({
    super.key,
    required this.value,
    this.fontSize = 12,
    this.color,
    this.compact = false,
  });

  final String value;
  final double fontSize;
  final Color? color;
  final bool compact;

  Future<void> copy(BuildContext context) async {
    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (context.mounted) toast(context, '用户 ID 已复制');
    } catch (_) {
      if (context.mounted) toast(context, '复制失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(
        child: Text(
          '用户 ID：$value',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: fontSize,
            color: color ?? context.colors.muted,
          ),
        ),
      ),
      const SizedBox(width: 4),
      IconButton(
        key: const ValueKey('copy-user-id'),
        tooltip: '复制用户 ID',
        style: compact
            ? IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ).withoutHover()
            : null,
        constraints: BoxConstraints.tightFor(
          width: 32,
          height: compact ? 24 : 32,
        ),
        padding: EdgeInsets.all(compact ? 4 : 6),
        onPressed: value.isEmpty ? null : () => copy(context),
        icon: AppIcon(
          AppIcons.copy,
          size: 16,
          color: color ?? context.colors.muted,
        ),
      ),
    ],
  );
}
