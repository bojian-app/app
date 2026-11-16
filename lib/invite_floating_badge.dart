import 'package:flutter/material.dart';

import 'app_store.dart';
import 'invitation_dialog.dart';

/// The "invite friends" entry floating at the bottom right of discovery. It
/// keeps gently growing and shrinking to draw the eye.
class InviteFloatingBadge extends StatefulWidget {
  const InviteFloatingBadge({super.key, required this.store});
  final AppStore store;

  /// Widget tests turn the endless pulse off so `pumpAndSettle` can settle.
  @visibleForTesting
  static bool pulse = true;

  @override
  State<InviteFloatingBadge> createState() => _InviteFloatingBadgeState();
}

class _InviteFloatingBadgeState extends State<InviteFloatingBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _scale = Tween(
    begin: .9,
    end: 1.04,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect the system "reduce motion" setting.
    if (!InviteFloatingBadge.pulse || MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '邀请好友领福利',
    excludeSemantics: true,
    child: GestureDetector(
      key: const ValueKey('discovery-invite'),
      behavior: HitTestBehavior.opaque,
      onTap: () => showInvitationDialog(context, widget.store),
      child: ScaleTransition(
        scale: _scale,
        child: Image.asset(
          'assets/membership/invite_badge.png',
          // Fixed box (image is 360 × 326) so the tap area exists before
          // the image has decoded.
          width: 96,
          height: 96 * 326 / 360,
          fit: BoxFit.contain,
          cacheWidth: 360,
          filterQuality: FilterQuality.medium,
        ),
      ),
    ),
  );
}
