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

  int discountFor(MembershipPlan plan) => min(amountCents, plan.amountCents);

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

  Future<void> _useCoupon(WalletCoupon coupon) async {
    final plans = membershipPlans
        .where((p) => coupon.appliesTo(p.code))
        .toList();
    if (plans.isEmpty) return;
    final plan = plans.length == 1
        ? plans.first
        : await showPanelSheet<MembershipPlan>(
            context,
            builder: (context) => PanelSheet(
              title: '选择使用套餐',
              child: ListView(
                children: [
                  for (final p in plans)
                    ListTile(
                      title: Text(p.orderName),
                      trailing: Text('¥${p.price}'),
                      onTap: () => Navigator.pop(context, p),
                    ),
                ],
              ),
            ),
          );
    if (!mounted || plan == null) return;
    await openPage<void>(
      context,
      MembershipCheckoutPage(
        store: widget.store,
        plan: plan,
        initialCoupon: coupon,
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final data = wallet;
    final showCoupons = !usesAppleMembership;
    return DefaultTabController(
      length: showCoupons ? 2 : 1,
      initialIndex: showCoupons ? 1 : 0,
      child: Scaffold(
        backgroundColor: c.canvas,
        appBar: AppBar(
          backgroundColor: c.canvas,
          foregroundColor: c.ink,
          centerTitle: true,
          scrolledUnderElevation: 0,
          title: showCoupons
              ? SizedBox(
                  width: 176,
                  child: TabBar(
                    labelColor: c.ink,
                    unselectedLabelColor: c.muted,
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.label,
                    indicatorColor: c.accent,
                    labelPadding: EdgeInsets.zero,
                    labelStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: const [
                      Tab(text: '会员卡'),
                      Tab(text: '优惠券'),
                    ],
                  ),
                )
              : const Text('会员卡'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: c.border),
          ),
        ),
        body: data == null
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
                  _WalletList(
                    cards: data.cards,
                    onUseCard: using == null ? _use : null,
                    onRefresh: _load,
                  ),
                  if (showCoupons)
                    _WalletList(
                      coupons: data.coupons,
                      onUseCoupon: _useCoupon,
                      onRefresh: _load,
                    ),
                ],
              ),
      ),
    );
  }
}

class _WalletList extends StatefulWidget {
  const _WalletList({
    this.cards,
    this.coupons,
    this.onUseCard,
    this.onUseCoupon,
    required this.onRefresh,
  });
  final List<WalletCard>? cards;
  final List<WalletCoupon>? coupons;
  final ValueChanged<WalletCard>? onUseCard;
  final ValueChanged<WalletCoupon>? onUseCoupon;
  final Future<void> Function() onRefresh;
  @override
  State<_WalletList> createState() => _WalletListState();
}

class _WalletListState extends State<_WalletList> {
  String filter = '全部';
  bool matches(String? code) =>
      filter == '全部' ||
      code == null ||
      code == (filter == '月卡适用' ? 'MONTH' : 'YEAR');

  String get rules => widget.cards != null
      ? '会员卡须在标注的期限内使用。确认后即开通对应时长的会员并发放 AI 次数，会员有效期从使用时起计算。'
      : '优惠券仅用于适用的会员套餐，每笔订单可使用一张。实际抵扣金额以确认订单页为准。';

  List<Widget> tickets({required bool history}) => [
    for (final card in widget.cards ?? const <WalletCard>[])
      if ((card.status != 'AVAILABLE') == history &&
          (history || matches(card.planCode)))
        _WalletTicket(
          key: ValueKey(card.id),
          face: card.planCode == 'YEAR' ? '年卡' : '月卡',
          caption: '会员卡',
          title: card.plan.orderName,
          date: card.status == 'USED'
              ? '会员有效期至 ${_day(card.membershipEndsAt)}'
              : '使用期限至 ${_day(card.expiresAt)}',
          rule: '开通 ${card.plan.period} 会员，并发放对应 AI 次数。',
          status: card.status,
          onUse: widget.onUseCard == null
              ? null
              : () => widget.onUseCard!(card),
        ),
    for (final coupon in widget.coupons ?? const <WalletCoupon>[])
      if (!coupon.usable == history && (history || matches(coupon.planCode)))
        _WalletTicket(
          key: ValueKey(coupon.id),
          face: '¥${_yuan(coupon.amountCents)}',
          caption: '会员立减',
          title: coupon.title,
          date: '有效期至 ${_day(coupon.expiresAt)}',
          rule: '${coupon.scope}。每单限用一张。',
          status: coupon.status,
          onUse: () => widget.onUseCoupon!(coupon),
        ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final visible = tickets(history: false);
    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    PopupMenuButton<String>(
                      tooltip: '筛选',
                      initialValue: filter,
                      onSelected: (v) => setState(() => filter = v),
                      itemBuilder: (_) => [
                        for (final name in ['全部', '月卡适用', '年卡适用'])
                          PopupMenuItem(value: name, child: Text(name)),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: c.inset,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '$filter（${visible.length}）',
                              style: TextStyle(color: c.ink, fontSize: 13),
                            ),
                            Icon(Icons.arrow_drop_down, size: 18, color: c.ink),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        final past = tickets(history: true);
                        openPage<void>(
                          context,
                          Scaffold(
                            backgroundColor: c.canvas,
                            appBar: const AppPageBar(title: Text('历史记录')),
                            body: SafeArea(
                              child: ListView(
                                padding: const EdgeInsets.all(16),
                                children: past.isEmpty
                                    ? [
                                        const SizedBox(height: 100),
                                        const Center(child: Text('暂无历史记录')),
                                      ]
                                    : past,
                              ),
                            ),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Text(
                            '历史记录',
                            style: TextStyle(color: c.muted, fontSize: 13),
                          ),
                          AppIcon(AppIcons.forward, size: 14, color: c.muted),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: widget.onRefresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: visible.isEmpty
                        ? [
                            const SizedBox(height: 100),
                            Center(
                              child: Text(
                                filter != '全部'
                                    ? '暂无符合条件的卡券'
                                    : widget.cards != null
                                    ? '暂无可用会员卡'
                                    : '暂无可用优惠券',
                                style: TextStyle(color: c.muted),
                              ),
                            ),
                          ]
                        : visible,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => showPanelSheet<void>(
                  context,
                  builder: (_) => PanelSheet(
                    title: '规则说明',
                    child: ListView(
                      children: [
                        Text(rules, style: const TextStyle(height: 1.7)),
                      ],
                    ),
                  ),
                ),
                child: const Text('规则说明'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletTicket extends StatefulWidget {
  const _WalletTicket({
    super.key,
    required this.face,
    required this.caption,
    required this.title,
    required this.date,
    required this.rule,
    required this.status,
    required this.onUse,
  });
  final String face, caption, title, date, rule, status;
  final VoidCallback? onUse;
  @override
  State<_WalletTicket> createState() => _WalletTicketState();
}

class _WalletTicketState extends State<_WalletTicket> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final active = widget.status == 'AVAILABLE';
    final tone = active ? c.accent : c.muted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: tone.withValues(alpha: .22)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.alphaBlend(tone.withValues(alpha: .11), c.surface),
                    Color.alphaBlend(tone.withValues(alpha: .05), c.surface),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: 85,
                    width: 8,
                    child: CustomPaint(
                      painter: _TicketSeam(
                        tone.withValues(alpha: .32),
                        c.canvas,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      SizedBox(
                        width: 85,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 12,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  widget.face,
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    color: tone,
                                  ),
                                ),
                              ),
                              Text(
                                widget.caption,
                                style: TextStyle(fontSize: 12, color: tone),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 12, 12, 12),
                          child: LayoutBuilder(
                            builder: (context, box) {
                              final details = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '最优简会员',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: c.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.title,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: c.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    widget.date,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: c.muted,
                                    ),
                                  ),
                                ],
                              );
                              final action = active
                                  ? FilledButton(
                                      onPressed: widget.onUse,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: c.palette.seed,
                                        minimumSize: const Size(56, 32),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        widget.caption == '会员卡'
                                            ? '立即使用'
                                            : '去使用',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    )
                                  : Text(
                                      _walletStatus(widget.status),
                                      style: TextStyle(
                                        color: c.muted,
                                        fontSize: 12,
                                      ),
                                    );
                              if (box.maxWidth <
                                  185 *
                                      MediaQuery.textScalerOf(context)
                                          .scale(1)) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [details, action],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(child: details),
                                  const SizedBox(width: 6),
                                  action,
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: () => setState(() => expanded = !expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '使用须知：${widget.rule}',
                        maxLines: expanded ? null : 1,
                        overflow: expanded ? null : TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: c.muted,
                        ),
                      ),
                    ),
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: c.muted,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketSeam extends CustomPainter {
  const _TicketSeam(this.line, this.cutout);
  final Color line, cutout;
  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final ink = Paint()..color = line;
    for (double y = 5; y < size.height - 4; y += 5) {
      canvas.drawLine(Offset(x, y), Offset(x, y + 2), ink);
    }
    ink.color = cutout;
    canvas.drawCircle(Offset(x, 0), x, ink);
    canvas.drawCircle(Offset(x, size.height), x, ink);
  }

  @override
  bool shouldRepaint(_TicketSeam old) =>
      old.line != line || old.cutout != cutout;
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
