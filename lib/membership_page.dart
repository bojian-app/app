import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hugeicons/hugeicons.dart';

import 'api/bojian_api.dart';
import 'app_page_bar.dart';
import 'app_store.dart';
import 'confirmation_dialog.dart';
import 'design.dart';
import 'profile_avatar.dart';
import 'template_market.dart' show MarketTemplateArtwork;

/// 会员套餐。价格与服务端 membershipPlans 保持一致，下单时以服务端金额为准。
class MembershipPlan {
  const MembershipPlan({
    required this.code,
    required this.title,
    required this.orderName,
    required this.amountCents,
    required this.period,
    required this.days,
  });
  final String code, title, orderName, period;
  final int amountCents, days;

  String get price =>
      (amountCents / 100).toStringAsFixed(amountCents % 100 == 0 ? 0 : 2);

  /// 按天折算，向下取两位，不夸大优惠。
  String get perDay => ((amountCents / days).floor() / 100).toStringAsFixed(2);
}

const membershipPlans = [
  MembershipPlan(
    code: 'YEAR',
    title: '年卡',
    orderName: '会员年卡',
    amountCents: 12800,
    period: '12 个月',
    days: 365,
  ),
  MembershipPlan(
    code: 'MONTH',
    title: '月卡',
    orderName: '会员月卡',
    amountCents: 2500,
    period: '1 个月',
    days: 30,
  ),
];

/// 年卡相比连续买 12 个月卡省下的钱（元）。
int get _yearSaving =>
    (membershipPlans[1].amountCents * 12 - membershipPlans[0].amountCents) ~/
    100;

/// 免费用户与会员的权益对照，数值与服务端 benefitsFor 一致。
const _benefits = [
  (HugeIcons.strokeRoundedLayout01, '付费模板', '兑换后限 24h', '全部免费用'),
  (HugeIcons.strokeRoundedAiMagic, 'AI 整份生成', '不提供', '单月 30 次'),
  (HugeIcons.strokeRoundedAiIdea, 'AI 单段生成', '不提供', '单月 100 次'),
  (HugeIcons.strokeRoundedAdvertisiment, '广告', '显示', '不显示'),
];

const _faqs = [
  ('开通后多久生效？', '支付成功后立即生效，有效期从开通时刻起算。已是会员时续费，有效期在当前到期时间上顺延。'),
  ('到期会自动扣费吗？', '不会。月卡和年卡都是一次性购买，到期后不续费就恢复为免费用户，已编辑的简历和导出的文件都会保留。'),
  ('会员能在其他手机上用吗？', '可以。会员绑定博简账号，登录同一账号的手机都能使用会员权益。'),
  ('之前用积分兑换的模板会失效吗？', '不会。改版前兑换的模板继续永久可用；开通会员后所有付费模板都可直接使用。'),
];

// 黑金配色：暖黑底 + 香槟金，只用于会员相关页面。
const _bg = Color(0xFF0F0D0A);
const _surface = Color(0xFF1B1813);
const _surfaceHi = Color(0xFF26211A);
const _line = Color(0x2EE8C992);
const _text = Color(0xFFF4ECDD);
const _muted = Color(0xFF948B7A);
const _gold = Color(0xFFEBCB91);
const _goldDeep = Color(0xFFC99A55);
const _goldInk = Color(0xFF4A2F0E);

/// 浅色确认订单页沿用 App 蓝色主题。
const _blueGradient = [Color(0xFF3F7BFF), Color(0xFF1C4FD8)];
const _champagne = [Color(0xFFFFEBC4), Color(0xFFEBC583), Color(0xFFC9934A)];

LinearGradient get _champagneGradient => const LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: _champagne,
);

/// 金色渐变文字。
class _GoldText extends StatelessWidget {
  const _GoldText(this.text, {required this.style});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: (bounds) => const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFFF1D2), Color(0xFFEBC583), Color(0xFFC08A43)],
    ).createShader(bounds),
    child: Text(text, style: style),
  );
}

/// 会员开通页：会员身份、权益、套餐、专享模板、权益对比和常见问题。
class MembershipPage extends StatefulWidget {
  const MembershipPage({super.key, required this.store});
  final AppStore store;

  @override
  State<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends State<MembershipPage> {
  MembershipPlan selected = membershipPlans.first;
  DateTime? endsAt;
  List<Map<String, dynamic>> templates = const [];
  final scroll = ScrollController();
  bool barSolid = false;

  AppStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    scroll.addListener(() {
      final solid = scroll.offset > 24;
      if (solid != barSolid) setState(() => barSolid = solid);
    });
    _loadStatus();
    _loadTemplates();
  }

  Future<void> _loadStatus() async {
    try {
      final result = await store.request('GetMembership');
      final value = result.data['ends_at'];
      if (!mounted || result.data['active'] != true || value is! String) return;
      setState(() => endsAt = DateTime.tryParse(value)?.toLocal());
    } catch (_) {
      // 会员状态读取失败时按未开通展示，不影响选购。
    }
  }

  Future<void> _loadTemplates() async {
    try {
      final result = await store.request(
        'GetTemplates',
        query: {'limit': '12', 'pricing': 'PAID'},
      );
      if (!mounted) return;
      setState(
        () =>
            templates = items(result.data)
                .where((row) => '${row['thumbnail_url'] ?? ''}'.isNotEmpty)
                .toList(),
      );
    } catch (_) {
      // 模板展示是补充信息，读取失败时隐藏该区块。
    }
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        extendBodyBehindAppBar: true,
        appBar: AppPageBar(
          title: const Text('开通会员'),
          backgroundColor: barSolid ? _bg : Colors.transparent,
          foregroundColor: _text,
        ),
        body: ListView(
          controller: scroll,
          padding: EdgeInsets.zero,
          children: [
            _Header(store: store, endsAt: endsAt),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('选择套餐'),
                  const SizedBox(height: 14),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final plan in membershipPlans) ...[
                          if (plan != membershipPlans.first)
                            const SizedBox(width: 12),
                          Expanded(
                            child: _PlanCard(
                              plan: plan,
                              selected: plan == selected,
                              onTap: () => setState(() => selected = plan),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedInformationCircle,
                        size: 14,
                        color: _muted,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '一次性购买，到期不自动扣费',
                        style: TextStyle(fontSize: 12, color: _muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (templates.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 32, 16, 14),
                child: _SectionTitle('会员专享模板', trailing: '付费模板开通即用'),
              ),
              _TemplateStrip(templates: templates),
            ],
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 32, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle('会员权益'),
                  SizedBox(height: 14),
                  _BenefitTable(),
                  SizedBox(height: 32),
                  _SectionTitle('常见问题'),
                  SizedBox(height: 14),
                  _FaqList(),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _BottomPayBar(
          dark: true,
          label: endsAt == null ? '立即开通' : '立即续费',
          amount: selected.price,
          footer: const _AutoRenewToggle(),
          onPressed: () => openPage<void>(
            context,
            MembershipCheckoutPage(store: store, plan: selected),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.store, this.endsAt});
  final AppStore store;
  final DateTime? endsAt;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final ends = endsAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TreeHero(
          top: top,
          identity: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _champagneGradient,
                ),
                child: ProfileAvatar(
                  seed: profileAvatarSeed(store),
                  url: store.avatarURL,
                  size: 36,
                  borderRadius: 18,
                ),
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name.isEmpty ? '博简用户' : store.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ends == null
                          ? '尚未开通会员'
                          : '有效期至 ${ends.year}-${_two(ends.month)}-${_two(ends.day)}',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 12,
                        color: ends == null ? _muted : _gold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    '可享 ',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _text,
                    ),
                  ),
                  _GoldText(
                    '${_privileges.length}',
                    style: const TextStyle(
                      fontSize: 22,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    ' 项会员权益',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _text,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '低至 ¥${membershipPlans.first.perDay}/天',
                    style: const TextStyle(fontSize: 12, color: _gold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (final (icon, title, subtitle) in _privileges)
                    _Privilege(icon: icon, title: title, subtitle: subtitle),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 首屏主视觉：发光金树立在金边沙丘上，左下角放会员身份。
class _TreeHero extends StatelessWidget {
  const _TreeHero({required this.top, required this.identity});
  final double top;
  final Widget identity;

  static const _treeAspect = 960 / 719;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final treeWidth = width * .74;
      final treeHeight = treeWidth / _treeAspect;
      final treeLeft = width * .57 - treeWidth / 2;
      final treeTop = top - 6;
      final height = treeTop + treeHeight + 34;
      return SizedBox(
        height: height,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: width * .57 - 190,
              top: treeTop + treeHeight * .5 - 190,
              child: const _Glow(size: 380, color: Color(0x40F2B544)),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 120,
              child: const CustomPaint(painter: _DunesPainter(front: false)),
            ),
            Positioned(
              left: treeLeft,
              top: treeTop,
              width: treeWidth,
              height: treeHeight,
              child: Image.asset(
                'assets/membership/golden_tree.webp',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 120,
              child: const IgnorePointer(
                child: CustomPaint(painter: _DunesPainter(front: true)),
              ),
            ),
            Positioned(left: 20, bottom: 18, child: identity),
          ],
        ),
      );
    },
  );
}

/// 两层暗色沙丘，顶边带金色描光；前景层只覆盖左侧，让树根光环露出来。
class _DunesPainter extends CustomPainter {
  const _DunesPainter({required this.front});
  final bool front;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final edge = Path();
    if (front) {
      edge
        ..moveTo(0, h * .5)
        ..cubicTo(w * .22, h * .38, w * .42, h * .62, w * .62, h * .86)
        ..cubicTo(w * .75, h * 1.0, w * .9, h * .96, w, h * .9);
    } else {
      edge
        ..moveTo(0, h * .36)
        ..cubicTo(w * .2, h * .16, w * .38, h * .3, w * .55, h * .5)
        ..cubicTo(w * .72, h * .68, w * .86, h * .4, w, h * .3);
    }
    final fill = Path.from(edge)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: front
              ? const [Color(0xFF1A150F), _bg]
              : const [Color(0xFF2A2116), Color(0xFF15120D)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      edge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = front ? 1.2 : 1.6
        ..shader = LinearGradient(
          colors: [
            _gold.withValues(alpha: 0),
            _gold.withValues(alpha: front ? .45 : .7),
            _gold.withValues(alpha: 0),
          ],
          stops: front ? const [0, .35, 1] : const [0, .55, 1],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _DunesPainter oldDelegate) =>
      oldDelegate.front != front;
}

const _privileges = [
  (HugeIcons.strokeRoundedLayout01, '付费模板', '全部免费用'),
  (HugeIcons.strokeRoundedAiMagic, 'AI 整份生成', '单月 30 次'),
  (HugeIcons.strokeRoundedAiIdea, 'AI 单段生成', '单月 100 次'),
  (HugeIcons.strokeRoundedAdvertisiment, '去除广告', '全程清爽'),
];

String _two(int value) => value.toString().padLeft(2, '0');

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    ),
  );
}

class _Privilege extends StatelessWidget {
  const _Privilege({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final List<List<dynamic>> icon;
  final String title, subtitle;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2E271D), Color(0xFF1A1611)],
            ),
            border: Border.all(color: _gold.withValues(alpha: .35)),
          ),
          child: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => _champagneGradient.createShader(bounds),
            child: HugeIcon(icon: icon, size: 22, color: Colors.white),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          maxLines: 1,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _text,
          ),
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(fontSize: 11, color: _muted)),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.trailing});
  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Container(
        width: 4,
        height: 16,
        margin: const EdgeInsets.only(right: 8, bottom: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFEBC4), _goldDeep],
          ),
        ),
      ),
      Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: _text,
        ),
      ),
      const Spacer(),
      if (trailing != null)
        Text(trailing!, style: const TextStyle(fontSize: 12, color: _muted)),
    ],
  );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });
  final MembershipPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final year = plan.code == 'YEAR';
    final priceStyle = const TextStyle(
      fontSize: 36,
      height: 1.1,
      fontWeight: FontWeight.w800,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    final price = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        selected
            ? const _GoldText(
                '¥',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              )
            : const Text(
                '¥',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _text,
                ),
              ),
        selected
            ? _GoldText(plan.price, style: priceStyle)
            : Text(plan.price, style: priceStyle.copyWith(color: _text)),
      ],
    );
    return Semantics(
      selected: selected,
      button: true,
      label: '${plan.title} ${plan.price} 元',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        // 选中态与未选中态布局完全一致，只整体淡入淡出，避免边框和渐变逐项插值造成跳动。
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          layoutBuilder: (current, previous) => Stack(
            fit: StackFit.passthrough,
            children: [...previous, ?current],
          ),
          child: Container(
            key: ValueKey(selected),
            padding: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: selected ? _champagneGradient : null,
              color: selected ? null : _line,
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x40C9934A),
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14.5),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: selected
                      ? const [Color(0xFF3A2D1B), Color(0xFF1E1912)]
                      : const [_surfaceHi, _surface],
                ),
              ),
              child: Stack(
                children: [
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 28, 12, 14),
                        child: Column(
                          children: [
                            Text(
                              plan.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: selected ? _gold : _text,
                              ),
                            ),
                            const SizedBox(height: 6),
                            price,
                            const SizedBox(height: 4),
                            Text(
                              '折合 ¥${plan.perDay}/天',
                              style: const TextStyle(
                                fontSize: 12,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          gradient: selected ? _champagneGradient : null,
                          color: selected ? null : Colors.black26,
                        ),
                        child: Text(
                          year ? '预计可省 ¥$_yearSaving' : '适合短期求职冲刺',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: selected ? _goldInk : _muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (year)
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFFF8A4C), Color(0xFFE5402E)],
                          ),
                          borderRadius: BorderRadius.only(
                            bottomRight: Radius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '最划算',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  if (selected)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: _champagneGradient,
                        ),
                        child: const HugeIcon(
                          icon: HugeIcons.strokeRoundedTick02,
                          size: 13,
                          color: _goldInk,
                        ),
                      ),
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

/// 横向滚动展示真实的付费模板缩略图。
class _TemplateStrip extends StatelessWidget {
  const _TemplateStrip({required this.templates});
  final List<Map<String, dynamic>> templates;

  /// 缩略图按 A4 纸张比例显示，与模板市场一致，避免裁切。
  static const _cardWidth = 116.0, _pageRatio = 595 / 842;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _cardWidth / _pageRatio + 26,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: templates.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final template = templates[index];
          return SizedBox(
            width: _cardWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: _pageRatio,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        MarketTemplateArtwork(
                          template: template,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          left: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              gradient: _champagneGradient,
                              borderRadius: const BorderRadius.only(
                                bottomRight: Radius.circular(8),
                              ),
                            ),
                            child: const Text(
                              '会员免费',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _goldInk,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${template['name'] ?? '简历模板'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: _text),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BenefitTable extends StatelessWidget {
  const _BenefitTable();

  @override
  Widget build(BuildContext context) {
    const memberTint = Color(0x1FEBC583);
    Widget cell(Widget child, {bool member = false, int flex = 4}) => Expanded(
      flex: flex,
      child: Container(
        color: member ? memberTint : null,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: child,
      ),
    );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                cell(
                  const Text(
                    '特权',
                    style: TextStyle(fontSize: 12, color: _muted),
                  ),
                  flex: 5,
                ),
                cell(
                  const Text(
                    '免费用户',
                    style: TextStyle(fontSize: 12, color: _muted),
                  ),
                ),
                cell(
                  const Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedCrown,
                        size: 14,
                        color: _gold,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '会员',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _gold,
                        ),
                      ),
                    ],
                  ),
                  member: true,
                ),
              ],
            ),
          ),
          for (final (icon, name, free, member) in _benefits)
            DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _line)),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    cell(
                      Row(
                        children: [
                          HugeIcon(icon: icon, size: 18, color: _gold),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _text,
                              ),
                            ),
                          ),
                        ],
                      ),
                      flex: 5,
                    ),
                    cell(
                      Text(
                        free,
                        style: const TextStyle(fontSize: 12, color: _muted),
                      ),
                    ),
                    cell(
                      Text(
                        member,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _gold,
                        ),
                      ),
                      member: true,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FaqList extends StatelessWidget {
  const _FaqList();

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Column(
          children: [
            for (final (index, (question, answer)) in _faqs.indexed)
              DecoratedBox(
                decoration: BoxDecoration(
                  border: index == 0
                      ? null
                      : const Border(top: BorderSide(color: _line)),
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  iconColor: _gold,
                  collapsedIconColor: _muted,
                  title: Text(
                    question,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _text,
                    ),
                  ),
                  children: [
                    Text(
                      answer,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 底部结算栏。会员页用黑金底配香槟金按钮，确认订单页用浅色底配蓝色按钮。
/// Records the buyer's auto-renew preference. Purchases stay one-off until
/// Alipay and WeChat recurring deduction are signed, so it is not sent yet.
class _AutoRenewToggle extends StatefulWidget {
  const _AutoRenewToggle();

  @override
  State<_AutoRenewToggle> createState() => _AutoRenewToggleState();
}

class _AutoRenewToggleState extends State<_AutoRenewToggle> {
  bool selected = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: selected,
      button: true,
      label: '自动续费',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => selected = !selected),
        child: Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 15,
                height: 15,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: selected ? _champagneGradient : null,
                  border: selected
                      ? null
                      : Border.all(color: _muted, width: 1.2),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded, size: 11, color: _goldInk)
                    : null,
              ),
              const SizedBox(width: 6),
              const Text('自动续费', style: TextStyle(fontSize: 12, color: _text)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomPayBar extends StatelessWidget {
  const _BottomPayBar({
    required this.label,
    required this.amount,
    this.footer,
    required this.onPressed,
    this.busy = false,
    this.dark = false,
  });
  final String label, amount;
  final Widget? footer;
  final VoidCallback? onPressed;
  final bool busy, dark;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final muted = dark ? _muted : colors.muted;
    final onButton = dark ? _goldInk : Colors.white;
    final amountWidget = dark
        ? _GoldText(
            '¥$amount',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          )
        : Text(
            '¥$amount',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: colors.accent,
            ),
          );
    return Container(
      decoration: BoxDecoration(
        color: dark ? _surface : colors.surface,
        border: Border(top: BorderSide(color: dark ? _line : colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [amountWidget, ?footer],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 46,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(23),
                    gradient: busy
                        ? LinearGradient(colors: [muted, muted])
                        : dark
                        ? _champagneGradient
                        : const LinearGradient(colors: _blueGradient),
                    boxShadow: busy
                        ? null
                        : [
                            BoxShadow(
                              color: dark
                                  ? const Color(0x50C9934A)
                                  : const Color(0x402867EE),
                              blurRadius: 14,
                              offset: Offset(0, 4),
                            ),
                          ],
                  ),
                  child: FilledButton(
                    onPressed: busy ? null : onPressed,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: onButton,
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(23),
                      ),
                    ),
                    child: busy
                        ? SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: onButton,
                            ),
                          )
                        : Text(
                            label,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: onButton,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 确认订单页：核对套餐与金额，选择支付方式后下单。
class MembershipCheckoutPage extends StatefulWidget {
  const MembershipCheckoutPage({
    super.key,
    required this.store,
    required this.plan,
  });
  final AppStore store;
  final MembershipPlan plan;

  @override
  State<MembershipCheckoutPage> createState() => _MembershipCheckoutPageState();
}

class _MembershipCheckoutPageState extends State<MembershipCheckoutPage> {
  String channel = 'ALIPAY';

  /// 服务端已启用的渠道；读取失败时两种都展示，由下单接口给出准确结果。
  Set<String> available = {'ALIPAY', 'WECHAT'};
  bool paying = false;

  /// 同一次确认使用同一幂等键，重复点击不会生成多笔订单。
  String? requestKey;

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    try {
      final result = await widget.store.request('GetMembershipPlans');
      final channels = (result.data['channels'] as List? ?? [])
          .whereType<String>()
          .toSet();
      if (!mounted || channels.isEmpty) return;
      setState(() {
        available = channels;
        if (!channels.contains(channel)) channel = channels.first;
      });
    } catch (_) {
      // 保留默认渠道列表。
    }
  }

  Future<void> _pay() async {
    if (paying) return;
    requestKey ??=
        'mobile-membership-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    setState(() => paying = true);
    try {
      final order = await widget.store.request(
        'PostMembershipOrders',
        body: {'plan_code': widget.plan.code, 'channel': channel},
        extra: {'idempotency-key': requestKey!},
      );
      if (!mounted) return;
      if (order.data['status'] == 'PAID') {
        toast(context, '会员已开通');
        Navigator.of(context).pop();
        return;
      }
      // 支付 SDK 尚未接入：订单已创建，但还不能调起收银台。
      toast(context, '${_channelName(channel)}暂未开放，请稍后再试');
    } on ApiFailure catch (e) {
      if (!mounted) return;
      if (e.code == 'MEMBERSHIP_ORDER_EXPIRED' ||
          e.code == 'IDEMPOTENCY_CONFLICT') {
        requestKey = null;
      }
      toast(context, e.message);
    } finally {
      if (mounted) setState(() => paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final plan = widget.plan;
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppPageBar(
        title: const Text('确认订单'),
        backgroundColor: colors.canvas,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _Card(
            child: Column(
              children: [
                Row(
                  children: [
                    _PlanThumb(plan: widget.plan),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.orderName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: colors.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '有效期 ${plan.period} · 到期不自动续费',
                            style: TextStyle(fontSize: 12, color: colors.muted),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '¥${plan.price}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colors.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: colors.border),
                const SizedBox(height: 12),
                _OrderLine(
                  '商品金额',
                  '¥${(plan.amountCents / 100).toStringAsFixed(2)}',
                ),
                _OrderLine('优惠', '-¥0.00'),
                _OrderLine(
                  '实付金额',
                  '¥${(plan.amountCents / 100).toStringAsFixed(2)}',
                  emphasize: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Card(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    '支付方式',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.ink,
                    ),
                  ),
                ),
                for (final option in const ['ALIPAY', 'WECHAT'])
                  if (available.contains(option))
                    _ChannelTile(
                      channel: option,
                      selected: channel == option,
                      onTap: paying
                          ? null
                          : () => setState(() => channel = option),
                    ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedSecurityCheck,
                size: 16,
                color: colors.muted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '会员为虚拟服务，支付成功后立即生效。付款后 30 分钟内未到账，请在“隐私与设置 → 意见反馈”联系我们。',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: colors.muted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: _BottomPayBar(
        label: '立即支付',
        amount: (plan.amountCents / 100).toStringAsFixed(2),
        busy: paying,
        onPressed: _pay,
      ),
    );
  }
}

String _channelName(String channel) => channel == 'WECHAT' ? '微信支付' : '支付宝';

/// 订单商品缩略图：黑金底上斜放一张迷你香槟金会员卡，标明年卡或月卡。
class _PlanThumb extends StatelessWidget {
  const _PlanThumb({required this.plan});
  final MembershipPlan plan;

  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF3A2C1A), _bg],
      ),
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        const Positioned(
          right: 5,
          top: 4,
          child: Text('✦', style: TextStyle(fontSize: 8, color: _gold)),
        ),
        Transform.rotate(
          angle: -.2,
          child: Container(
            width: 34,
            height: 23,
            padding: const EdgeInsets.fromLTRB(4, 3, 4, 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: _champagneGradient,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x80000000),
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const HugeIcon(
                  icon: HugeIcons.strokeRoundedCrown,
                  size: 8,
                  color: _goldInk,
                  strokeWidth: 2,
                ),
                Text(
                  plan.title,
                  style: const TextStyle(
                    fontSize: 7,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: _goldInk,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(14),
    ),
    child: child,
  );
}

class _OrderLine extends StatelessWidget {
  const _OrderLine(this.label, this.value, {this.emphasize = false});
  final String label, value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: emphasize ? colors.ink : colors.muted,
              fontWeight: emphasize ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasize ? 16 : 13,
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w400,
              color: emphasize ? colors.accent : colors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.channel,
    required this.selected,
    required this.onTap,
  });
  final String channel;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final wechat = channel == 'WECHAT';
    return Semantics(
      selected: selected,
      button: true,
      label: _channelName(channel),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // 两个渠道统一为 22 的品牌色圆角方块：支付宝标识自带方块，微信支付补一个绿底。
              wechat
                  ? Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF07C160),
                        borderRadius: BorderRadius.circular(3.5),
                      ),
                      child: SvgPicture.asset(
                        'assets/payment/wechat_pay.svg',
                        width: 16,
                        height: 16,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    )
                  : SvgPicture.asset(
                      'assets/payment/alipay.svg',
                      width: 22,
                      height: 22,
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _channelName(channel),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: colors.ink,
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? colors.accent : Colors.transparent,
                  border: Border.all(
                    color: selected ? colors.accent : colors.border,
                    width: 1.6,
                  ),
                ),
                child: selected
                    ? const HugeIcon(
                        icon: HugeIcons.strokeRoundedTick02,
                        size: 14,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 当前只在安卓开放购买；iOS 接入苹果内购前不显示入口。
bool get membershipPurchaseAvailable => Platform.isAndroid;

/// Explains a members-only rejection and offers the membership page.
/// Returns false for any other error so callers keep their own handling.
Future<bool> showMembershipRequired(
  BuildContext context,
  AppStore store,
  Object error,
) async {
  if (error is! ApiFailure || error.code != 'MEMBERSHIP_REQUIRED') {
    return false;
  }
  final purchasable = membershipPurchaseAvailable;
  final open = await showAppConfirmation(
    context,
    title: '会员专享',
    content: Text(error.message),
    confirmLabel: purchasable ? '开通会员' : '知道了',
    cancelLabel: purchasable ? '暂不' : null,
  );
  if (open == true && purchasable && context.mounted) {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => MembershipPage(store: store)),
    );
  }
  return true;
}
