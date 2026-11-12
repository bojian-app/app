import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';

import 'app_icons.dart';
import 'app_store.dart';
import 'design.dart';
import 'design_shapes.dart';
import 'points_coin.dart';
import 'discovery.dart' show DiscoveryPage;
import 'invitation_dialog.dart';
import 'resume_user_share.dart';
import 'rewarded_ad.dart';
import 'story_composer.dart';

const _displayFont = 'ResumeDocument';
const _goldInk = Color(0xFFE07B00);

/// Warm red-orange for amounts, against the blue brand.
const _rewardInk = Color(0xFFFF5A2C);
const _rewardGradient = [Color(0xFFFF7E57), Color(0xFFFF482C)];
const _blueGradient = [Color(0xFF5C9BFF), Color(0xFF2867EE)];
const _accent = Color(0xFF2867EE);
const _gutter = 14.0;

/// Body text colour of the design; the dark theme keeps its own ink.
Color _strong(BuildContext context) =>
    context.isDark ? context.colors.ink : const Color(0xFF333333);
const _dailyTasks = ['PUBLISH_ARTICLE', 'REQUEST_REVIEW', 'HELP_REVIEW'];

/// Height of the tinted hero; the invite card overlaps its lower edge.
const _heroHeight = 320.0;

/// Plays [controller] forward [times] times and leaves it at the end.
/// Idle motion draws the eye on arrival, then stops instead of looping.
void _playTimes(AnimationController controller, int times) {
  var left = times;
  void next(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    left--;
    if (left > 0) {
      controller.forward(from: 0);
    } else {
      controller.removeStatusListener(next);
    }
  }

  controller.addStatusListener(next);
  controller.forward(from: 0);
}

class PointsPage extends StatefulWidget {
  const PointsPage({super.key, required this.store});
  final AppStore store;

  /// Top colour of the hero gradient; the shell paints the status bar with it.
  static Color headerColor(BuildContext context) =>
      context.isDark ? const Color(0xFF1F3266) : const Color(0xFF8FB6FF);

  @override
  State<PointsPage> createState() => _PointsPageState();
}

class _PointsPageState extends State<PointsPage> with TickerProviderStateMixin {
  final tasks = <String, Map<String, dynamic>>{};
  final pageKey = GlobalKey();
  final balanceKey = GlobalKey();
  final todayKey = GlobalKey();
  final taskKeys = {for (final task in _dailyTasks) task: GlobalKey()};
  final adKey = GlobalKey();
  final bursts = <_Burst>[];
  String? claimingTask;
  bool adEnabled = false, watchingAd = false, claiming = false;
  bool choosingResume = false;

  /// Balance shown while coins are still flying, so the number rises only
  /// when they land.
  int? heldPoints;
  AppStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && store.isAuthenticated) refresh();
    });
  }

  @override
  void dispose() {
    for (final burst in bursts) {
      burst.controller.dispose();
    }
    super.dispose();
  }

  Future<void> refresh() async {
    final epoch = store.epoch;
    await Future.wait([
      store.load('profile'),
      () async {
        try {
          final result = await store.request('GetWalletTasks');
          if (!mounted || epoch != store.epoch) return;
          setState(() {
            tasks.clear();
            for (final row
                in (result.data['items'] as List? ?? []).whereType<Map>()) {
              tasks['${row['task']}'] = Map<String, dynamic>.from(row);
            }
          });
        } catch (_) {
          if (mounted && epoch == store.epoch) setState(tasks.clear);
        }
      }(),
      () async {
        try {
          final enabled = await RewardedAd.available(store);
          if (mounted && epoch == store.epoch) {
            setState(() => adEnabled = enabled);
          }
        } catch (_) {
          if (mounted) setState(() => adEnabled = false);
        }
      }(),
    ]);
  }

  bool get animate => !MediaQuery.disableAnimationsOf(context);

  /// Confetti at [source], coins arcing into the balance, then the number
  /// rolls up and the otter jumps.
  void celebrate(GlobalKey source, int amount, int? before) {
    HapticFeedback.mediumImpact();
    final page = pageKey.currentContext?.findRenderObject();
    final from = source.currentContext?.findRenderObject();
    final to = balanceKey.currentContext?.findRenderObject();
    if (!animate ||
        page is! RenderBox ||
        from is! RenderBox ||
        to is! RenderBox) {
      toast(context, '+$amount 积分已到账');
      return;
    }
    final start = page.globalToLocal(
      from.localToGlobal(from.size.center(Offset.zero)),
    );
    final end = page.globalToLocal(
      to.localToGlobal(Offset(18, to.size.height / 2)),
    );
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    final burst = _Burst(controller, start, end, amount);
    setState(() {
      heldPoints = before;
      bursts.add(burst);
    });
    var landed = false;
    controller.addListener(() {
      if (!landed && controller.value >= _Burst.landAt) {
        landed = true;
        if (mounted) setState(() => heldPoints = null);
      }
    });
    controller.forward().whenComplete(() {
      if (!mounted) return;
      setState(() => bursts.remove(burst));
      controller.dispose();
    });
  }

  Future<void> checkIn() async {
    if (claiming || store.rewardClaimed || store.pending.contains('reward')) {
      return;
    }
    final epoch = store.epoch;
    final before = store.points;
    setState(() => claiming = true);
    try {
      final amount = await store.claimReward();
      if (mounted && epoch == store.epoch && amount != null && amount > 0) {
        celebrate(todayKey, amount, before);
      }
    } catch (error) {
      if (mounted && epoch == store.epoch) toast(context, '$error');
    } finally {
      if (mounted) setState(() => claiming = false);
    }
  }

  Future<void> claimTask(String task) async {
    if (claimingTask != null) return;
    final epoch = store.epoch;
    final before = store.points;
    setState(() => claimingTask = task);
    try {
      final result = await store.request(
        'PostWalletTasksTaskClaims',
        path: {'task': task},
        body: {},
      );
      if (!mounted || epoch != store.epoch) return;
      if (result.data['deduplicated'] == true) {
        toast(context, '今日奖励已领取');
      } else {
        celebrate(taskKeys[task]!, integer(result.data['points']), before);
      }
      await refresh();
    } catch (e) {
      if (mounted && epoch == store.epoch) toast(context, '$e');
    } finally {
      if (mounted) setState(() => claimingTask = null);
    }
  }

  Future<void> watchAd() async {
    if (watchingAd) return;
    final epoch = store.epoch;
    final before = store.points;
    setState(() => watchingAd = true);
    try {
      final amount = await RewardedAd.watch(store);
      if (!mounted || epoch != store.epoch) return;
      if (amount > 0) {
        celebrate(adKey, amount, before);
      } else {
        toast(context, '未获得新的广告奖励');
      }
      await refresh();
    } catch (e) {
      if (mounted && epoch == store.epoch) toast(context, '$e');
    } finally {
      if (mounted) setState(() => watchingAd = false);
    }
  }

  Future<void> _openTask(Widget Function() page) async {
    if (!store.isAuthenticated) {
      store.endSession();
      return;
    }
    await openPage(context, page());
    if (mounted) await refresh();
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
          child: ListenableBuilder(
            listenable: store,
            builder: (context, _) => AutoPaginate.section(
              store: store,
              section: 'resumes',
              child: ListView(
                shrinkWrap: true,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      '选择需要优化的简历',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (final resume in store.resumes)
                    ListTile(
                      title: Text(resume.title),
                      trailing: const AppIcon(AppIcons.forward, size: 18),
                      onTap: () => Navigator.pop(context, resume),
                    ),
                  PageLoadingFooter(
                    visible: store.loadingMore.contains('resumes'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (!mounted || epoch != store.epoch || resume == null) return;
      await openPage(context, ResumeUserShare(store: store, resume: resume));
      if (mounted) await refresh();
    } finally {
      choosingResume = false;
    }
  }

  Future<void> _helpOthers() async {
    await store.load('feed');
    if (!mounted) return;
    await _openTask(
      () => Scaffold(
        appBar: AppBar(title: const Text('帮别人改简历')),
        body: DiscoveryPage(store: store),
      ),
    );
  }

  void rules() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.colors.surface,
    builder: (context) => const _RulesSheet(),
  );

  void ledger() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.colors.surface,
    builder: (context) => _LedgerSheet(store: store),
  );

  bool get showCheckIn =>
      store.isAuthenticated &&
      !store.rewardEnded &&
      store.rewardDays.length == 7;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final topInset = MediaQuery.paddingOf(context).top;
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: appSystemUiStyle(context).copyWith(
          // The header is always midnight blue.
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemStatusBarContrastEnforced: false,
        ),
        child: Scaffold(
          backgroundColor: context.colors.canvas,
          body: Stack(
            key: pageKey,
            fit: StackFit.expand,
            children: [
              RefreshIndicator(
                color: _accent,
                onRefresh: refresh,
                child: SingleChildScrollView(
                  key: const PageStorageKey('points-scroll'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: _heroHeight + topInset,
                        child: const _HeroBackground(),
                      ),
                      Positioned(
                        top: topInset + 82,
                        right: 42,
                        width: 96,
                        child: Image.asset(
                          'assets/points/coin-stack.webp',
                          fit: BoxFit.contain,
                          excludeFromSemantics: true,
                        ),
                      ),
                      Column(
                        children: [
                          SizedBox(height: topInset),
                          _hero(),
                          DataStatus(
                            store: store,
                            section: 'profile',
                            empty: false,
                          ),
                          if (store.isAuthenticated) ...[
                            _invite(),
                            if (showCheckIn) _checkIn(),
                            _tasks(),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              for (final burst in bursts)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: _BurstPainter(burst)),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );

  Widget _hero() {
    final points = heldPoints ?? store.points;
    return SizedBox(
      height: 121,
      child: Stack(
        children: [
          Positioned(
            left: 24,
            top: 26,
            right: 96,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _Coin(size: 16),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '我的积分',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 20 / 14,
                          color: Color(0xE6FFFFFF),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Semantics(
                  label: '可用积分 ${points ?? '暂不可用'}',
                  excludeSemantics: true,
                  child: FittedBox(
                    key: balanceKey,
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    // Already display-sized; system text scaling would
                    // push digits out of their rolling windows.
                    child: MediaQuery.withNoTextScaling(
                      child: store.isAuthenticated && points != null
                          ? _Odometer(value: points)
                          : Text('—', style: _Odometer.style(context)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            top: 30,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _EdgeTab(label: '积分规则', onTap: rules),
                if (store.isAuthenticated) ...[
                  const SizedBox(height: 9),
                  _EdgeTab(
                    key: const ValueKey('points-ledger'),
                    label: '积分明细',
                    onTap: ledger,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(_gutter, 0, _gutter, 12),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(16),
      boxShadow: context.isDark
          ? null
          : [
              BoxShadow(
                color: const Color(0xFF0B1A45).withValues(alpha: .06),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
    ),
    child: child,
  );

  /// Card heading; a soft brand-blue marker runs under the title's foot.
  Widget _sectionHead(Widget title, [Widget? trailing]) => Container(
    height: 52,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          context.isDark ? const Color(0xFF1F2A44) : const Color(0xFFEFF5FF),
          context.colors.surface,
        ],
      ),
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: Row(
            children: [
              Flexible(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: -1,
                      right: -3,
                      bottom: 1,
                      height: 7,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(
                            colors: [
                              _accent.withValues(alpha: .45),
                              _accent.withValues(alpha: .12),
                            ],
                          ),
                        ),
                      ),
                    ),
                    DefaultTextStyle.merge(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        height: 24 / 17,
                        fontWeight: FontWeight.w700,
                        color: _strong(context),
                      ),
                      child: title,
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const Spacer(),
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
        ),
        Positioned(left: 0, right: 0, bottom: 0, child: _rule()),
      ],
    ),
  );

  Widget _rule() => Container(
    height: 1,
    color: context.isDark ? context.colors.border : const Color(0xFFF1F3F7),
  );

  /// Consecutive check-ins ending today, or yesterday while today is open.
  int _streak(List<Map<String, dynamic>> days, int today) {
    var day = today.clamp(-1, days.length - 1);
    if (day >= 0 && days[day]['status'] != 'CLAIMED') day--;
    var count = 0;
    while (day >= 0 && days[day]['status'] == 'CLAIMED') {
      count++;
      day--;
    }
    return count;
  }

  Widget _checkIn() {
    final days = store.rewardDays;
    final today = store.rewardDay - 1;
    final streak = _streak(days, today);
    final tomorrow = today + 1 < days.length && today >= 0
        ? integer(days[today + 1]['points'])
        : null;
    final disabled =
        store.rewardClaimed ||
        claiming ||
        store.rewardPoints == null ||
        store.pending.contains('reward');
    final now = DateTime.now();
    String date(int i) {
      final day = DateTime(now.year, now.month, now.day + i - today);
      return '${day.month.toString().padLeft(2, '0')}.'
          '${day.day.toString().padLeft(2, '0')}';
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHead(
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: '已连续签到'),
                  TextSpan(
                    text: '$streak',
                    style: const TextStyle(color: _rewardInk),
                  ),
                  const TextSpan(text: '天'),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < days.length; i++) ...[
                  if (i > 0) const SizedBox(width: 7.5),
                  Expanded(
                    child: _DayTile(
                      key: i == today ? todayKey : null,
                      actionKey: i == today
                          ? const ValueKey('profile-claim-reward')
                          : null,
                      points: integer(days[i]['points']),
                      status: '${days[i]['status']}',
                      label: today >= 0 ? date(i) : '第${i + 1}天',
                      bonus: i == days.length - 1,
                      onTap: i == today && !disabled ? checkIn : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: _CheckInButton(
              label: store.rewardClaimed
                  ? (tomorrow == null ? '今日已签到' : '今日已签到，明天可领 +$tomorrow')
                  : '立即签到 +${store.rewardPoints ?? integer(days[today.clamp(0, days.length - 1)]['points'])}',
              onPressed: disabled ? null : checkIn,
            ),
          ),
        ],
      ),
    );
  }

  Widget _invite() => Container(
    height: 112,
    margin: const EdgeInsets.fromLTRB(_gutter, 0, _gutter, 12),
    child: CustomPaint(
      painter: _InviteCardPainter(dark: context.isDark),
      child: Stack(
        children: [
          Positioned(
            left: 18,
            top: 14,
            right: 120,
            child: Text(
              '邀请好友',
              maxLines: 1,
              style: TextStyle(
                fontSize: 16,
                height: 22 / 16,
                fontWeight: FontWeight.w600,
                color: _strong(context),
              ),
            ),
          ),
          Positioned(
            left: 18,
            top: 37,
            right: 120,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: const LinearGradient(
                  begin: Alignment(-1, -.44),
                  end: Alignment(1, .49),
                  colors: _rewardGradient,
                ).createShader,
                child: const Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '500',
                        style: TextStyle(fontSize: 36, letterSpacing: -.5),
                      ),
                      TextSpan(text: ' 积分/人'),
                    ],
                  ),
                  style: TextStyle(
                    fontFamily: _displayFont,
                    fontSize: 17,
                    height: 1.05,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 18,
            top: 78,
            right: 120,
            child: Text(
              '好友注册并绑定手机号后到账',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 16.5 / 12,
                color: context.isDark
                    ? context.colors.muted
                    : const Color(0xFF8A8F99),
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: 46,
            child: _BlueButton(
              key: const ValueKey('points-invite'),
              label: '去邀请',
              onPressed: () async {
                if (!store.isAuthenticated) {
                  store.endSession();
                  return;
                }
                await showInvitationDialog(context, store);
                if (mounted) await refresh();
              },
            ),
          ),
        ],
      ),
    ),
  );

  Widget _tasks() {
    final done = _dailyTasks
        .where((task) => tasks[task]?['claimed'] == true)
        .length;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHead(
            const Text('每日任务'),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: 90,
                    height: 8,
                    child: LinearProgressIndicator(
                      value: done / 3,
                      backgroundColor: context.isDark
                          ? context.colors.inset
                          : const Color(0xFFEEF1F7),
                      valueColor: const AlwaysStoppedAnimation(_accent),
                    ),
                  ),
                ),
                const SizedBox(width: 22),
                Text(
                  '$done/3',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.isDark
                        ? context.colors.muted
                        : const Color(0xFF999999),
                  ),
                ),
              ],
            ),
          ),
          _dailyTask(
            'PUBLISH_ARTICLE',
            '发一篇求职经验',
            'assets/points/tasks/publish-material.webp',
            () => _openTask(() => StoryComposer(store: store)),
          ),
          _divider(),
          _dailyTask(
            'REQUEST_REVIEW',
            '请大家帮你改简历',
            'assets/points/tasks/request-material.webp',
            _requestOptimization,
          ),
          _divider(),
          _dailyTask(
            'HELP_REVIEW',
            '帮别人改简历',
            'assets/points/tasks/review-material.webp',
            _helpOthers,
          ),
          if (adEnabled) ...[
            _divider(),
            _TaskRow(
              actionKey: adKey,
              title: '看一段视频',
              progress: '每次都能领',
              reward: 20,
              iconAsset: 'assets/points/tasks/icons/video.svg',
              state: watchingAd ? _TaskState.busy : _TaskState.todo,
              action: watchingAd ? '播放中…' : '去观看',
              onPressed: watchingAd ? null : watchAd,
            ),
          ],
        ],
      ),
    );
  }

  Widget _divider() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: _rule(),
  );

  Widget _dailyTask(
    String task,
    String title,
    String iconAsset,
    VoidCallback go,
  ) {
    final row = tasks[task];
    final claimed = row?['claimed'] == true;
    final claimable = row?['claimable'] == true;
    final busy = claimingTask == task;
    final state = claimed
        ? _TaskState.done
        : busy
        ? _TaskState.busy
        : claimable
        ? _TaskState.claim
        : _TaskState.todo;
    return _TaskRow(
      actionKey: taskKeys[task],
      title: title,
      reward: 100,
      iconAsset: iconAsset,
      state: state,
      action: switch (state) {
        _TaskState.done => '已领取',
        _TaskState.busy => '领取中…',
        _TaskState.claim => '点击领取',
        _TaskState.todo => '去完成',
      },
      onPressed: switch (state) {
        _TaskState.done || _TaskState.busy => null,
        _TaskState.claim => claimingTask == null ? () => claimTask(task) : null,
        _TaskState.todo => go,
      },
    );
  }
}

/// Invite card with a notched top right where the coin stack rests, the
/// way card-style layouts let a 3D object break out of the frame.
class _InviteCardPainter extends CustomPainter {
  const _InviteCardPainter({required this.dark});
  final bool dark;

  static Path outline(Size size) {
    final w = size.width, h = size.height;
    return roundedPolygon([
      (Offset.zero, 16),
      (Offset(w - 172.8, 0), 24),
      (Offset(w - 139.2, 20), 24),
      (Offset(w, 20), 16),
      (Offset(w, h), 16),
      (Offset(0, h), 16),
    ]);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final card = outline(size);
    final bounds = card.getBounds();
    canvas.drawPath(
      card.shift(const Offset(0, 6)),
      Paint()
        ..color = const Color(0xFF1C4FD8).withValues(alpha: dark ? .3 : .16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawPath(
      card,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF24304D), Color(0xFF1B2232)]
              : const [Color(0xFFEAF2FF), Colors.white, Colors.white],
        ).createShader(bounds),
    );
    // A warm wash behind the amount ties it to the reward colour.
    canvas.save();
    canvas.clipPath(card);
    canvas.drawCircle(
      Offset(size.width * .22, size.height * .62),
      size.width * .3,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                const Color(0xFFFFE3D6).withValues(alpha: dark ? .08 : .6),
                const Color(0xFFFFE3D6).withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(
                center: Offset(size.width * .22, size.height * .62),
                radius: size.width * .3,
              ),
            ),
    );
    canvas.restore();
    canvas.drawPath(
      card,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: dark ? .08 : 1),
    );
  }

  @override
  bool shouldRepaint(_InviteCardPainter oldDelegate) =>
      oldDelegate.dark != dark;
}

/// Saturated brand-blue header that melts into the page, lit from the top
/// right where the coin stack sits.
class _HeroBackground extends StatelessWidget {
  const _HeroBackground();

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0, .42, .78, 1],
            colors: context.isDark
                ? [
                    const Color(0xFF1C3F9E),
                    const Color(0xFF1A3474),
                    const Color(0xFF16213D),
                    context.colors.canvas,
                  ]
                : [
                    const Color(0xFF2A66F5),
                    const Color(0xFF4C8BFF),
                    const Color(0xFFB4CFFF),
                    context.colors.canvas,
                  ],
          ),
        ),
      ),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(.7, -.55),
            radius: .7,
            colors: [
              Colors.white.withValues(alpha: context.isDark ? .1 : .32),
              Colors.white.withValues(alpha: 0),
            ],
          ),
        ),
      ),
      const CustomPaint(painter: _RingsPainter()),
    ],
  );
}

class _RingsPainter extends CustomPainter {
  const _RingsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .78, size.height * .22);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final (radius, alpha) in const [
      (62.0, .16),
      (104.0, .11),
      (150.0, .07),
    ]) {
      canvas.drawCircle(
        center,
        radius,
        paint..color = Colors.white.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter oldDelegate) => false;
}

/// Frosted half pill docked against the right edge of the header.
class _EdgeTab extends StatelessWidget {
  const _EdgeTab({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      backgroundColor: Colors.white.withValues(alpha: .2),
      foregroundColor: Colors.white,
      minimumSize: const Size(72, 26),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(13)),
        side: BorderSide(color: Colors.white.withValues(alpha: .3), width: .5),
      ),
      textStyle: const TextStyle(fontSize: 12),
    ),
    child: Text(label),
  );
}

/// Tinted brand-blue pill for task actions; [filled] makes it the solid
/// gradient for an action that pays out now.
class _SoftButton extends StatelessWidget {
  const _SoftButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.filled = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final solid = filled && enabled;
    final blue = context.isDark ? context.colors.accent : _accent;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        gradient: solid
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _blueGradient,
              )
            : null,
        color: solid
            ? null
            : enabled
            ? blue.withValues(alpha: context.isDark ? .16 : .1)
            : context.colors.inset,
        boxShadow: solid
            ? [
                BoxShadow(
                  color: _accent.withValues(alpha: .3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: solid ? Colors.white : blue,
          disabledForegroundColor: context.colors.muted,
          minimumSize: const Size(76, 31),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        child: Text(label, maxLines: 1),
      ),
    );
  }
}

/// Brand-blue gradient pill with a soft coloured shadow.
class _BlueButton extends StatelessWidget {
  const _BlueButton({super.key, required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(99),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: _blueGradient,
      ),
      boxShadow: [
        BoxShadow(
          color: _accent.withValues(alpha: .3),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        minimumSize: const Size(86, 34),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    ),
  );
}

/// Full-width check-in call to action under the week; greys out once
/// today is claimed and says what tomorrow brings.
class _CheckInButton extends StatelessWidget {
  const _CheckInButton({required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        gradient: enabled
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _blueGradient,
              )
            : null,
        color: enabled
            ? null
            : (context.isDark ? context.colors.inset : const Color(0xFFEFF4FF)),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: _accent.withValues(alpha: .3),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: TextButton(
        key: const ValueKey('points-check-in'),
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: context.isDark
              ? context.colors.muted
              : const Color(0xFF6E8BC8),
          minimumSize: const Size.fromHeight(44),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(99),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF5C9BFF), Color(0xFF2867EE)],
      ),
    ),
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(46),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    ),
  );
}

/// The rendered 3D coin from the points artwork.
class _Coin extends StatelessWidget {
  const _Coin({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/points/coin-3d.webp',
    width: size,
    height: size,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
  );
}

/// Balance digits that roll to their new value like an odometer.
class _Odometer extends StatelessWidget {
  const _Odometer({required this.value});
  final int value;
  static const _height = 42.0;

  static TextStyle style(BuildContext context) => TextStyle(
    fontFamily: _displayFont,
    fontSize: 36,
    height: _height / 36,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  @override
  Widget build(BuildContext context) {
    final text = value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    final textStyle = style(context);
    final chars = text.split('');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < chars.length; i++)
          if (chars[i] == ',')
            Text(',', style: textStyle)
          else
            // Keyed from the right so a digit keeps its column as it rolls.
            _DigitColumn(
              key: ValueKey(chars.length - i),
              digit: int.parse(chars[i]),
              style: textStyle,
              height: _height,
              delay: (chars.length - 1 - i) * 70,
            ),
      ],
    );
  }
}

class _DigitColumn extends StatelessWidget {
  const _DigitColumn({
    super.key,
    required this.digit,
    required this.style,
    required this.height,
    required this.delay,
  });
  final int digit, delay;
  final TextStyle style;
  final double height;

  @override
  Widget build(BuildContext context) {
    // Tabular figures share one width; measure it so the column can be a
    // fixed window over the 0-9 strip.
    final probe = TextPainter(
      text: TextSpan(text: '0', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final width = probe.width;
    probe.dispose();
    return ClipRect(
      child: SizedBox(
        width: width,
        height: height,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: digit.toDouble()),
          duration: Duration(milliseconds: 800 + delay),
          curve: Interval(delay / (800 + delay), 1, curve: Curves.easeOutCubic),
          builder: (context, value, _) => OverflowBox(
            alignment: Alignment.topCenter,
            minWidth: width,
            maxWidth: width,
            minHeight: height * 10,
            maxHeight: height * 10,
            child: Transform.translate(
              offset: Offset(0, -value * height),
              child: Column(
                children: [
                  for (var n = 0; n < 10; n++)
                    SizedBox(
                      height: height,
                      child: Center(child: Text('$n', style: style)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One day of the newcomer gift. Today glows and can be tapped to check in;
/// the tile flips to its claimed face when the claim is confirmed.
class _DayTile extends StatefulWidget {
  const _DayTile({
    super.key,
    required this.points,
    required this.status,
    required this.label,
    this.actionKey,
    this.bonus = false,
    this.onTap,
  });
  final int points;
  final String status, label;
  final Key? actionKey;

  /// The week's last, largest reward gets a warm highlight.
  final bool bonus;
  final VoidCallback? onTap;

  @override
  State<_DayTile> createState() => _DayTileState();
}

class _DayTileState extends State<_DayTile> with TickerProviderStateMixin {
  late final flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
    value: widget.status == 'CLAIMED' ? 1 : 0,
  );
  late final glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncGlow();
  }

  @override
  void didUpdateWidget(_DayTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncGlow();
    if (widget.status == oldWidget.status) return;
    if (widget.status == 'CLAIMED') {
      if (MediaQuery.disableAnimationsOf(context)) {
        flip.value = 1;
      } else {
        flip.animateTo(1, curve: Curves.easeOutBack);
      }
    } else {
      flip.value = 0;
    }
  }

  bool played = false;

  void syncGlow() {
    final on =
        widget.status == 'AVAILABLE' &&
        !MediaQuery.disableAnimationsOf(context);
    if (on && !played) {
      played = true;
      _playTimes(glow, 5);
    } else if (!on && glow.isAnimating) {
      glow
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    flip.dispose();
    glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final today = widget.status == 'AVAILABLE';
    final missed = widget.status == 'MISSED';
    final dark = context.isDark;
    const grey = Color(0xFF999999);

    Widget face({required bool claimed}) {
      final faded = claimed || missed;
      final highlight = today && !claimed;
      final warm = widget.bonus && !faded && !highlight;
      final Widget coin = claimed
          ? Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFD6D6D6),
              ),
              child: const Icon(Icons.check, size: 12, color: Colors.white),
            )
          : missed
          ? const ColorFiltered(
              colorFilter: ColorFilter.matrix([
                .33, .33, .33, 0, 0, //
                .33, .33, .33, 0, 0, //
                .33, .33, .33, 0, 0, //
                0, 0, 0, 1, 0,
              ]),
              child: _Coin(size: 18),
            )
          : const _Coin(size: 18);
      return Container(
        height: 67,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          color: highlight || warm
              ? null
              : faded
              ? (dark ? const Color(0xFF2A2F38) : const Color(0xFFF2F3F5))
              : (dark ? const Color(0xFF242B3D) : const Color(0xFFEFF4FF)),
          border: warm
              ? Border.all(color: const Color(0xFFFFB08A), width: 1)
              : null,
          boxShadow: highlight
              ? [
                  BoxShadow(
                    color: _accent.withValues(alpha: .35),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
          gradient: warm
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: dark
                      ? const [Color(0xFF4A2E22), Color(0xFF3A241C)]
                      : const [Color(0xFFFFF3EC), Color(0xFFFFE0D0)],
                )
              : highlight
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2867EE), Color(0xFF0F2A78)],
                )
              : null,
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            SizedBox(
              height: 23,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '+${widget.points}',
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: highlight
                        ? Colors.white
                        : faded
                        ? grey
                        : warm
                        ? _rewardInk
                        : (dark ? colors.ink : const Color(0xFF333333)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4.5),
            coin,
          ],
        ),
      );
    }

    final claimedNow = widget.status == 'CLAIMED';
    final label = claimedNow
        ? '已签'
        : missed
        ? '漏签'
        : widget.label;
    return Semantics(
      button: widget.onTap != null,
      label:
          '${widget.label} ${widget.points} 积分 ${claimedNow
              ? '已签'
              : missed
              ? '漏签'
              : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        key: widget.actionKey,
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            SizedBox(
              height: 67,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (today)
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: glow,
                        builder: (context, _) => flip.value > 0
                            ? const SizedBox.shrink()
                            : Transform.scale(
                                scale: 1 + glow.value * .12,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      width: 2,
                                      color: const Color(0xFF5C9BFF).withValues(
                                        alpha: .9 * (1 - glow.value),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: flip,
                      builder: (context, _) {
                        final angle = flip.value * math.pi;
                        final back = angle > math.pi / 2;
                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, .002)
                            ..rotateY(back ? angle - math.pi : angle),
                          child: face(claimed: back),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  height: 15 / 11,
                  color: claimedNow || missed
                      ? grey
                      : (dark ? colors.ink : const Color(0xFF333333)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _TaskState { todo, claim, busy, done }

class _TaskRow extends StatefulWidget {
  const _TaskRow({
    required this.actionKey,
    required this.title,
    this.progress,
    required this.reward,
    required this.iconAsset,
    required this.state,
    required this.action,
    required this.onPressed,
  });
  final Key? actionKey;
  final String title, action;
  final String? progress;
  final int reward;
  final String iconAsset;
  final _TaskState state;
  final VoidCallback? onPressed;

  @override
  State<_TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends State<_TaskRow>
    with SingleTickerProviderStateMixin {
  // A claimable reward gives a small periodic nudge.
  late final pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncPulse();
  }

  @override
  void didUpdateWidget(_TaskRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncPulse();
  }

  bool played = false;

  void syncPulse() {
    final on =
        widget.state == _TaskState.claim &&
        !MediaQuery.disableAnimationsOf(context);
    if (on && !played) {
      played = true;
      _playTimes(pulse, 4);
    } else if (!on && pulse.isAnimating) {
      pulse
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final done = widget.state == _TaskState.done;
    final claim = widget.state == _TaskState.claim;
    final button = _SoftButton(
      key: widget.actionKey,
      label: widget.action,
      filled: claim,
      onPressed: widget.onPressed,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14.5, 16, 14.5),
      child: Row(
        children: [
          Opacity(
            opacity: done ? .45 : 1,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: context.isDark
                      ? Colors.white.withValues(alpha: .06)
                      : const Color(0xFFDCE7FF),
                  width: .8,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: context.isDark
                      ? const [Color(0xFF243050), Color(0xFF1C2640)]
                      : const [Color(0xFFF5F8FF), Color(0xFFE4EDFF)],
                ),
              ),
              child: widget.iconAsset.endsWith('.svg')
                  ? SvgPicture.asset(
                      widget.iconAsset,
                      width: 22,
                      height: 22,
                      theme: SvgTheme(
                        currentColor: context.isDark
                            ? context.colors.accent
                            : _accent,
                      ),
                      excludeFromSemantics: true,
                    )
                  : Image.asset(
                      widget.iconAsset,
                      width: 34,
                      height: 34,
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    height: 21 / 15,
                    color: done
                        ? colors.muted
                        : (context.isDark
                              ? colors.ink
                              : const Color(0xFF333333)),
                  ),
                ),
                if (widget.progress != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.progress!,
                    style: TextStyle(
                      fontSize: 12,
                      height: 16 / 12,
                      color: context.isDark
                          ? colors.muted
                          : const Color(0xFF999999),
                    ),
                  ),
                ],
                const SizedBox(height: 7),
                Row(
                  children: [
                    const _Coin(size: 16),
                    const SizedBox(width: 2),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '+${widget.reward}',
                          style: const TextStyle(
                            fontSize: 16,
                            height: 22.5 / 16,
                            fontWeight: FontWeight.w600,
                            color: _rewardInk,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (claim)
            AnimatedBuilder(
              animation: pulse,
              builder: (context, child) {
                final t = pulse.value;
                final scale = t < .7
                    ? 1.0
                    : 1 + math.sin((t - .7) / .3 * math.pi * 2) * .06;
                return Transform.scale(scale: scale, child: child);
              },
              child: button,
            )
          else
            button,
        ],
      ),
    );
  }
}

/// One claim celebration: confetti at the source, coins arcing to the
/// balance and the amount floating up beside it.
class _Burst {
  _Burst(this.controller, this.from, this.to, this.amount);
  final AnimationController controller;
  final Offset from, to;
  final int amount;

  /// Fraction of the timeline at which the first coin reaches the balance.
  static const landAt = .5;
  static const coins = 7;
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.burst) : super(repaint: burst.controller);
  final _Burst burst;

  static const _confetti = [
    Color(0xFFFFC233),
    Color(0xFFFF5A4E),
    Color(0xFF4F8DFF),
    Color(0xFF7A4CFF),
    Color(0xFF13A58C),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = burst.controller.value;
    final from = burst.from, to = burst.to;

    // Confetti bursts out and drifts down while spinning.
    final c = (t / .6).clamp(0.0, 1.0);
    if (c < 1) {
      final e = Curves.easeOutCubic.transform(c);
      for (var i = 0; i < 22; i++) {
        // Fixed pseudo-random spread so every frame agrees.
        final a = (i * 137.5) % 360 * math.pi / 180;
        final d = (40 + (i * 29) % 50) * e;
        final at = from + Offset(math.cos(a) * d, math.sin(a) * d + 30 * c * c);
        canvas.save();
        canvas.translate(at.dx, at.dy);
        canvas.rotate((i.isEven ? 1 : -1) * c * math.pi * 3);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: 7, height: 4.5),
            const Radius.circular(1.5),
          ),
          Paint()..color = _confetti[i % 5].withValues(alpha: 1 - c),
        );
        canvas.restore();
      }
    }

    // Coins pop out, then arc into the balance.
    for (var i = 0; i < _Burst.coins; i++) {
      final start = i * .04;
      final p = ((t - start) / _Burst.landAt).clamp(0.0, 1.0);
      if (p <= 0 || p >= 1) continue;
      final a = -math.pi / 2 + (i - (_Burst.coins - 1) / 2) * .5;
      final pop = from + Offset(math.cos(a) * 50, math.sin(a) * 50);
      final control = Offset(
        (pop.dx + to.dx) / 2 + 30,
        math.min(pop.dy, to.dy) - 60,
      );
      Offset at;
      double scale;
      if (p < .3) {
        final e = Curves.easeOutCubic.transform(p / .3);
        at = Offset.lerp(from, pop, e)!;
        scale = .5 + .7 * e;
      } else {
        final u = Curves.easeInOutSine.transform((p - .3) / .7);
        at =
            pop * ((1 - u) * (1 - u)) +
            control * (2 * (1 - u) * u) +
            to * (u * u);
        scale = 1.2 - u * .5;
      }
      // A spinning coin narrows as it turns edge-on.
      final spin = math.cos(p * math.pi * 4).abs() * .7 + .3;
      final s = 26 * scale;
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.scale(spin, 1);
      PointsCoinPainter.paintCoin(
        canvas,
        Rect.fromCenter(center: Offset.zero, width: s, height: s),
        opacity: p > .9 ? (1 - p) * 10 : 1,
      );
      canvas.restore();
    }

    // The amount pops beside the balance as the coins land.
    final f = ((t - _Burst.landAt) / (1 - _Burst.landAt)).clamp(0.0, 1.0);
    if (f > 0 && f < 1) {
      final rise = Curves.easeOutBack.transform((f / .3).clamp(0.0, 1.0));
      final opacity = f < .7 ? 1.0 : (1 - f) / .3;
      final text = TextPainter(
        text: TextSpan(
          text: '+${burst.amount}',
          style: TextStyle(
            fontFamily: _displayFont,
            fontSize: 24 * (.6 + .4 * rise),
            fontWeight: FontWeight.w700,
            color: const Color(0xFFFFE27A).withValues(alpha: opacity),
            shadows: [
              Shadow(
                color: const Color(0xFF141E78).withValues(alpha: .4 * opacity),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, to + Offset(100, -44 - f * 18));
      text.dispose();
    }
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) => oldDelegate.burst != burst;
}

class _RulesSheet extends StatelessWidget {
  const _RulesSheet();

  static const rules = [
    (
      '新人 7 天礼',
      '注册当天起连续 7 天（北京时间）每天签到一次，依次得 50、75、100、125、150、200、300 积分；漏签不补。',
      '共 1000',
    ),
    ('邀请好友', '好友注册时填写你的邀请码，并绑定手机号后到账。', '500/位'),
    ('每日任务', '发经验、请人改简历、帮人改简历，每项每天能领一次，需完成并通过审核。', '各 100'),
    ('看视频', '完整看完并验证成功后到账，可重复。', '20/次'),
    ('积分怎么用', '兑换模版市场里的付费简历模版，兑换前会显示所需积分。积分不能提现或转让。', ''),
  ];

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        appPageHorizontalPadding,
        0,
        appPageHorizontalPadding,
        20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '积分规则',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          for (final (index, (title, body, amount)) in rules.indexed) ...[
            if (index > 0) Divider(height: 1, color: context.colors.border),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          body,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.6,
                            color: context.colors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (amount.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    Text(
                      amount,
                      style: const TextStyle(
                        fontFamily: _displayFont,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _goldInk,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          _GradientButton(
            label: '我知道了',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  );
}

class _LedgerSheet extends StatefulWidget {
  const _LedgerSheet({required this.store});
  final AppStore store;

  @override
  State<_LedgerSheet> createState() => _LedgerSheetState();
}

class _LedgerSheetState extends State<_LedgerSheet> {
  final rows = <Map<String, dynamic>>[];
  String cursor = '';
  bool loading = true, loadingMore = false;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool more = false}) async {
    if (more && (cursor.isEmpty || loadingMore || loading)) return;
    setState(() {
      more ? loadingMore = true : loading = true;
      error = null;
    });
    try {
      final result = await widget.store.request(
        'GetWalletTransactions',
        query: {'limit': '30', if (more) 'cursor': cursor},
      );
      if (!mounted) return;
      final page = items(result.data);
      setState(() {
        if (!more) rows.clear();
        rows.addAll(
          page.where((row) => !more || !rows.any((v) => v['id'] == row['id'])),
        );
        cursor = result.nextCursor;
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) {
        setState(() => more ? loadingMore = false : loading = false);
      }
    }
  }

  static String when(Object? value) {
    final time = DateTime.tryParse('$value')?.toLocal();
    if (time == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${time.month}月${time.day}日 ${two(time.hour)}:${two(time.minute)}';
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .7,
      child: Column(
        children: [
          const Text(
            '积分明细',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Builder(
              builder: (context) {
                if (loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (error != null && rows.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(error!),
                        TextButton(onPressed: load, child: const Text('重新加载')),
                      ],
                    ),
                  );
                }
                if (rows.isEmpty) {
                  return Center(
                    child: Text(
                      '还没有积分记录，去签到或做任务吧',
                      style: TextStyle(color: context.colors.muted),
                    ),
                  );
                }
                return AutoPaginate(
                  canLoad: cursor.isNotEmpty && !loadingMore && error == null,
                  onLoadMore: () => load(more: true),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      appPageHorizontalPadding,
                      0,
                      appPageHorizontalPadding,
                      16,
                    ),
                    itemCount: rows.length + 1,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: context.colors.border),
                    itemBuilder: (context, index) {
                      if (index == rows.length) {
                        return error == null
                            ? PageLoadingFooter(visible: loadingMore)
                            : TextButton(
                                onPressed: () => load(more: true),
                                child: const Text('加载失败，点击重试'),
                              );
                      }
                      final row = rows[index];
                      final income = row['direction'] == 'IN';
                      final amount = integer(row['amount_points']);
                      final title = '${row['description'] ?? ''}'.trim();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title.isEmpty ? '积分变动' : title,
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    when(row['created_at']),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.colors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${income ? '+' : '-'}$amount',
                              style: TextStyle(
                                fontFamily: _displayFont,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: income ? _goldInk : context.colors.ink,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
