import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'app_store.dart';
import 'design.dart';
import 'messages_page.dart';

class MessagesButton extends StatefulWidget {
  const MessagesButton({
    super.key,
    required this.store,
    this.color,
    this.icon = AppIcons.inbox,
    this.iconSize = 24,
  });
  final AppStore store;
  final Color? color;
  final AppIconData icon;
  final double iconSize;

  @override
  State<MessagesButton> createState() => _MessagesButtonState();
}

class _MessagesButtonState extends State<MessagesButton> {
  bool opening = false;

  Future<void> open() async {
    if (opening || ModalRoute.of(context)?.isCurrent != true) return;
    setState(() => opening = true);
    try {
      await openPage(
        context,
        MessagesPage(store: widget.store, standalone: true),
      );
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final unread = widget.store.unread;
      return Semantics(
        label: '消息',
        value: unread > 0 ? '$unread条未读消息' : null,
        button: true,
        onTap: opening ? null : open,
        excludeSemantics: true,
        child: IconButton(
          tooltip: '消息',
          onPressed: opening ? null : open,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              AppIcon(widget.icon, size: widget.iconSize, color: widget.color),
              if (unread > 0)
                PositionedDirectional(
                  top: -8,
                  end: -13,
                  child: Container(
                    key: const ValueKey('messages-unread-badge'),
                    // Wider than tall, so even one digit sits in an oval.
                    constraints: const BoxConstraints(minWidth: 24),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCC4939),
                      border: Border.all(
                        color: context.colors.surface,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(
                        fontSize: 9,
                        height: 1.2,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
