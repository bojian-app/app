import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'app_icons.dart';
import 'app_store.dart';
import 'design.dart';
import 'resume_pages.dart';
import 'resume_guidance_share.dart';
import 'story_composer.dart';

const _blue = brandBlue;
const _navy = Color(0xFF203D6B);

class PointsPage extends StatefulWidget {
  const PointsPage({super.key, required this.store});
  final AppStore store;

  static Color headerColor(BuildContext context) =>
      context.isDark ? const Color(0xFF192536) : const Color(0xFFEAF1FF);

  @override
  State<PointsPage> createState() => _PointsPageState();
}

class _PointsPageState extends State<PointsPage> {
  int tab = 0;
  bool claiming = false;
  bool choosingResume = false;
  AppStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && store.isAuthenticated) store.load('profile');
    });
  }

  Future<void> claim() async {
    if (claiming || store.rewardClaimed || store.pending.contains('reward')) {
      return;
    }
    final epoch = store.epoch;
    setState(() => claiming = true);
    try {
      final amount = await store.claimReward();
      if (mounted && epoch == store.epoch && amount != null) {
        toast(context, '+$amount 积分已到账');
      }
    } catch (error) {
      if (mounted && epoch == store.epoch) toast(context, '$error');
    } finally {
      if (mounted) setState(() => claiming = false);
    }
  }

  void rules() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('积分规则'),
      content: const Text(
        '每日任务：邀请新人、打卡。打卡每日可领取一次积分，数量以当日显示为准。\n\n长期任务：创建一份简历、发布一篇文章、请求别人优化简历、观看广告，每项仅限完成一次。\n\n积分可用于模版市场中的付费模版，兑换前会展示所需积分。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('知道了'),
        ),
      ],
    ),
  );

  void market() => openPage(context, TemplateMarket(store: store));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final dark = context.isDark;
      final background = PointsPage.headerColor(context);
      return Scaffold(
        backgroundColor: background,
        body: RefreshIndicator(
          color: _blue,
          onRefresh: () => store.load('profile'),
          child: SingleChildScrollView(
            key: const PageStorageKey('points-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 4, 14, 4),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '积分福利中心',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: rules,
                        style: TextButton.styleFrom(
                          foregroundColor: dark ? Colors.white70 : _navy,
                        ),
                        child: const Text('规则', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                _overview(),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: dark
                        ? context.colors.canvas
                        : const Color(0xFFF8F8F8),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(22),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          for (final (index, label) in [(0, '赚积分'), (1, '兑好礼')])
                            Expanded(
                              child: Semantics(
                                selected: tab == index,
                                child: TextButton(
                                  key: ValueKey('points-tab-$index'),
                                  onPressed: () => setState(() => tab = index),
                                  style: TextButton.styleFrom(
                                    foregroundColor: tab == index
                                        ? _blue
                                        : context.colors.muted,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        label,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: tab == index
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 7),
                                      Container(
                                        width: 24,
                                        height: 3,
                                        decoration: BoxDecoration(
                                          color: tab == index
                                              ? _blue
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      DataStatus(
                        store: store,
                        section: 'profile',
                        empty: false,
                      ),
                      if (tab == 0) ...[
                        if (store.isAuthenticated) _checkIn(),
                        const SizedBox(height: 12),
                        _tasks(),
                      ] else ...[
                        _redeem(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _overview() => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: context.isDark
            ? const [Color(0xFF284F97), Color(0xFF233D70)]
            : const [Color(0xFF487EF5), Color(0xFF285BCB)],
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '我的积分',
                style: TextStyle(fontSize: 12, color: Color(0xFFDCE8FF)),
              ),
              const SizedBox(height: 8),
              Semantics(
                label: '可用积分 ${store.points ?? '暂不可用'}',
                excludeSemantics: true,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    store.isAuthenticated ? '${store.points ?? '—'}' : '—',
                    style: const TextStyle(
                      fontSize: 38,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Image.asset(
          'assets/points/rewards-transparent.png',
          width: 124,
          height: 96,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
      ],
    ),
  );

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );

  Widget _checkIn() {
    final claimed = store.rewardClaimed;
    final disabled =
        claimed ||
        claiming ||
        store.rewardPoints == null ||
        store.pending.contains('reward');
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          claimed ? '今天已签到' : '今天未签到',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        Text(
          '每日奖励 +${store.rewardPoints ?? '—'} 积分',
          style: TextStyle(fontSize: 11, color: context.colors.muted),
        ),
      ],
    );
    final button = _primaryButton(
      key: const ValueKey('profile-claim-reward'),
      label: claimed
          ? '已领取'
          : claiming
          ? '领取中…'
          : '签到领取',
      onPressed: disabled ? null : claim,
    );
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) =>
                MediaQuery.textScalerOf(context).scale(14) > 22
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [title, const SizedBox(height: 10), button],
                  )
                : Row(
                    children: [
                      Expanded(child: title),
                      const SizedBox(width: 10),
                      button,
                    ],
                  ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final large = MediaQuery.textScalerOf(context).scale(12) > 18;
              final width = large ? 62.0 : (constraints.maxWidth - 30) / 7;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < 7; i++) ...[
                      if (i > 0) const SizedBox(width: 5),
                      _day(i, width, claimed),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            '每日来领取，积累小确幸',
            style: TextStyle(fontSize: 10, color: context.colors.muted),
          ),
          _taskDivider(),
          _task(
            '邀请新人',
            '邀请新用户加入博简',
            '待开放',
            'assets/points/tasks/invite-newcomer.svg',
            null,
          ),
        ],
      ),
    );
  }

  Widget _day(int index, double width, bool claimed) {
    final today = DateTime.now().weekday - 1 == index;
    return SizedBox(
      width: width,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: today
                  ? context.colors.accentSoft
                  : context.colors.inset.withValues(alpha: .55),
              border: Border.all(
                color: today
                    ? context.colors.accent.withValues(alpha: .25)
                    : Colors.transparent,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SizedBox(
              height: 32,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  SizedBox.square(
                    dimension: 28,
                    child: CustomPaint(
                      painter: _CheckInStar(
                        color: context.colors.accent,
                        claimed: today && claimed,
                      ),
                    ),
                  ),
                  if (today && claimed && store.rewardPoints != null)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Semantics(
                        label: '今日已领取 ${store.rewardPoints} 积分',
                        excludeSemantics: true,
                        child: Container(
                          key: const ValueKey('check-in-received-amount'),
                          constraints: BoxConstraints(maxWidth: width),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 3,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.accent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: context.colors.surface),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '+${store.rewardPoints}',
                              style: TextStyle(
                                fontSize: 8,
                                height: 1.1,
                                fontWeight: FontWeight.w700,
                                color: context.isDark
                                    ? const Color(0xFF172D50)
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            today ? '今天' : ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][index],
            style: TextStyle(
              fontSize: 9,
              color: today ? _blue : context.colors.muted,
            ),
          ),
        ],
      ),
    );
  }

  void _openTask(Widget Function() page) {
    if (!store.isAuthenticated) {
      store.endSession();
      return;
    }
    openPage(context, page());
  }

  Future<void> _requestOptimization() async {
    if (!store.isAuthenticated) {
      store.endSession();
      return;
    }
    if (choosingResume) return;
    choosingResume = true;
    try {
      final epoch = store.epoch;
      await store.load('resumes');
      if (!mounted || epoch != store.epoch) return;
      if (store.errors['resumes'] case final String error) {
        toast(context, error);
        return;
      }
      if (store.resumes.isEmpty) {
        toast(context, '请先创建一份简历');
        return;
      }
      final resume = await showModalBottomSheet<ResumeDraft>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '选择需要优化的简历',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              for (final resume in store.resumes)
                ListTile(
                  title: Text(resume.title),
                  trailing: const AppIcon(AppIcons.forward, size: 18),
                  onTap: () => Navigator.pop(context, resume),
                ),
            ],
          ),
        ),
      );
      if (!mounted || epoch != store.epoch || resume == null) return;
      await openPage(
        context,
        ResumeGuidanceShare(store: store, resume: resume),
      );
    } finally {
      choosingResume = false;
    }
  }

  Widget _taskDivider() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Divider(height: 1, color: Theme.of(context).dividerColor),
  );

  Widget _tasks() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _task(
          '创建一份简历',
          '整理经历，开启求职第一步',
          '去创建',
          'assets/points/tasks/create-resume.svg',
          () => _openTask(
            () => ResumeEditor(store: store, draft: store.createResume()),
          ),
        ),
        _taskDivider(),
        _task(
          '发布一篇文章',
          '分享你的经验与见解',
          '去发布',
          'assets/points/tasks/publish-article.svg',
          () => _openTask(() => StoryComposer(store: store)),
        ),
        _taskDivider(),
        _task(
          '请求别人优化简历',
          '选择简历，向他人请教',
          '去请求',
          'assets/points/tasks/request-review.svg',
          _requestOptimization,
        ),
        _taskDivider(),
        _task(
          '观看广告',
          '观看视频广告，获取积分奖励',
          '待开放',
          'assets/points/tasks/watch-ad.svg',
          null,
        ),
      ],
    ),
  );

  Widget _task(
    String title,
    String subtitle,
    String action,
    String image,
    VoidCallback? onTap,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      final content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SvgPicture.asset(
              image,
              width: 44,
              height: 44,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10, color: context.colors.muted),
                ),
              ],
            ),
          ),
        ],
      );
      final button = TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: brandBlue,
          backgroundColor: context.isDark
              ? const Color(0xFF22324D)
              : const Color(0xFFEAF1FF),
          minimumSize: const Size(64, 36),
        ),
        child: Text(action, style: const TextStyle(fontSize: 11)),
      );
      return MediaQuery.textScalerOf(context).scale(12) > 18
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [content, button],
            )
          : Row(
              children: [
                Expanded(child: content),
                const SizedBox(width: 8),
                button,
              ],
            );
    },
  );

  Widget _redeem() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            'assets/points/resume.png',
            width: double.infinity,
            height: 180,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          '用积分，解锁一份出彩',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          '精选简历模版，让好经历被看见。\n具体所需积分以模版详情为准。',
          style: TextStyle(
            fontSize: 12,
            height: 1.7,
            color: context.colors.muted,
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: _primaryButton(label: '逛逛模版市场', onPressed: market),
        ),
      ],
    ),
  );

  Widget _primaryButton({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
  }) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: onPressed == null
            ? [const Color(0xFFA7B9D8), const Color(0xFFA7B9D8)]
            : [brandBlue, const Color(0xFF53A0FF)],
      ),
      borderRadius: BorderRadius.circular(12),
    ),
    child: TextButton(
      key: key,
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

/// A rounded star character; only a confirmed claim changes its expression.
class _CheckInStar extends CustomPainter {
  const _CheckInStar({required this.color, required this.claimed});
  final Color color;
  final bool claimed;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 28, size.height / 28);
    final star = Path()
      ..moveTo(11.8, 3.2)
      ..quadraticBezierTo(14, -.1, 16.2, 3.2)
      ..lineTo(18.5, 7.7)
      ..quadraticBezierTo(19, 8.5, 20, 8.6)
      ..lineTo(24.5, 9.3)
      ..quadraticBezierTo(28, 9.9, 25.5, 12.8)
      ..lineTo(22.3, 16.1)
      ..quadraticBezierTo(21.7, 16.8, 21.9, 17.9)
      ..lineTo(22.6, 22.1)
      ..quadraticBezierTo(23.1, 26, 19.6, 24.5)
      ..lineTo(15, 22.3)
      ..quadraticBezierTo(14, 21.8, 13, 22.3)
      ..lineTo(8.4, 24.5)
      ..quadraticBezierTo(4.9, 26, 5.4, 22.1)
      ..lineTo(6.1, 17.9)
      ..quadraticBezierTo(6.3, 16.8, 5.7, 16.1)
      ..lineTo(2.5, 12.8)
      ..quadraticBezierTo(0, 9.9, 3.5, 9.3)
      ..lineTo(8, 8.6)
      ..quadraticBezierTo(9, 8.5, 9.5, 7.7)
      ..close();
    canvas.drawPath(
      star,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(Colors.white, color, claimed ? .35 : .18)!,
            Color.lerp(Colors.white, color, claimed ? .85 : .55)!,
          ],
        ).createShader(const Rect.fromLTWH(0, 0, 28, 26)),
    );
    canvas.drawPath(
      star,
      Paint()
        ..color = color.withValues(alpha: .35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7,
    );
    canvas.drawPath(
      Path()
        ..moveTo(11.8, 7.2)
        ..quadraticBezierTo(13.8, 2.5, 15, 5.5),
      Paint()
        ..color = Colors.white.withValues(alpha: .8)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.5,
    );
    final face = Paint()
      ..color = const Color(0xFF245499)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.3;
    if (claimed) {
      face.style = PaintingStyle.stroke;
      for (final x in [10.0, 17.0]) {
        canvas.drawPath(
          Path()
            ..moveTo(x - 1, 14)
            ..quadraticBezierTo(x, 11.9, x + 1, 14),
          face,
        );
      }
    } else {
      for (final x in [10.0, 18.0]) {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(x, 13.5), width: 1.6, height: 2.3),
          face,
        );
      }
    }
    canvas.drawPath(
      Path()
        ..moveTo(12.2, 16)
        ..quadraticBezierTo(14, claimed ? 19 : 18, 15.8, 16),
      face..style = PaintingStyle.stroke,
    );
    for (final x in [8.0, 20.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 16), width: 3, height: 1.5),
        Paint()..color = Colors.white.withValues(alpha: .6),
      );
    }
  }

  @override
  bool shouldRepaint(_CheckInStar oldDelegate) =>
      color != oldDelegate.color || claimed != oldDelegate.claimed;
}
