part of 'membership_page.dart';

/// 卡包里的立减券。金额以服务端为准，下单时再校验一次。
class WalletCoupon {
  const WalletCoupon({
    required this.id,
    required this.title,
    required this.amountCents,
    required this.planCode,
    required this.expiresAt,
    required this.status,
  });

  factory WalletCoupon.fromJson(Map json) => WalletCoupon(
    id: integer(json['id']),
    title: '${json['title'] ?? '会员立减券'}',
    amountCents: integer(json['amount_cents']),
    planCode: json['plan_code'] as String?,
    expiresAt: DateTime.tryParse('${json['expires_at']}')?.toLocal(),
    status: '${json['status']}',
  );

  final int id, amountCents;
  final String title, status;
  final String? planCode;
  final DateTime? expiresAt;

  bool get usable => status == 'AVAILABLE';
  bool appliesTo(String plan) => planCode == null || planCode == plan;

  /// 支付渠道不接受 0 元，抵扣后至少支付 0.01 元。
  int discountFor(MembershipPlan plan) =>
      min(amountCents, plan.amountCents - 1);

  String get scope => switch (planCode) {
    'MONTH' => '仅限月卡',
    'YEAR' => '仅限年卡',
    _ => '月卡、年卡通用',
  };
}

class WalletCard {
  const WalletCard({
    required this.id,
    required this.planCode,
    required this.expiresAt,
    required this.status,
    required this.membershipEndsAt,
  });

  factory WalletCard.fromJson(Map json) => WalletCard(
    id: integer(json['id']),
    planCode: '${json['plan_code']}',
    expiresAt: DateTime.tryParse('${json['expires_at']}')?.toLocal(),
    status: '${json['status']}',
    membershipEndsAt: DateTime.tryParse('${json['membership_ends_at']}')
        ?.toLocal(),
  );

  final int id;
  final String planCode, status;
  final DateTime? expiresAt, membershipEndsAt;

  MembershipPlan get plan => membershipPlans.firstWhere(
    (plan) => plan.code == planCode,
    orElse: () => membershipPlans.last,
  );
}

class MembershipWallet {
  const MembershipWallet({required this.coupons, required this.cards});
  final List<WalletCoupon> coupons;
  final List<WalletCard> cards;

  static Future<MembershipWallet> load(AppStore store) async {
    final result = await store.request('GetMembershipWallet');
    List<T> items<T>(String key, T Function(Map) parse) =>
        (result.data[key] as List? ?? []).whereType<Map>().map(parse).toList();
    return MembershipWallet(
      coupons: items('coupons', WalletCoupon.fromJson),
      cards: items('cards', WalletCard.fromJson),
    );
  }

  /// 下单页默认选中抵扣最多的可用券。
  WalletCoupon? bestFor(MembershipPlan plan) {
    WalletCoupon? best;
    for (final coupon in coupons) {
      if (!coupon.usable || !coupon.appliesTo(plan.code)) continue;
      if (best == null || coupon.discountFor(plan) > best.discountFor(plan)) {
        best = coupon;
      }
    }
    return best;
  }
}

String _day(DateTime? value) => value == null
    ? '-'
    : '${value.year}-${_two(value.month)}-${_two(value.day)}';

String _yuan(int cents) =>
    (cents / 100).toStringAsFixed(cents % 100 == 0 ? 0 : 2);

/// 卡包：后台下发的会员立减券和月卡/年卡。
class MembershipWalletPage extends StatefulWidget {
  const MembershipWalletPage({super.key, required this.store});
  final AppStore store;

  @override
  State<MembershipWalletPage> createState() => _MembershipWalletPageState();
}

class _MembershipWalletPageState extends State<MembershipWalletPage> {
  MembershipWallet? wallet;
  String? error;
  int? using;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final next = await MembershipWallet.load(widget.store);
      if (!mounted) return;
      setState(() {
        wallet = next;
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> _use(WalletCard card) async {
    final confirmed = await showAppConfirmation(
      context,
      title: '使用${card.plan.orderName}',
      content: Text(
        '使用后从现在起开通 ${card.plan.period} 会员，并一次性发放 AI 简历生成 ${card.plan.aiCreateQuota} 次、AI 简历优化 ${card.plan.aiPolishQuota} 次、单段 ${card.plan.aiTextQuota} 次，到期清零；不会在已有会员到期后顺延。',
      ),
      confirmLabel: '立即使用',
    );
    if (confirmed != true || !mounted) return;
    setState(() => using = card.id);
    try {
      final result = await widget.store.request(
        'PostMembershipCardsIdUse',
        path: {'id': '${card.id}'},
      );
      if (!mounted) return;
      final membership = result.data['membership'];
      final ends = membership is Map
          ? DateTime.tryParse('${membership['ends_at']}')?.toLocal()
          : null;
      toast(context, '会员已开通，有效期至 ${_day(ends)}');
      await _load();
    } on ApiFailure catch (e) {
      if (mounted) toast(context, e.message);
      await _load();
    } finally {
      if (mounted) setState(() => using = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final wallet = this.wallet;
    // iOS 会员由 App Store 计费，不能叠加优惠券，只展示会员卡。
    final showCoupons = !usesAppleMembership;
    return DefaultTabController(
      length: showCoupons ? 2 : 1,
      child: Scaffold(
        backgroundColor: colors.canvas,
        appBar: AppPageBar(
          title: const Text('我的卡包'),
          backgroundColor: colors.canvas,
          bottom: !showCoupons
              ? null
              : TabBar(
                  labelColor: colors.accent,
                  unselectedLabelColor: colors.muted,
                  indicatorColor: colors.accent,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(
                      text:
                          '优惠券${_count(wallet?.coupons.where((c) => c.usable))}',
                    ),
                    Tab(
                      text:
                          '会员卡${_count(wallet?.cards.where((c) => c.status == 'AVAILABLE'))}',
                    ),
                  ],
                ),
        ),
        body: wallet == null
            ? Center(
                child: error == null
                    ? const CircularProgressIndicator()
                    : TextButton(
                        onPressed: _load,
                        child: const Text('加载失败，点击重试'),
                      ),
              )
            : TabBarView(
                children: [
                  if (showCoupons)
                    _WalletList(
                      onRefresh: _load,
                      empty: '暂无优惠券',
                      children: [
                        for (final coupon in wallet.coupons)
                          _CouponTile(coupon: coupon),
                      ],
                    ),
                  _WalletList(
                    onRefresh: _load,
                    empty: '暂无会员卡',
                    children: [
                      for (final card in wallet.cards)
                        _MembershipCardTile(
                          card: card,
                          busy: using == card.id,
                          onUse: using == null ? () => _use(card) : null,
                        ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  String _count(Iterable<Object>? usable) {
    final count = usable?.length ?? 0;
    return count == 0 ? '' : ' $count';
  }
}

class _WalletList extends StatelessWidget {
  const _WalletList({
    required this.onRefresh,
    required this.empty,
    required this.children,
  });
  final Future<void> Function() onRefresh;
  final String empty;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: children.isEmpty
        ? ListView(
            children: [
              const SizedBox(height: 160),
              Center(
                child: Text(
                  empty,
                  style: TextStyle(fontSize: 14, color: context.colors.muted),
                ),
              ),
            ],
          )
        : ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: children.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, index) => children[index],
          ),
  );
}

String _walletStatus(String status) => switch (status) {
  'USED' => '已使用',
  'EXPIRED' => '已过期',
  _ => '',
};

class _CouponTile extends StatelessWidget {
  const _CouponTile({required this.coupon, this.selected, this.onTap});
  final WalletCoupon coupon;

  /// 下单页选择券时显示选中状态；卡包里为 null。
  final bool? selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final active = coupon.usable;
    final tone = active ? colors.accent : colors.muted;
    return Opacity(
      opacity: active ? 1 : .55,
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 96,
                  color: tone.withValues(alpha: .08),
                  alignment: Alignment.center,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: '¥',
                          style: TextStyle(fontSize: 14),
                        ),
                        TextSpan(text: _yuan(coupon.amountCents)),
                      ],
                    ),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: tone,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          coupon.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colors.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '开通会员立减 · ${coupon.scope}',
                          style: TextStyle(fontSize: 12, color: colors.muted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '有效期至 ${_day(coupon.expiresAt)}',
                          style: TextStyle(fontSize: 12, color: colors.muted),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Center(
                    child: selected != null
                        ? Icon(
                            selected!
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 22,
                            color: selected! ? colors.accent : colors.border,
                          )
                        : Text(
                            _walletStatus(coupon.status),
                            style: TextStyle(fontSize: 12, color: colors.muted),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MembershipCardTile extends StatelessWidget {
  const _MembershipCardTile({
    required this.card,
    required this.busy,
    required this.onUse,
  });
  final WalletCard card;
  final bool busy;
  final VoidCallback? onUse;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final available = card.status == 'AVAILABLE';
    final plan = card.plan;
    return Opacity(
      opacity: available ? 1 : .55,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _PlanThumb(plan: plan),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.orderName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.status == 'USED'
                        ? '已使用 · 会员有效期至 ${_day(card.membershipEndsAt)}'
                        : '会员 ${plan.period} · ${_day(card.expiresAt)} 前使用',
                    style: TextStyle(fontSize: 12, color: colors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (available)
              SizedBox(
                height: 32,
                child: FilledButton(
                  onPressed: onUse,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: busy
                      ? const SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('立即使用'),
                ),
              )
            else
              Text(
                _walletStatus(card.status),
                style: TextStyle(fontSize: 12, color: colors.muted),
              ),
          ],
        ),
      ),
    );
  }
}

/// 下单页选择优惠券。返回 0 表示不使用优惠券，null 表示未改动。
Future<int?> _pickCoupon(
  BuildContext context,
  List<WalletCoupon> coupons,
  int? selectedId,
) => showPanelSheet<int>(
  context,
  builder: (context) => PanelSheet(
    title: '选择优惠券',
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .6,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 12),
        children: [
          for (final coupon in coupons) ...[
            _CouponTile(
              coupon: coupon,
              selected: coupon.id == selectedId,
              onTap: () => Navigator.pop(context, coupon.id),
            ),
            const SizedBox(height: 10),
          ],
          TextButton(
            onPressed: () => Navigator.pop(context, 0),
            child: const Text('不使用优惠券'),
          ),
        ],
      ),
    ),
  ),
);
