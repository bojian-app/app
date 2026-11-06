import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_icons.dart';
import 'app_store.dart';
import 'design.dart';
import 'discovery.dart' show DiscoveryPage;
import 'invitation_page.dart';
import 'resume_pages.dart';
import 'resume_user_share.dart';
import 'rewarded_ad.dart';
import 'story_composer.dart';
import 'template_market.dart' show MarketTemplateArtwork;

const _displayFont = 'ResumeDocument';
const _goldInk = Color(0xFFE07B00);
const _orange = [Color(0xFFFF9A2E), Color(0xFFFF5A1F)];
const _dailyTasks = ['PUBLISH_ARTICLE', 'REQUEST_REVIEW', 'HELP_REVIEW'];

/// Height of the coloured hero; the check-in card overlaps its lower edge.
const _heroHeight = 300.0;

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
      context.isDark ? const Color(0xFF23356B) : const Color(0xFF3F86FF);

  @override
  State<PointsPage> createState() => _PointsPageState();
}

class _PointsPageState extends State<PointsPage> with TickerProviderStateMixin {
  final tasks = <String, Map<String, dynamic>>{};
  final templates = <Map<String, dynamic>>[];
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
      () async {
        try {
          final result = await store.request(
            'GetTemplates',
            query: {'pricing': 'PAID', 'limit': '3'},
          );
          if (!mounted || epoch != store.epoch) return;
          setState(() {
            templates
              ..clear()
              ..addAll(
                (result.data['items'] as List? ?? [])
                    .whereType<Map>()
                    .map((row) => Map<String, dynamic>.from(row))
                    .take(3),
              );
          });
        } catch (_) {
          // The market link stays available when the preview list fails.
          if (mounted && epoch == store.epoch) setState(templates.clear);
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

  void market() => openPage(context, TemplateMarket(store: store));

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
      final dark = context.isDark;
      final topInset = MediaQuery.paddingOf(context).top;
      return AnnotatedRegion<SystemUiOverlayStyle>(
        // The hero is saturated blue in both themes.
        value: appSystemUiStyle(context).copyWith(
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
                color: brandBlue,
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
                        child: _HeroBackground(dark: dark),
                      ),
                      Column(
                        children: [
                          SizedBox(height: topInset),
                          _topBar(),
                          _hero(),
                          DataStatus(
                            store: store,
                            section: 'profile',
                            empty: false,
                          ),
                          if (showCheckIn) _checkIn(),
                          if (store.isAuthenticated) ...[
                            if (!showCheckIn) const SizedBox(height: 4),
                            _invite(),
                            _tasks(),
                          ],
                          _redeem(),
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

  Widget _topBar() => SizedBox(
    width: double.infinity,
    height: 44,
    child: Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: _Pill(label: '规则', onTap: rules),
      ),
    ),
  );

  Widget _hero() {
    final points = heldPoints ?? store.points;
    const white = Colors.white;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: showCheckIn ? 170 : 190),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _Coin(size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '我的积分',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: white.withValues(alpha: .85),
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
                const SizedBox(height: 10),
                if (store.isAuthenticated)
                  _Pill(
                    key: const ValueKey('points-ledger'),
                    label: '积分明细 ›',
                    onTap: ledger,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.fromLTRB(14, 16, 14, 6),
  }) => Container(
    width: double.infinity,
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    padding: padding,
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(20),
    ),
    child: child,
  );

  /// Section title with a small gradient accent bar.
  Widget _sectionHead(String title, Widget trailing) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 0, 2, 4),
    child: Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF4F8DFF), Color(0xFF6A4CFF)],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
        trailing,
      ],
    ),
  );

  Widget _checkIn() {
    final days = store.rewardDays;
    final today = store.rewardDay - 1;
    final signed = days.where((day) => day['status'] == 'CLAIMED').length;
    final claimed = store.rewardClaimed;
    final nextPoints = today >= 0 && today + 1 < days.length
        ? integer(days[today + 1]['points'])
        : 0;
    final disabled =
        claimed ||
        claiming ||
        store.rewardPoints == null ||
        store.pending.contains('reward');
    final total = days.fold<int>(0, (sum, day) => sum + integer(day['points']));
    Widget tile(int i) => _DayTile(
      key: i == today ? todayKey : null,
      points: integer(days[i]['points']),
      status: '${days[i]['status']}',
      label: i == today
          ? '今天'
          : today >= 0 && i == today + 1
          ? '明天'
          : '第${i + 1}天',
      bonus: i == 6,
    );
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E328C).withValues(alpha: .12),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: '已签到 '),
                        TextSpan(
                          text: '$signed',
                          style: const TextStyle(
                            fontFamily: _displayFont,
                            fontSize: 26,
                            color: brandBlue,
                          ),
                        ),
                        const TextSpan(text: ' 天'),
                      ],
                    ),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.isDark
                        ? const Color(0xFF3A2C12)
                        : const Color(0xFFFFF1DA),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '7 天共 $total 积分',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB15A00),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < 7; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(flex: i == 6 ? 2 : 1, child: tile(i)),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _GoldButton(
            key: const ValueKey('profile-claim-reward'),
            label: claimed
                ? nextPoints > 0
                      ? '今日已签到，明天再来领 $nextPoints'
                      : '今日已签到'
                : claiming
                ? '签到中…'
                : '立即签到 领 ${store.rewardPoints ?? '—'} 积分',
            onPressed: disabled ? null : checkIn,
          ),
        ],
      ),
    );
  }

  Widget _invite() => Container(
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    padding: const EdgeInsets.all(16),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: context.isDark
            ? const [Color(0xFF4A3410), Color(0xFF5E3A0E)]
            : const [Color(0xFFFFE9B8), Color(0xFFFFC56B)],
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '邀请好友',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _inviteInk(context).withValues(alpha: .75),
                ),
              ),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: '500',
                      style: TextStyle(
                        fontFamily: _displayFont,
                        fontSize: 32,
                        height: 1.1,
                        color: Color(0xFFE5450F),
                      ),
                    ),
                    TextSpan(
                      text: ' 积分/人',
                      style: TextStyle(color: _inviteInk(context)),
                    ),
                  ],
                ),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '好友注册并绑定手机号后到账',
                style: TextStyle(
                  fontSize: 12,
                  color: _inviteInk(context).withValues(alpha: .7),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _OrangeButton(
          key: const ValueKey('points-invite'),
          label: '去邀请',
          onPressed: () => _openTask(() => InvitationPage(store: store)),
        ),
      ],
    ),
  );

  static Color _inviteInk(BuildContext context) =>
      context.isDark ? const Color(0xFFFFD98A) : const Color(0xFF5A2E00);

  Widget _tasks() {
    final done = _dailyTasks
        .where((task) => tasks[task]?['claimed'] == true)
        .length;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHead(
            '每日任务',
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    width: 64,
                    height: 6,
                    child: LinearProgressIndicator(
                      value: done / 3,
                      backgroundColor: context.colors.inset,
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xFFFFA22E),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$done/3',
                  style: TextStyle(fontSize: 12, color: context.colors.muted),
                ),
              ],
            ),
          ),
          _dailyTask(
            'PUBLISH_ARTICLE',
            '发一篇求职经验',
            '审核通过后可领',
            'assets/points/tasks/publish-material.webp',
            () => _openTask(() => StoryComposer(store: store)),
          ),
          _divider(),
          _dailyTask(
            'REQUEST_REVIEW',
            '请大家帮你改简历',
            '发出一份简历求助',
            'assets/points/tasks/request-material.webp',
            _requestOptimization,
          ),
          _divider(),
          _dailyTask(
            'HELP_REVIEW',
            '帮别人改简历',
            '留一条有用的修改建议',
            'assets/points/tasks/review-material.webp',
            _helpOthers,
          ),
          if (adEnabled) ...[
            _divider(),
            _TaskRow(
              actionKey: adKey,
              title: '看一段视频',
              note: '每次都能领',
              reward: 20,
              icon: Icons.play_circle_outline_rounded,
              colors: const [Color(0xFFB38BFF), Color(0xFF7A4CFF)],
              state: watchingAd ? _TaskState.busy : _TaskState.todo,
              action: watchingAd ? '播放中…' : '去观看',
              onPressed: watchingAd ? null : watchAd,
            ),
          ],
        ],
      ),
    );
  }

  Widget _divider() => Divider(height: 1, color: context.colors.border);

  Widget _dailyTask(
    String task,
    String title,
    String note,
    String imageAsset,
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
      progress: claimed || claimable ? '(1/1)' : '(0/1)',
      note: claimable || claimed ? null : note,
      reward: 100,
      imageAsset: imageAsset,
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

  Widget _redeem() {
    final points = heldPoints ?? store.points ?? 0;
    return _card(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHead(
            '积分兑模版',
            TextButton(
              key: const ValueKey('points-market'),
              onPressed: market,
              style: TextButton.styleFrom(
                foregroundColor: context.colors.muted,
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 32),
              ),
              child: const Text('全部 ›', style: TextStyle(fontSize: 13)),
            ),
          ),
          const SizedBox(height: 8),
          if (templates.isEmpty)
            InkWell(
              onTap: market,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: context.colors.inset,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  '去模版市场看看',
                  style: TextStyle(fontSize: 14, color: context.colors.muted),
                ),
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: i < templates.length
                        ? _TemplateTile(
                            template: templates[i],
                            balance: points,
                            onTap: market,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

/// Saturated blue-violet gradient with soft highlights and a fading dot grid.
class _HeroBackground extends StatelessWidget {
  const _HeroBackground({required this.dark});
  final bool dark;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? const [
                    Color(0xFF23356B),
                    Color(0xFF1C2C66),
                    Color(0xFF2E2470),
                  ]
                : const [
                    Color(0xFF3F86FF),
                    Color(0xFF2E5BF0),
                    Color(0xFF5A44E8),
                  ],
          ),
        ),
      ),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(.75, -.55),
            radius: .7,
            colors: [
              Colors.white.withValues(alpha: dark ? .1 : .25),
              Colors.white.withValues(alpha: 0),
            ],
          ),
        ),
      ),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-1, 1),
            radius: .9,
            colors: [
              const Color(0xFF8C5AFF).withValues(alpha: dark ? .3 : .55),
              const Color(0xFF8C5AFF).withValues(alpha: 0),
            ],
          ),
        ),
      ),
      const CustomPaint(painter: _DotsPainter()),
    ],
  );
}

class _DotsPainter extends CustomPainter {
  const _DotsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var y = 8.0; y < size.height * .7; y += 16) {
      // Dots fade out towards the bottom of the hero.
      paint.color = Colors.white.withValues(
        alpha: .18 * (1 - y / (size.height * .7)),
      );
      for (var x = 8.0; x < size.width; x += 16) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotsPainter oldDelegate) => false;
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      backgroundColor: Colors.white.withValues(alpha: .2),
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 30),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(fontSize: 13),
    ),
    child: Text(label),
  );
}

/// The check-in call to action: gold with a light sweep while it can be
/// pressed.
class _GoldButton extends StatefulWidget {
  const _GoldButton({super.key, required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  State<_GoldButton> createState() => _GoldButtonState();
}

class _GoldButtonState extends State<_GoldButton>
    with SingleTickerProviderStateMixin {
  late final shine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    sync();
  }

  @override
  void didUpdateWidget(_GoldButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    sync();
  }

  bool played = false;

  void sync() {
    final on =
        widget.onPressed != null && !MediaQuery.disableAnimationsOf(context);
    if (on && !played) {
      played = true;
      _playTimes(shine, 4);
    } else if (!on && shine.isAnimating) {
      shine
        ..stop()
        ..value = 1;
    }
  }

  @override
  void dispose() {
    shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final button = TextButton(
      onPressed: widget.onPressed,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF5A2E00),
        disabledForegroundColor: context.colors.muted,
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        textStyle: TextStyle(
          fontSize: enabled ? 17 : 15,
          fontWeight: enabled ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      child: Text(widget.label, textAlign: TextAlign.center),
    );
    if (!enabled) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.inset,
          borderRadius: BorderRadius.circular(99),
        ),
        child: button,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFD54F), Color(0xFFFFA21F)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9614).withValues(alpha: .4),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: shine,
                  builder: (context, _) {
                    // Sweeps across in the second half of each cycle.
                    final t = ((shine.value - .5) / .3).clamp(0.0, 1.0);
                    return FractionalTranslation(
                      translation: Offset(-1 + t * 2.2, 0),
                      child: Transform(
                        transform: Matrix4.skewX(-.35),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            width: 40,
                            color: Colors.white.withValues(alpha: .55),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            button,
          ],
        ),
      ),
    );
  }
}

class _OrangeButton extends StatelessWidget {
  const _OrangeButton({super.key, required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(99),
      gradient: const LinearGradient(
        colors: [Color(0xFFFF7A2E), Color(0xFFFF4D3A)],
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFFF4D3A).withValues(alpha: .35),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 15),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    ),
  );
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(99),
      gradient: const LinearGradient(colors: [brandBlue, Color(0xFF4F8DFF)]),
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

/// A gold coin drawn in code, so every size stays crisp.
class _Coin extends StatelessWidget {
  const _Coin({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _CoinPainter()),
  );
}

class _CoinPainter extends CustomPainter {
  const _CoinPainter();

  static final _star = () {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? 4.7 : 2.0;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = Offset(12 + math.cos(a) * r, 11.6 + math.sin(a) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }();

  /// Paints a 24-unit coin scaled into [rect].
  static void paintCoin(
    Canvas canvas,
    Rect rect, {
    double opacity = 1,
    bool shadow = false,
  }) {
    canvas.save();
    canvas.translate(rect.left, rect.top);
    canvas.scale(rect.width / 24);
    Color fade(Color color) =>
        color.withValues(alpha: color.a * opacity.clamp(0, 1));
    if (shadow) {
      canvas.drawCircle(
        const Offset(12, 14),
        10.5,
        Paint()
          ..color = fade(const Color(0x590A1E5A))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
    canvas.drawCircle(
      const Offset(12, 13),
      10.5,
      Paint()..color = fade(const Color(0xFFD97800)),
    );
    canvas.drawCircle(
      const Offset(12, 11.6),
      10.4,
      Paint()
        ..shader =
            RadialGradient(
              center: const Alignment(-.3, -.4),
              radius: .9,
              colors: [
                fade(const Color(0xFFFFF1A8)),
                fade(const Color(0xFFFFC72C)),
                fade(const Color(0xFFF08A00)),
              ],
              stops: const [0, .55, 1],
            ).createShader(
              Rect.fromCircle(center: const Offset(12, 11.6), radius: 10.4),
            ),
    );
    canvas.drawCircle(
      const Offset(12, 11.6),
      7.4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = fade(const Color(0xFFFFE68A)),
    );
    canvas.drawPath(_star, Paint()..color = fade(const Color(0xFFF29A00)));
    canvas.save();
    canvas.translate(8.6, 6.6);
    canvas.rotate(-.5);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 5.2, height: 2.8),
      Paint()..color = fade(Colors.white.withValues(alpha: .6)),
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) => paintCoin(canvas, Offset.zero & size);

  @override
  bool shouldRepaint(_CoinPainter oldDelegate) => false;
}

/// Balance digits that roll to their new value like an odometer.
class _Odometer extends StatelessWidget {
  const _Odometer({required this.value});
  final int value;
  static const _height = 52.0;

  static TextStyle style(BuildContext context) => TextStyle(
    fontFamily: _displayFont,
    fontSize: 46,
    height: _height / 46,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    shadows: [
      Shadow(
        color: const Color(0xFF141E78).withValues(alpha: .3),
        blurRadius: 14,
        offset: const Offset(0, 4),
      ),
    ],
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

/// One day of the newcomer gift. Today glows; the tile flips to its claimed
/// face when the claim is confirmed.
class _DayTile extends StatefulWidget {
  const _DayTile({
    super.key,
    required this.points,
    required this.status,
    required this.label,
    required this.bonus,
  });
  final int points;
  final String status, label;
  final bool bonus;

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

    Widget face({required bool claimed}) {
      final Color ink = claimed
          ? (dark ? const Color(0xFF8FB0F5) : const Color(0xFF6B8BD8))
          : today
          ? const Color(0xFF7A4300)
          : widget.bonus
          ? const Color(0xFFB15A00)
          : colors.ink;
      final Gradient? gradient = claimed
          ? null
          : today
          ? const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFE68E), Color(0xFFFFBE2E)],
            )
          : widget.bonus
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? const [Color(0xFF4A3410), Color(0xFF5E3A0E)]
                  : const [Color(0xFFFFF3D6), Color(0xFFFFDFA6)],
            )
          : null;
      final Widget icon = claimed
          ? Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: brandBlue,
              ),
              child: const Icon(Icons.check, size: 15, color: Colors.white),
            )
          : widget.bonus
          ? Image.asset(
              'assets/points/rewards-transparent.webp',
              height: 40,
              excludeFromSemantics: true,
            )
          : missed
          ? const ColorFiltered(
              colorFilter: ColorFilter.matrix([
                .33, .33, .33, 0, 0, //
                .33, .33, .33, 0, 0, //
                .33, .33, .33, 0, 0, //
                0, 0, 0, 1, 0,
              ]),
              child: _Coin(size: 24),
            )
          : const _Coin(size: 24);
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: gradient == null
              ? claimed
                    ? (dark ? const Color(0xFF1F2A40) : const Color(0xFFEAF1FF))
                    : colors.inset
              : null,
          gradient: gradient,
          boxShadow: today && !claimed
              ? [
                  BoxShadow(
                    color: const Color(0xFFFFAA14).withValues(alpha: .45),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Opacity(
          opacity: missed ? .55 : 1,
          // Scales as one block so enlarged text never overflows the tile.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '+${widget.points}',
                  style: TextStyle(
                    fontFamily: _displayFont,
                    fontSize: widget.bonus && !claimed ? 15 : 13,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 3),
                icon,
                const SizedBox(height: 3),
                Text(
                  claimed
                      ? '已签'
                      : missed
                      ? '漏签'
                      : widget.bonus
                      ? '第7天大奖'
                      : widget.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: today && !claimed
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: claimed || today || widget.bonus
                        ? ink
                        : colors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Semantics(
      label:
          '${widget.label} ${widget.points} 积分 ${widget.status == 'CLAIMED'
              ? '已签'
              : missed
              ? '漏签'
              : ''}',
      excludeSemantics: true,
      child: SizedBox(
        height: 80,
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
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                width: 2,
                                color: const Color(0xFFFFC93D)
                                    .withValues(alpha: .9 * (1 - glow.value)),
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
            if (widget.bonus)
              Positioned(
                top: -9,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF4D4D),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                      bottomLeft: Radius.circular(2),
                    ),
                  ),
                  child: const Text(
                    '大礼',
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
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
    this.note,
    required this.reward,
    this.icon,
    this.imageAsset,
    this.colors = const [],
    required this.state,
    required this.action,
    required this.onPressed,
  });
  final Key? actionKey;
  final String title, action;
  final String? progress, note;
  final int reward;
  final IconData? icon;
  final String? imageAsset;
  final List<Color> colors;
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
    final button = TextButton(
      key: widget.actionKey,
      onPressed: widget.onPressed,
      style: TextButton.styleFrom(
        foregroundColor: claim ? Colors.white : brandBlue,
        disabledForegroundColor: done ? colors.muted : brandBlue,
        backgroundColor: claim
            ? null
            : done
            ? colors.inset
            : colors.accentSoft,
        minimumSize: const Size(80, 32),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      child: Text(widget.action),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 2),
      child: Row(
        children: [
          Opacity(
            opacity: done ? .45 : 1,
            child: widget.imageAsset != null
                ? Image.asset(
                    widget.imageAsset!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  )
                : Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: done
                            ? [colors.muted, colors.muted]
                            : widget.colors,
                      ),
                    ),
                    child: Icon(widget.icon, size: 22, color: Colors.white),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: widget.title),
                      if (widget.progress != null)
                        TextSpan(
                          text: ' ${widget.progress}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                            color: colors.muted,
                          ),
                        ),
                    ],
                  ),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: done ? colors.muted : colors.ink,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const _Coin(size: 15),
                    const SizedBox(width: 3),
                    Text(
                      '+${widget.reward}',
                      style: const TextStyle(
                        fontFamily: _displayFont,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _goldInk,
                      ),
                    ),
                    if (widget.note != null) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          widget.note!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: colors.muted),
                        ),
                      ),
                    ],
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
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: const LinearGradient(colors: _orange),
                  boxShadow: [
                    BoxShadow(
                      color: _orange.last.withValues(alpha: .35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: button,
              ),
            )
          else
            button,
        ],
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.template,
    required this.balance,
    required this.onTap,
  });
  final Map<String, dynamic> template;
  final int balance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final price = integer(template['price_points']);
    final affordable = balance >= price;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        decoration: BoxDecoration(
          color: context.colors.inset,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 104,
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: MarketTemplateArtwork(template: template),
            ),
            const SizedBox(height: 8),
            Text(
              '${template['name'] ?? ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const _Coin(size: 14),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    '$price',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: _displayFont,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _goldInk,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              affordable ? '可兑换' : '还差 ${price - balance}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: affordable ? brandBlue : context.colors.muted,
              ),
            ),
          ],
        ),
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
      _CoinPainter.paintCoin(
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
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
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
  late Future<List<Map<String, dynamic>>> rows = load();

  Future<List<Map<String, dynamic>>> load() async {
    final result = await widget.store.request(
      'GetWalletTransactions',
      query: {'limit': '50'},
    );
    return (result.data['items'] as List? ?? [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
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
            child: FutureBuilder(
              future: rows,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${snapshot.error}'),
                        TextButton(
                          onPressed: () => setState(() => rows = load()),
                          child: const Text('重新加载'),
                        ),
                      ],
                    ),
                  );
                }
                final items = snapshot.data!;
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      '还没有积分记录，去签到或做任务吧',
                      style: TextStyle(color: context.colors.muted),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: context.colors.border),
                  itemBuilder: (context, index) {
                    final row = items[index];
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
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
