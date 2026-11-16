import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hugeicons/hugeicons.dart';

import 'api/bojian_api.dart';
import 'app_page_bar.dart';
import 'app_store.dart';
import 'membership_status.dart';
import 'apple_membership_products.dart';
import 'apple_membership_purchases.dart';
import 'confirmation_dialog.dart';
import 'design.dart';
import 'legal_document.dart';
import 'legal_document_page.dart';
import 'panel_sheet.dart';
import 'profile_avatar.dart';
import 'template_market.dart' show MarketTemplateArtwork;

part 'membership_ai_addon.dart';
part 'membership_wallet.dart';
part 'membership_apple_checkout.dart';
part 'membership_order_result.dart';
part 'membership_theme.dart';

/// 会员套餐。价格与服务端 membershipPlans 保持一致，下单时以服务端金额为准。
class MembershipPlan {
  const MembershipPlan({
    required this.code,
    required this.title,
    required this.orderName,
    required this.amountCents,
    required this.period,
    required this.days,
    required this.aiCreateQuota,
    required this.aiPolishQuota,
    required this.aiTextQuota,
  });
  final String code, title, orderName, period;
  final int amountCents, days;

  /// 开通时一次性发放的整期 AI 次数，与服务端 membershipPlans 一致。
  final int aiCreateQuota, aiPolishQuota, aiTextQuota;

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
    aiCreateQuota: 180,
    aiPolishQuota: 180,
    aiTextQuota: 1200,
  ),
  MembershipPlan(
    code: 'MONTH',
    title: '月卡',
    orderName: '会员月卡',
    amountCents: 2500,
    period: '1 个月',
    days: 30,
    aiCreateQuota: 15,
    aiPolishQuota: 15,
    aiTextQuota: 100,
  ),
];

/// 免费用户与会员的权益对照；AI 次数开通时一次性发放，会员到期清零。
const _benefits = [
  (HugeIcons.strokeRoundedLayout01, '付费模板', '兑换后限 24h', '全部免费用'),
  (HugeIcons.strokeRoundedAiMagic, 'AI 简历生成', '不提供', '月卡 15 次\n年卡 180 次'),
  (HugeIcons.strokeRoundedAiEditing, 'AI 简历优化', '不提供', '月卡 15 次\n年卡 180 次'),
  (HugeIcons.strokeRoundedAiIdea, 'AI 单段生成', '不提供', '月卡 100 次\n年卡 1200 次'),
  (HugeIcons.strokeRoundedAdvertisiment, '广告', '显示', '不显示'),
];

const _faqs = [
  (
    '开通后多久生效？',
    '支付成功后立即生效，从购买时刻起算。每次购买都是独立的一份会员，不会在已有会员到期后顺延；同时有多份时，会员到期日以最晚的一份为准。',
  ),
  (
    'AI 次数怎么算？',
    '每次购买时一次性发放这一份的全部次数：月卡 AI 简历生成 15 次、AI 简历优化 15 次、单段生成 100 次，年卡 180 次、180 次、1200 次，三类次数分开计算。次数只在这一份的有效期内可用，到期剩余次数直接清零，不合并到其他份。同时有多份时，先扣最早到期的那一份。',
  ),
  (
    '到期会自动扣费吗？',
    '默认是一次性购买，不会自动扣费，到期后恢复为免费用户，已编辑的简历和导出的文件都会保留。iPhone 下单时勾选“自动续费”才会由 App Store 到期自动续订，可在 App Store 订阅管理中取消。',
  ),
  ('会员能在其他手机上用吗？', '可以。会员绑定博简账号，登录同一账号的手机都能使用会员权益。'),
  (
    '邀请好友能得到什么？',
    '好友用你的邀请码注册并绑定手机号后，你获得三天会员体验包：到账起 3 天内享受会员权益（免广告、付费模板免费用），另含 AI 简历生成 1 次、AI 简历优化 1 次、单段生成 10 次，到期清零。',
  ),
  ('之前用积分兑换的模板会失效吗？', '积分已下线。改版前兑换的模板在原有效期内继续可用；开通会员后所有付费模板都可直接使用。'),
];

// 晶体配色：深蓝灰底、铂银高光与冰蓝反射，只用于会员相关页面。
const _bg = Color(0xFF10151E);
const _surface = Color(0xFF1B2431);
const _surfaceHi = Color(0xFF273449);
const _line = Color(0x29C5D7EF);
const _text = Color(0xFFF0F5FC);
const _muted = Color(0xFF9CACC2);
const _platinum = Color(0xFFD4E6FF);
const _platinumInk = Color(0xFF203349);

/// 浅色确认订单页沿用 App 蓝色主题。
const _blueGradient = [Color(0xFF3F7BFF), Color(0xFF1C4FD8)];
const _crystal = [Color(0xFFF7FCFF), Color(0xFFCDDEF2), Color(0xFF91B3DD)];

LinearGradient get _crystalGradient => const LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: _crystal,
);

/// 会员开通页：会员身份、权益、套餐、专享模板、权益对比和常见问题。
class MembershipPage extends StatefulWidget {
  const MembershipPage({super.key, required this.store, this.embedded = false});
  final AppStore store;
  final bool embedded;
  static Color backgroundColor(BuildContext context) =>
      _MembershipColors.of(context).background;

  @override
  State<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends State<MembershipPage>
    with WidgetsBindingObserver {
  MembershipPlan selected = usesAppleMembership
      ? membershipPlans.last
      : membershipPlans.first;
  final AppleMembershipProducts? appleProducts = usesAppleMembership
      ? AppleMembershipProducts()
      : null;
  DateTime? endsAt;
  List<Map<String, dynamic>> templates = const [];
  AppleMembershipPurchases? applePurchases;
  int _membershipRevision = 0;
  int _statusRequest = 0;
  bool _membershipLoaded = false;
  bool _membershipLoading = true;
  String? _membershipPlanCode;
  List<_AIPack> _aiPacks = const [];
  _AIAddonBalance _aiAddon = const _AIAddonBalance();
  List<AIAddonOffer> _addonOffers = const [];
  Timer? _membershipExpiryTimer;
  bool _tabWasActive = true;

  AppStore get store => widget.store;

  /// 已开通年卡或月卡时用对应的会员标识图替换文字。
  String? get _membershipBadgeAsset {
    final ends = endsAt;
    if (!_membershipLoaded || ends == null || !ends.isAfter(DateTime.now())) {
      return null;
    }
    return switch (_membershipPlanCode) {
      'YEAR' => 'assets/membership/badge-year-blue.png',
      'MONTH' => 'assets/membership/badge-month-blue.png',
      _ => null,
    };
  }

  String get _membershipLabel {
    if (!_membershipLoaded) {
      return _membershipLoading ? '正在查询会员状态' : '会员状态暂不可用';
    }
    final ends = endsAt;
    if (ends == null) return '暂无有效会员';
    if (!ends.isAfter(DateTime.now())) return '会员已到期';
    return switch (_membershipPlanCode) {
      'YEAR' => '已开通年度会员',
      'MONTH' => '已开通月度会员',
      _ when _aiPacks.isNotEmpty && _aiPacks.every((pack) => pack.referral) =>
        '会员体验中',
      _ => '已开通会员',
    };
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStatus();
    _loadTemplates();
    if (usesAppleMembership) {
      _addonOffers = _appleAddonOffers;
    } else {
      _loadAddonOffers();
    }
    appleProducts?.addListener(_productsChanged);
    appleProducts?.load();
    if (appleProducts != null) {
      applePurchases = AppleMembershipPurchases.forStore(store);
      _membershipRevision = applePurchases!.membershipRevision;
      applePurchases!.addListener(_purchasesChanged);
    }
  }

  void _purchasesChanged() {
    if (!mounted) return;
    if (_membershipRevision != applePurchases!.membershipRevision) {
      _membershipRevision = applePurchases!.membershipRevision;
      unawaited(_loadStatus());
    }
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.embedded) return;
    final active = TickerMode.valuesOf(context).enabled;
    if (active && !_tabWasActive) unawaited(_loadStatus());
    _tabWasActive = active;
  }

  void _productsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadStatus() async {
    final request = ++_statusRequest;
    if (!_membershipLoaded && !_membershipLoading && mounted) {
      setState(() => _membershipLoading = true);
    }
    try {
      final result = await store.request('GetMembership');
      final active = result.data['active'];
      final value = result.data['ends_at'];
      final ends = value is String ? DateTime.tryParse(value)?.toLocal() : null;
      if (active is! bool || (active && ends == null)) {
        throw const FormatException('Invalid membership status');
      }
      if (!mounted || request != _statusRequest) return;
      MembershipStatus.instance.apply(store.userID, active ? ends : null);
      setState(() {
        endsAt = active ? ends : null;
        _membershipPlanCode = active && result.data['plan_code'] is String
            ? result.data['plan_code'] as String
            : null;
        _aiPacks = _AIPack.parseAll(result.data['ai_packs']);
        _aiAddon = _AIAddonBalance.parse(result.data['ai_addon']);
        _membershipLoaded = true;
        _membershipLoading = false;
      });
      _membershipExpiryTimer?.cancel();
      // Refresh when the membership or any pack ends, since its uses vanish then.
      final changes = [?endsAt, for (final pack in _aiPacks) pack.endsAt]
        ..sort();
      if (changes.firstOrNull case final expiry?
          when expiry.isAfter(DateTime.now())) {
        _membershipExpiryTimer = Timer(expiry.difference(DateTime.now()), () {
          if (!mounted) return;
          setState(() {});
          unawaited(_loadStatus());
        });
      }
    } catch (_) {
      if (!mounted || request != _statusRequest) return;
      // 刷新失败保留上次有效结果，不能把网络错误当作未开通。
      setState(() => _membershipLoading = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_loadStatus());
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
    WidgetsBinding.instance.removeObserver(this);
    _membershipExpiryTimer?.cancel();
    appleProducts?.removeListener(_productsChanged);
    appleProducts?.dispose();
    applePurchases?.removeListener(_purchasesChanged);
    super.dispose();
  }

  /// 加购价格来自服务端；读取失败时不展示加购入口。
  Future<void> _loadAddonOffers() async {
    try {
      final result = await store.request('GetMembershipPlans');
      if (!mounted) return;
      setState(
        () => _addonOffers = AIAddonOffer.parseAll(result.data['ai_addons']),
      );
    } catch (_) {}
  }

  Future<void> _openAddonCheckout(AIAddonOffer offer) async {
    await openPage<bool>(
      context,
      appleProducts != null
          ? _AppleAIAddonCheckoutPage(
              offer: offer,
              products: appleProducts!,
              purchases: applePurchases!,
            )
          : AIAddonCheckoutPage(store: store, offer: offer),
    );
    if (mounted) await _loadStatus();
  }

  Future<void> _openCheckout() async {
    await openPage<void>(
      context,
      appleProducts != null
          ? _AppleMembershipCheckoutPage(
              plan: selected,
              products: appleProducts!,
              purchases: applePurchases!,
            )
          : MembershipCheckoutPage(store: store, plan: selected),
    );
    if (mounted) await _loadStatus();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _MembershipColors.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: appSystemUiStyle(context)
          .copyWith(systemNavigationBarColor: palette.background),
      child: Scaffold(
        backgroundColor: palette.background,
        appBar: AppPageBar(
          title: Text(widget.embedded ? '会员' : '开通会员'),
          automaticallyImplyLeading: !widget.embedded,
          backgroundColor: palette.background,
          foregroundColor: palette.text,
          actions: [
            Padding(
              // 去掉按钮自带内边距，使文字右缘与页面统一边距对齐
              padding: const EdgeInsets.only(right: appPageHorizontalPadding),
              child: TextButton.icon(
                onPressed: () async {
                  await openPage<void>(
                    context,
                    MembershipWalletPage(store: store),
                  );
                  if (mounted) await _loadStatus();
                },
                style: TextButton.styleFrom(
                  foregroundColor: palette.accent,
                  padding: const EdgeInsets.only(left: 8),
                  minimumSize: const Size(44, 44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedTicket01,
                  size: 18,
                  color: palette.accent,
                ),
                label: const Text('卡包'),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            _Header(
              store: store,
              membershipLabel: _membershipLabel,
              membershipBadgeAsset: _membershipBadgeAsset,
              endsAt: endsAt,
              aiPacks: _aiPacks,
              aiAddon: _aiAddon,
            ),
            if (endsAt != null && _addonOffers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                child: _AIAddonSection(
                  offers: _addonOffers,
                  balance: _aiAddon,
                  onBuy: _openAddonCheckout,
                  apple: appleProducts != null,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(child: _SectionTitle('选择套餐')),
                      TextButton(
                        onPressed: _openCheckout,
                        style: TextButton.styleFrom(
                          foregroundColor: palette.accent,
                          padding: const EdgeInsets.only(left: 12),
                          minimumSize: const Size(44, 44),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              endsAt == null ? '立即开通' : '立即续费',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(Icons.chevron_right_rounded, size: 19),
                          ],
                        ),
                      ),
                    ],
                  ),
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
                              recommended: plan.code == 'YEAR',
                              localizedPrice: appleProducts?.priceLabel(
                                plan.code,
                              ),
                              priceLoading:
                                  appleProducts?.loading == true &&
                                  !appleProducts!.available(plan.code),
                              onTap: () => setState(() => selected = plan),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (appleProducts?.error != null) ...[
                    const SizedBox(height: 10),
                    _AppleProductNotice(
                      products: appleProducts!,
                      membership: true,
                    ),
                  ],
                  if (applePurchases?.message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        applePurchases!.message!,
                        style: TextStyle(color: palette.accent, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            if (templates.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 32, 20, 14),
                child: _SectionTitle('会员专享模板'),
              ),
              _TemplateStrip(templates: templates),
            ],
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 32, 20, 28),
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
      ),
    );
  }
}

/// 邀请好友入口：好友注册并绑定手机号后，邀请人获得 3 天内可用的 AI 次数。
class _Header extends StatelessWidget {
  const _Header({
    required this.store,
    required this.membershipLabel,
    this.membershipBadgeAsset,
    this.endsAt,
    this.aiPacks = const [],
    this.aiAddon = const _AIAddonBalance(),
  });
  final AppStore store;
  final String membershipLabel;
  final String? membershipBadgeAsset;
  final DateTime? endsAt;
  final List<_AIPack> aiPacks;
  final _AIAddonBalance aiAddon;

  @override
  Widget build(BuildContext context) {
    final children = [
      // Only members carry the card; non-members go straight to the plans.
      if (endsAt != null)
        _MetalMembershipCard(
          store: store,
          membershipLabel: membershipLabel,
          membershipBadgeAsset: membershipBadgeAsset,
          endsAt: endsAt,
        ),
      if (aiPacks.isNotEmpty || !aiAddon.isEmpty) ...[
        if (endsAt != null) const SizedBox(height: 12),
        _AIUsageStrip(aiPacks, addon: aiAddon, member: endsAt != null),
      ],
    ];
    if (children.isEmpty) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(children: children),
    );
  }
}

class _MetalMembershipCard extends StatelessWidget {
  const _MetalMembershipCard({
    required this.store,
    required this.membershipLabel,
    this.membershipBadgeAsset,
    this.endsAt,
  });
  final AppStore store;
  final String membershipLabel;
  final String? membershipBadgeAsset;
  final DateTime? endsAt;

  /// ISO/IEC 7810 ID-1, the proportion of a real bank card.
  static const aspectRatio = 85.60 / 53.98;

  // Embossed lettering: a dark lower edge and a faint upper highlight.
  static const _emboss = [
    Shadow(color: Color(0xA6000000), offset: Offset(0, 1), blurRadius: 1),
    Shadow(color: Color(0x30FFFFFF), offset: Offset(0, -.6)),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final height = width / aspectRatio;
      // Everything on the card scales with it, like print on a real card.
      final k = (width / 335).clamp(.8, 1.25).toDouble();
      final radius = width * .045;
      final inset = 20 * k;
      final ends = endsAt;
      final name = store.name.isEmpty ? '博简用户' : store.name;
      return MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.15,
        child: Semantics(
          container: true,
          label: [
            membershipLabel,
            name,
            if (ends != null)
              '有效期至 ${ends.year}-${_two(ends.month)}-${_two(ends.day)}',
          ].join('，'),
          excludeSemantics: true,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: const [
                // Contact shadow plus a soft ambient lift.
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 3,
                  offset: Offset(0, 1.5),
                ),
                BoxShadow(
                  color: Color(0x4D0B1626),
                  blurRadius: 28,
                  spreadRadius: -6,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF3A4D68),
                            Color(0xFF233249),
                            Color(0xFF162234),
                            Color(0xFF1E2D42),
                          ],
                          stops: [0, .38, .78, 1],
                        ),
                      ),
                    ),
                  ),
                  const Positioned.fill(
                    child: CustomPaint(painter: _BrushedMetal()),
                  ),
                  Positioned.fill(
                    child: CustomPaint(painter: _CardSheen(radius: radius)),
                  ),
                  // One left edge for chip, number and holder, like the
                  // print grid of a real card.
                  Positioned(
                    left: inset,
                    top: height * .2,
                    width: 50 * k,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(7 * k),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x59000000),
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/membership/card_chip.png',
                        fit: BoxFit.contain,
                        cacheWidth: 240,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                  Positioned(
                    left: inset,
                    top: height * .53,
                    child: Text(
                      _decorativeCardNumber(profileAvatarSeed(store)),
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontSize: 15 * k,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.6 * k,
                        color: const Color(0xFFDCE6F3),
                        fontFeatures: const [FontFeature.tabularFigures()],
                        shadows: _emboss,
                      ),
                    ),
                  ),
                  Positioned(
                    left: inset,
                    right: inset,
                    bottom: inset * .85,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0x66C5D8F0),
                              width: 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(1.5),
                            child: ProfileAvatar(
                              seed: profileAvatarSeed(store),
                              url: store.avatarURL,
                              size: 32 * k,
                              borderRadius: 16 * k,
                            ),
                          ),
                        ),
                        SizedBox(width: 9 * k),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14 * k,
                                  height: 1.25,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                  color: const Color(0xFFE4ECF7),
                                  shadows: _emboss,
                                ),
                              ),
                              SizedBox(height: 3 * k),
                              if (membershipBadgeAsset != null)
                                Image.asset(
                                  membershipBadgeAsset!,
                                  height: 17 * k,
                                  fit: BoxFit.contain,
                                  cacheHeight: 96,
                                )
                              else
                                Text(
                                  membershipLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10 * k,
                                    height: 1.3,
                                    letterSpacing: 1,
                                    color: const Color(0xFF9FB2CC),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (ends != null) ...[
                          SizedBox(width: 10 * k),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '有效期至',
                                style: TextStyle(
                                  fontSize: 9 * k,
                                  height: 1.2,
                                  letterSpacing: 1.5,
                                  color: const Color(0xFF8DA1BC),
                                ),
                              ),
                              SizedBox(height: 2 * k),
                              Text(
                                '${ends.year}/${_two(ends.month)}/${_two(ends.day)}',
                                style: TextStyle(
                                  fontSize: 15 * k,
                                  height: 1.2,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.5,
                                  color: const Color(0xFFE4ECF7),
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                  shadows: _emboss,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// A stable, purely decorative card number derived from the account, shown
/// in the 4 × 4 grouping of a real card. It is not an identifier.
String _decorativeCardNumber(String seed) {
  var hash = 0x811C9DC5;
  final digits = StringBuffer();
  for (var i = 0; digits.length < 16; i++) {
    for (final unit in '$seed#$i'.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
    }
    digits.write(hash % 10);
  }
  final text = digits.toString();
  return [for (var i = 0; i < 16; i += 4) text.substring(i, i + 4)].join(' ');
}

/// The remaining AI uses sit below the card, not printed on it.
class _AIUsageStrip extends StatelessWidget {
  const _AIUsageStrip(
    this.packs, {
    this.addon = const _AIAddonBalance(),
    this.member = true,
  });
  final List<_AIPack> packs;
  final _AIAddonBalance addon;
  final bool member;

  @override
  Widget build(BuildContext context) {
    final palette = _MembershipColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surfaceHi,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        [
          ..._aiUsageLines(packs),
          ?_aiAddonLine(addon, member: member),
        ].join('\n'),
        style: TextStyle(fontSize: 12, height: 1.5, color: palette.muted),
      ),
    );
  }
}

/// Fine horizontal grain of brushed metal, deterministic so it never flickers.
class _BrushedMetal extends CustomPainter {
  const _BrushedMetal();

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(7);
    final paint = Paint()..strokeWidth = .5;
    for (var y = 0.0; y < size.height; y += .9) {
      final light = random.nextBool();
      paint.color = (light ? Colors.white : Colors.black).withValues(
        alpha: .012 + random.nextDouble() * (light ? .03 : .05),
      );
      final start = random.nextDouble() * size.width * .3;
      canvas.drawLine(
        Offset(start, y),
        Offset(size.width - random.nextDouble() * size.width * .3, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BrushedMetal oldDelegate) => false;
}

/// A bevelled edge that catches light on top.
class _CardSheen extends CustomPainter {
  const _CardSheen({required this.radius});
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final edge = RRect.fromRectAndRadius(
      rect.deflate(.6),
      Radius.circular(radius),
    );
    canvas.drawRRect(
      edge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x66E4EEFA), Color(0x14E4EEFA), Color(0x33000000)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _CardSheen oldDelegate) =>
      radius != oldDelegate.radius;
}

/// 生效中的一份会员或邀请奖励。次数只在这一份的有效期内可用，到期清零。
String _two(int value) => value.toString().padLeft(2, '0');

class _AIPack {
  const _AIPack({
    required this.referral,
    required this.endsAt,
    required this.create,
    required this.polish,
    required this.text,
  });
  final bool referral;
  final DateTime endsAt;
  final int create, polish, text;

  /// 服务端已按到期时间升序返回；格式不对的项直接忽略。
  static List<_AIPack> parseAll(Object? value) {
    final packs = <_AIPack>[];
    if (value is! List) return packs;
    for (final item in value) {
      if (item is! Map) continue;
      final ends = DateTime.tryParse('${item['ends_at']}')?.toLocal();
      if (ends == null) continue;
      packs.add(
        _AIPack(
          referral: item['source'] == 'REFERRAL',
          endsAt: ends,
          create: _count(item['ai_create_remaining']),
          polish: _count(item['ai_polish_remaining']),
          text: _count(item['ai_text_remaining']),
        ),
      );
    }
    return packs;
  }
}

int _count(Object? value) => value is num && value > 0 ? value.toInt() : 0;

/// 剩余次数合计，以及最早一份的清零时间（扣减也先扣这一份）。
List<String> _aiUsageLines(List<_AIPack> packs) {
  if (packs.isEmpty) return const [];
  final create = packs.fold(0, (sum, pack) => sum + pack.create);
  final polish = packs.fold(0, (sum, pack) => sum + pack.polish);
  final text = packs.fold(0, (sum, pack) => sum + pack.text);
  final first = packs.first;
  final label = first.referral ? '邀请奖励' : (packs.length > 1 ? '最早一份' : '本份');
  final at = first.endsAt;
  return [
    'AI 剩余：简历生成 $create 次 · 简历优化 $polish 次 · 单段 $text 次',
    '$label ${_two(at.month)}-${_two(at.day)} ${_two(at.hour)}:${_two(at.minute)} 到期清零',
  ];
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: _MembershipColors.of(context).text,
    ),
  );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
    this.recommended = false,
    this.localizedPrice,
    this.priceLoading = false,
  });
  final MembershipPlan plan;
  final bool selected, priceLoading, recommended;
  final VoidCallback onTap;
  final String? localizedPrice;

  @override
  Widget build(BuildContext context) {
    final colors = _MembershipColors.of(context);
    final accent = colors.accent;
    final titleColor = context.isDark
        ? selected
              ? const Color(0xFFEFF5FF)
              : const Color(0xFFD2DFF1)
        : colors.text;
    return Semantics(
      selected: selected,
      button: true,
      onTap: onTap,
      label:
          '${plan.title}，${recommended ? '推荐，' : ''}有效期 ${plan.period}，含 AI 简历生成 ${plan.aiCreateQuota} 次、AI 简历优化 ${plan.aiPolishQuota} 次、单段生成 ${plan.aiTextQuota} 次，${priceLoading ? '价格加载中' : localizedPrice ?? '${plan.price} 元'}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 108),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected ? colors.selectedPlan : colors.unselectedPlan,
          ),
          border: Border.all(
            color: selected ? colors.selectedBorder : colors.unselectedBorder,
            width: 1.1,
          ),
        ),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(18),
                splashColor: accent.withValues(alpha: .1),
                highlightColor: accent.withValues(alpha: .04),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 12, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: priceLoading
                                  ? _BreathingPricePlaceholder(
                                      fontSize: 24,
                                      color: accent,
                                    )
                                  : Text(
                                      localizedPrice ?? '¥${plan.price}',
                                      style: TextStyle(
                                        fontSize: 24,
                                        height: 1.1,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -.5,
                                        color: selected ? accent : titleColor,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _PlanRadio(selected: selected),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (recommended)
              const Positioned(top: 0, right: 0, child: _PlanBadge()),
          ],
        ),
      ),
    );
  }
}

/// 卡片右下角的单选圈，选中时显示对勾。
class _PlanRadio extends StatelessWidget {
  const _PlanRadio({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = _MembershipColors.of(context);
    final accent = colors.accent;
    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? accent : Colors.transparent,
          border: Border.all(
            color: selected
                ? accent
                : context.isDark
                ? const Color(0xFF647E9E)
                : colors.muted.withValues(alpha: .7),
            width: 1.4,
          ),
        ),
        child: selected
            ? Icon(Icons.check_rounded, size: 13, color: colors.accentInk)
            : null,
      ),
    );
  }
}

/// 贴在卡片右上角的“推荐”标签，外侧圆角与卡片一致。
class _PlanBadge extends StatelessWidget {
  const _PlanBadge();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF3DDA8), Color(0xFFD9A864)],
            ),
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(17),
              bottomLeft: Radius.circular(14),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                size: 14,
                color: Color(0xFFD62F1F),
              ),
              SizedBox(width: 3),
              Text(
                '推荐',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF9B2416),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BreathingPricePlaceholder extends StatefulWidget {
  const _BreathingPricePlaceholder({this.fontSize = 30, this.color});
  final double fontSize;
  final Color? color;

  @override
  State<_BreathingPricePlaceholder> createState() =>
      _BreathingPricePlaceholderState();
}

class _BreathingPricePlaceholderState extends State<_BreathingPricePlaceholder>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final _opacity = Tween<double>(
    begin: .35,
    end: .75,
  ).chain(CurveTween(curve: Curves.easeInOut)).animate(_controller);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = .5;
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
  Widget build(BuildContext context) {
    final height =
        MediaQuery.textScalerOf(context).scale(widget.fontSize) * 1.1;
    return Semantics(
      label: '正在获取 App Store 价格',
      child: RepaintBoundary(
        child: FadeTransition(
          opacity: _opacity,
          child: SizedBox(
            width: widget.fontSize * 3.2,
            height: height,
            child: Center(
              child: Container(
                height: height * .6,
                decoration: BoxDecoration(
                  color: widget.color ?? _MembershipColors.of(context).accent,
                  borderRadius: BorderRadius.circular(6),
                ),
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
        padding: const EdgeInsets.symmetric(horizontal: 20),
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
                              gradient: _crystalGradient,
                              borderRadius: const BorderRadius.only(
                                bottomRight: Radius.circular(8),
                              ),
                            ),
                            child: const Text(
                              '会员免费',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _platinumInk,
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
                  style: TextStyle(
                    fontSize: 12,
                    color: _MembershipColors.of(context).text,
                  ),
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
    final palette = _MembershipColors.of(context);
    final memberTint = context.isDark
        ? const Color(0x1FA3C7F3)
        : const Color(0xFFEAF3FF);
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
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                cell(
                  Text(
                    '特权',
                    style: TextStyle(fontSize: 12, color: palette.muted),
                  ),
                  flex: 5,
                ),
                cell(
                  Text(
                    '免费用户',
                    style: TextStyle(fontSize: 12, color: palette.muted),
                  ),
                ),
                cell(
                  Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedCrown,
                        size: 14,
                        color: palette.accent,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '会员',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: palette.accent,
                          ),
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
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: palette.line)),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    cell(
                      Row(
                        children: [
                          HugeIcon(icon: icon, size: 18, color: palette.accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: palette.text,
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
                        style: TextStyle(fontSize: 12, color: palette.muted),
                      ),
                    ),
                    cell(
                      Text(
                        member,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: palette.accent,
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
    final palette = _MembershipColors.of(context);
    return Material(
      clipBehavior: Clip.antiAlias,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: palette.line),
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
                      : Border(top: BorderSide(color: palette.line)),
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  iconColor: palette.accent,
                  collapsedIconColor: palette.muted,
                  title: Text(
                    question,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: palette.text,
                    ),
                  ),
                  children: [
                    Text(
                      answer,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: palette.muted,
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

/// 确认订单页底部结算栏。
class _BottomPayBar extends StatelessWidget {
  const _BottomPayBar({
    required this.label,
    required this.amount,
    this.displayAmount,
    required this.onPressed,
    this.busy = false,
  });
  final String label, amount;
  final String? displayAmount;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final inactive = busy || onPressed == null;
    const onButton = Colors.white;
    final buttonRadius = BorderRadius.circular(23);
    final amountWidget = Text(
      displayAmount ?? '¥$amount',
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: colors.accent,
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: amountWidget,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 46,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: buttonRadius,
                    gradient: inactive
                        ? LinearGradient(colors: [colors.muted, colors.muted])
                        : const LinearGradient(colors: _blueGradient),
                    boxShadow: inactive
                        ? null
                        : const [
                            BoxShadow(
                              color: Color(0x402867EE),
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
                      shape: RoundedRectangleBorder(borderRadius: buttonRadius),
                    ),
                    child: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: onButton,
                            ),
                          )
                        : Text(
                            label,
                            style: const TextStyle(
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

  /// 适用于本套餐的可用券；默认选中抵扣最多的一张。
  List<WalletCoupon> coupons = const [];
  WalletCoupon? coupon;

  int get discountCents => coupon?.discountFor(widget.plan) ?? 0;
  int get payableCents => widget.plan.amountCents - discountCents;

  @override
  void initState() {
    super.initState();
    _loadChannels();
    _loadCoupons();
  }

  Future<void> _loadCoupons() async {
    try {
      final wallet = await MembershipWallet.load(widget.store);
      if (!mounted) return;
      setState(() {
        coupons = wallet.coupons
            .where((c) => c.usable && c.appliesTo(widget.plan.code))
            .toList();
        coupon = wallet.bestFor(widget.plan);
        requestKey = null;
      });
    } catch (_) {
      // 卡包读取失败时按原价下单。
    }
  }

  Future<void> _chooseCoupon() async {
    final picked = await _pickCoupon(context, coupons, coupon?.id);
    if (picked == null || !mounted) return;
    setState(() {
      coupon = picked == 0 ? null : coupons.firstWhere((c) => c.id == picked);
      // 换券即换订单内容，需要新的幂等键。
      requestKey = null;
    });
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

  static const _alipay = MethodChannel('cn.kelance.bojian/alipay');

  /// 支付宝通知通常在几秒内到达，期间轮询订单状态；返回最后一次查到的订单。
  Future<Map<String, dynamic>> _waitUntilPaid(
    Map<String, dynamic> order,
  ) async {
    final id = integer(order['id']);
    if (id <= 0) return order;
    for (var attempt = 0; attempt < 8; attempt++) {
      try {
        final result = await widget.store.request(
          'GetMembershipOrdersId',
          path: {'id': '$id'},
        );
        order = result.data;
        if (order['status'] == 'PAID') return order;
      } on ApiFailure {
        // 网络抖动时继续等待下一次查询。
      }
      if (!mounted) return order;
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return order;
    }
    return order;
  }

  /// 用结果页替换确认订单页，返回时直接回到会员页。
  void _showResult(Map<String, dynamic> order) {
    Navigator.of(context).pushReplacement(
      CupertinoPageRoute<void>(
        builder: (_) => MembershipOrderResultPage(
          store: widget.store,
          plan: widget.plan,
          order: order,
        ),
      ),
    );
  }

  Future<void> _pay() async {
    if (paying) return;
    requestKey ??=
        'mobile-membership-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    setState(() => paying = true);
    try {
      final order = await widget.store.request(
        'PostMembershipOrders',
        body: {
          'plan_code': widget.plan.code,
          'channel': channel,
          'coupon_id': ?coupon?.id,
        },
        extra: {'idempotency-key': requestKey!},
      );
      if (!mounted) return;
      if (order.data['status'] == 'PAID') return _showResult(order.data);
      final orderString = order.data['alipay_order_string'];
      if (channel != 'ALIPAY' ||
          orderString is! String ||
          orderString.isEmpty) {
        toast(context, '${_channelName(channel)}暂未开放，请稍后再试');
        return;
      }
      final outcome = await _alipay.invokeMapMethod<String, String>('pay', {
        'orderString': orderString,
      });
      if (!mounted) return;
      final status = outcome?['resultStatus'];
      if (status == '6001') {
        toast(context, '已取消支付');
        return;
      }
      // 支付宝同步结果仅作提示，会员是否开通以服务端验签后的订单状态为准。
      final latest = await _waitUntilPaid(order.data);
      if (!mounted) return;
      // 已开通，或支付宝显示已付款（9000 成功、8000 处理中）时进入结果页继续确认。
      if (latest['status'] == 'PAID' || status == '9000' || status == '8000') {
        return _showResult(latest);
      }
      toast(context, '支付未完成，请重试');
    } on PlatformException catch (e) {
      if (mounted) toast(context, e.message ?? '无法打开支付宝，请重试');
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
                _CouponLine(
                  discountCents: discountCents,
                  available: coupons.length,
                  onTap: paying || coupons.isEmpty ? null : _chooseCoupon,
                ),
                _OrderLine(
                  '实付金额',
                  '¥${(payableCents / 100).toStringAsFixed(2)}',
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
        amount: (payableCents / 100).toStringAsFixed(2),
        busy: paying,
        onPressed: _pay,
      ),
    );
  }
}

String _channelName(String channel) => channel == 'WECHAT' ? '微信支付' : '支付宝';

/// 订单商品缩略图：冷黑底上斜放一张迷你铂银会员卡，标明年卡或月卡。
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
        colors: [Color(0xFF243B5B), _bg],
      ),
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        const Positioned(
          right: 5,
          top: 4,
          child: Text('✦', style: TextStyle(fontSize: 8, color: _platinum)),
        ),
        Transform.rotate(
          angle: -.2,
          child: Container(
            width: 34,
            height: 23,
            padding: const EdgeInsets.fromLTRB(4, 3, 4, 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: _crystalGradient,
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
                  color: _platinumInk,
                  strokeWidth: 2,
                ),
                Text(
                  plan.title,
                  style: const TextStyle(
                    fontSize: 7,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: _platinumInk,
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

class _CouponLine extends StatelessWidget {
  const _CouponLine({
    required this.discountCents,
    required this.available,
    required this.onTap,
  });
  final int discountCents, available;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final value = discountCents > 0
        ? '-¥${(discountCents / 100).toStringAsFixed(2)}'
        : available > 0
        ? '$available 张可用'
        : '无可用优惠券';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Text('优惠券', style: TextStyle(fontSize: 13, color: colors.muted)),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: discountCents > 0 ? colors.accent : colors.muted,
                fontWeight: discountCents > 0 ? FontWeight.w600 : null,
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, size: 18, color: colors.muted),
          ],
        ),
      ),
    );
  }
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

/// iOS 允许查看套餐，实际购买由独立的 App Store 页面控制。
bool get membershipPageAvailable =>
    defaultTargetPlatform == TargetPlatform.android || usesAppleMembership;

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
  final purchasable = membershipPageAvailable;
  final open = await showAppConfirmation(
    context,
    title: '会员专享',
    content: Text(error.message),
    confirmLabel: purchasable
        ? usesAppleMembership
              ? '查看会员'
              : '开通会员'
        : '知道了',
    cancelLabel: purchasable ? '暂不' : null,
  );
  if (open == true && purchasable && context.mounted) {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => MembershipPage(store: store)),
    );
  }
  return true;
}
