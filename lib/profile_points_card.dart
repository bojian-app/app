import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_icons.dart';
import 'app_store.dart';
import 'design.dart';

class ProfilePointsCard extends StatefulWidget {
  const ProfilePointsCard({super.key, required this.store});
  final AppStore store;
  @override
  State<ProfilePointsCard> createState() => _ProfilePointsCardState();
}

class _ProfilePointsCardState extends State<ProfilePointsCard>
    with SingleTickerProviderStateMixin {
  late final flight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late final initialBalance = widget.store.points?.toDouble() ?? 0;
  bool busy = false;
  int? received;

  Future<void> claim() async {
    final store = widget.store;
    if (busy || store.rewardClaimed || store.pending.contains('reward')) return;
    final epoch = store.epoch;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    setState(() {
      busy = true;
      received = null;
    });
    flight.reset();
    try {
      final amount = await store.claimReward();
      if (!mounted || epoch != store.epoch || amount == null) return;
      setState(() => received = amount);
      if (amount > 0 && !reduceMotion) {
        HapticFeedback.lightImpact();
        flight.forward(from: 0);
      }
    } catch (e) {
      if (mounted && epoch == store.epoch) toast(context, '$e');
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final store = widget.store;
      final disabled =
          busy ||
          store.pending.contains('reward') ||
          store.rewardClaimed ||
          store.rewardPoints == null;
      final reduced = MediaQuery.disableAnimationsOf(context);
      const buttonTextStyle = TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
      );
      // Reserve the longest label before claiming so all three states keep the
      // same bounds, including when the system text size is increased.
      final buttonLabel = TextPainter(
        text: TextSpan(
          text: '今日已领取',
          style: DefaultTextStyle.of(context).style.merge(buttonTextStyle),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final buttonSize = Size(
        math.max(96, buttonLabel.width + 28),
        math.max(42, buttonLabel.height + 20),
      );
      buttonLabel.dispose();
      return RepaintBoundary(
        child: Container(
          key: const ValueKey('profile-points-card'),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF305EDA), Color(0xFF1842A6)],
            ),
          ),
          child: Stack(
            children: [
              const Positioned(
                right: -35,
                top: -40,
                child: IgnorePointer(child: _OrbitDecoration()),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const AppIcon(
                          AppIcons.coins,
                          size: 18,
                          color: Color(0xFFFFD985),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '我的积分',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFDCE6FF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Semantics(
                            label: store.points == null
                                ? '积分暂不可用'
                                : '可用积分 ${store.points}',
                            excludeSemantics: true,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(
                                begin: initialBalance,
                                end: store.points?.toDouble() ?? initialBalance,
                              ),
                              duration: reduced
                                  ? Duration.zero
                                  : const Duration(milliseconds: 650),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, _) => Text(
                                store.points == null ? '—' : '${value.round()}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 36,
                                  height: 1.2,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          key: const ValueKey('profile-claim-reward'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFFE4A7),
                            foregroundColor: const Color(0xFF453510),
                            disabledBackgroundColor: Colors.white.withValues(
                              alpha: .13,
                            ),
                            disabledForegroundColor: const Color(0xFFDCE6FF),
                            fixedSize: buttonSize,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            textStyle: buttonTextStyle,
                          ),
                          onPressed: disabled ? null : claim,
                          child: Text(
                            busy
                                ? '领取中…'
                                : received != null || store.rewardClaimed
                                ? '今日已领取'
                                : '领取积分',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: .14),
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        received != null && received! > 0
                            ? '+$received 积分已到账'
                            : store.rewardClaimed
                            ? '今日奖励已领取'
                            : store.rewardPoints == null
                            ? '每日奖励加载中'
                            : '每日奖励 +${store.rewardPoints} 积分',
                        key: const ValueKey('profile-reward-status'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: received != null && received! > 0
                              ? const Color(0xFFFFE4A7)
                              : const Color(0xFFDCE6FF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(painter: _RewardFlight(flight)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  @override
  void dispose() {
    flight.dispose();
    super.dispose();
  }
}

class _OrbitDecoration extends StatelessWidget {
  const _OrbitDecoration();
  @override
  Widget build(BuildContext context) => Container(
    width: 155,
    height: 155,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white.withValues(alpha: .06), width: 20),
    ),
    child: Center(
      child: Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: .08),
            width: 1,
          ),
        ),
      ),
    ),
  );
}

class _RewardFlight extends CustomPainter {
  _RewardFlight(this.animation) : super(repaint: animation);
  final Animation<double> animation;
  @override
  void paint(Canvas canvas, Size size) {
    final progress = animation.value;
    if (progress <= 0 || progress >= 1) return;
    final origin = Offset(size.width - 65, 77);
    final target = Offset(65, 68);
    for (var i = 0; i < 6; i++) {
      final t = ((progress - i * .055) / .64).clamp(0.0, 1.0);
      if (t <= 0 || t >= 1) continue;
      final p =
          Offset.lerp(origin, target, Curves.easeInOutCubic.transform(t))! +
          Offset(0, -math.sin(t * math.pi) * (38 + i * 6));
      final radius = 5 + math.sin(t * math.pi) * 2;
      canvas.drawCircle(
        p + const Offset(0, 1.5),
        radius,
        Paint()..color = const Color(0xFFDEAD4A),
      );
      canvas.drawCircle(p, radius, Paint()..color = const Color(0xFFFFE4A7));
      canvas.drawCircle(
        p,
        radius - 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFFCF9D39),
      );
    }
    final sparkle = ((progress - .45) / .55).clamp(0.0, 1.0);
    if (sparkle > 0) {
      final paint = Paint()
        ..color = const Color(0xFFFFE4A7).withValues(alpha: 1 - sparkle)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 8; i++) {
        final angle = i * math.pi / 4;
        final p =
            target +
            Offset(math.cos(angle), math.sin(angle)) * (12 + sparkle * 25);
        canvas.drawLine(
          p - const Offset(2.5, 0),
          p + const Offset(2.5, 0),
          paint,
        );
        canvas.drawLine(
          p - const Offset(0, 2.5),
          p + const Offset(0, 2.5),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RewardFlight oldDelegate) =>
      oldDelegate.animation != animation;
}
