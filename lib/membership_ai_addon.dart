part of 'membership_page.dart';

/// 会员按次加购的一种 AI 次数。单价以服务端 /membership/plans 为准。
class AIAddonOffer {
  const AIAddonOffer({
    required this.kind,
    required this.name,
    required this.unitPriceCents,
    required this.maxQuantity,
  });
  final String kind, name;
  final int unitPriceCents, maxQuantity;

  /// 快捷数量：单段单价低，档位放大十倍。
  List<int> get presets =>
      kind == 'TEXT' ? const [10, 50, 100, 200] : const [1, 5, 10, 20];

  String get unitPrice => _yuan(unitPriceCents);

  static List<AIAddonOffer> parseAll(Object? value) {
    final offers = <AIAddonOffer>[];
    if (value is! List) return offers;
    for (final item in value) {
      if (item is! Map) continue;
      final kind = item['kind'], name = item['name'];
      final price = item['unit_price_cents'], max = item['max_quantity'];
      if (kind is! String || name is! String || price is! num || max is! num) {
        continue;
      }
      if (price <= 0 || max < 1) continue;
      offers.add(
        AIAddonOffer(
          kind: kind,
          name: name,
          unitPriceCents: price.toInt(),
          maxQuantity: max.toInt(),
        ),
      );
    }
    return offers;
  }
}

/// 已加购、尚未用完的次数。没有到期日，只在会员有效期内可用。
class _AIAddonBalance {
  const _AIAddonBalance({this.create = 0, this.polish = 0, this.text = 0});
  final int create, polish, text;

  bool get isEmpty => create == 0 && polish == 0 && text == 0;

  static _AIAddonBalance parse(Object? value) => value is Map
      ? _AIAddonBalance(
          create: _count(value['ai_create_remaining']),
          polish: _count(value['ai_polish_remaining']),
          text: _count(value['ai_text_remaining']),
        )
      : const _AIAddonBalance();
}

/// 先选择次数类型，再复用各平台的数量选择与支付流程。
class _AIAddonPicker extends StatelessWidget {
  const _AIAddonPicker({required this.offers});
  final List<AIAddonOffer> offers;

  @override
  Widget build(BuildContext context) {
    final palette = _MembershipColors.of(context);
    return PanelSheet(
      title: '选择加购类型',
      child: ListView.separated(
        itemCount: offers.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final offer = offers[index];
          return Material(
            color: palette.surface,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              title: Text(
                offer.name,
                style: TextStyle(fontSize: 14, color: palette.text),
              ),
              trailing: Icon(Icons.chevron_right_rounded, color: palette.muted),
              onTap: () => Navigator.of(context).pop(offer),
            ),
          );
        },
      ),
    );
  }
}

/// 选择加购数量并支付。金额等于单价乘次数，以服务端订单为准。
class AIAddonCheckoutPage extends StatefulWidget {
  const AIAddonCheckoutPage({
    super.key,
    required this.store,
    required this.offer,
  });
  final AppStore store;
  final AIAddonOffer offer;

  @override
  State<AIAddonCheckoutPage> createState() => _AIAddonCheckoutPageState();
}

class _AIAddonCheckoutPageState extends State<AIAddonCheckoutPage> {
  late int quantity = widget.offer.presets[1];
  String channel = 'ALIPAY';
  Set<String> available = {'ALIPAY', 'WECHAT'};
  bool paying = false;

  /// 同一数量与渠道的重复点击复用幂等键，不会生成多笔订单。
  String? requestKey;

  AIAddonOffer get offer => widget.offer;
  int get amountCents => offer.unitPriceCents * quantity;

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
      // 保留默认渠道列表，由下单接口给出准确结果。
    }
  }

  void _setQuantity(int value) {
    final next = value.clamp(1, offer.maxQuantity);
    if (next == quantity) return;
    setState(() {
      quantity = next;
      requestKey = null;
    });
  }

  static const _alipay = MethodChannel('cn.kelance.bojian/alipay');

  Future<Map<String, dynamic>> _waitUntilPaid(
    Map<String, dynamic> order,
  ) async {
    final id = integer(order['id']);
    if (id <= 0) return order;
    for (var attempt = 0; attempt < 8; attempt++) {
      try {
        final result = await widget.store.request(
          'GetMembershipAiAddonOrdersId',
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

  Future<void> _pay() async {
    if (paying) return;
    requestKey ??=
        'mobile-ai-addon-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    setState(() => paying = true);
    try {
      final order = await widget.store.request(
        'PostMembershipAiAddonOrders',
        body: {'kind': offer.kind, 'quantity': quantity, 'channel': channel},
        extra: {'idempotency-key': requestKey!},
      );
      if (!mounted) return;
      if (order.data['status'] == 'PAID') return _done();
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
      // 次数是否到账以服务端验签后的订单状态为准。
      final latest = await _waitUntilPaid(order.data);
      if (!mounted) return;
      if (latest['status'] == 'PAID') return _done();
      toast(
        context,
        status == '9000' || status == '8000'
            ? '支付结果确认中，稍后在会员页查看次数'
            : '支付未完成，请重试',
      );
    } on PlatformException catch (e) {
      if (mounted) toast(context, e.message ?? '无法打开支付宝，请重试');
    } on ApiFailure catch (e) {
      if (!mounted) return;
      if (e.code == 'AI_ADDON_ORDER_EXPIRED' ||
          e.code == 'IDEMPOTENCY_CONFLICT') {
        requestKey = null;
      }
      toast(context, e.message);
    } finally {
      if (mounted) setState(() => paying = false);
    }
  }

  void _done() {
    toast(context, '已到账：${offer.name} $quantity 次');
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppPageBar(
        title: const Text('加购 AI 次数'),
        backgroundColor: colors.canvas,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        offer.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colors.ink,
                        ),
                      ),
                    ),
                    Text(
                      '¥${offer.unitPrice}/次',
                      style: TextStyle(fontSize: 14, color: colors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      '购买次数',
                      style: TextStyle(fontSize: 14, color: colors.ink),
                    ),
                    const Spacer(),
                    _StepButton(
                      icon: Icons.remove_rounded,
                      label: '减少',
                      onTap: paying || quantity <= 1
                          ? null
                          : () => _setQuantity(quantity - 1),
                    ),
                    SizedBox(
                      width: 56,
                      child: Text(
                        '$quantity',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colors.ink,
                        ),
                      ),
                    ),
                    _StepButton(
                      icon: Icons.add_rounded,
                      label: '增加',
                      onTap: paying || quantity >= offer.maxQuantity
                          ? null
                          : () => _setQuantity(quantity + 1),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final preset in offer.presets)
                      if (preset <= offer.maxQuantity)
                        ChoiceChip(
                          label: Text('$preset 次'),
                          selected: quantity == preset,
                          showCheckmark: false,
                          onSelected: paying
                              ? null
                              : (_) => _setQuantity(preset),
                        ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: colors.border),
                const SizedBox(height: 12),
                _OrderLine('实付金额', '¥${_fixed(amountCents)}', emphasize: true),
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
                          : () => setState(() {
                              channel = option;
                              requestKey = null;
                            }),
                    ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '加购次数为虚拟服务，支付成功后立即到账，不支持退款。次数不会过期，只在会员有效期内可用；会员到期后冻结，续费后恢复。',
            style: TextStyle(fontSize: 12, height: 1.5, color: colors.muted),
          ),
        ],
      ),
      bottomNavigationBar: _BottomPayBar(
        label: '立即支付',
        amount: _fixed(amountCents),
        busy: paying,
        onPressed: _pay,
      ),
    );
  }
}

String _fixed(int cents) => (cents / 100).toStringAsFixed(2);

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colors.border),
          ),
          child: Icon(
            icon,
            size: 20,
            color: onTap == null ? colors.muted : colors.accent,
          ),
        ),
      ),
    );
  }
}

/// iOS 加购的三类；价格来自 App Store 固定次数包，不按次计价。
const _appleAddonOffers = [
  AIAddonOffer(
    kind: 'CREATE',
    name: 'AI 简历生成',
    unitPriceCents: 0,
    maxQuantity: 10,
  ),
  AIAddonOffer(
    kind: 'POLISH',
    name: 'AI 简历优化',
    unitPriceCents: 0,
    maxQuantity: 10,
  ),
  AIAddonOffer(
    kind: 'TEXT',
    name: 'AI 单段生成',
    unitPriceCents: 0,
    maxQuantity: 100,
  ),
];

/// iOS 加购：选一档固定次数包，用 App Store 付款，服务端验单后到账。
class _AppleAIAddonCheckoutPage extends StatefulWidget {
  const _AppleAIAddonCheckoutPage({
    required this.offer,
    required this.products,
    required this.purchases,
  });
  final AIAddonOffer offer;
  final AppleMembershipProducts products;
  final AppleMembershipPurchases purchases;

  @override
  State<_AppleAIAddonCheckoutPage> createState() =>
      _AppleAIAddonCheckoutPageState();
}

class _AppleAIAddonCheckoutPageState extends State<_AppleAIAddonCheckoutPage> {
  late final int initialRevision = widget.purchases.membershipRevision;
  late final packs = AppleMembershipProducts.addonPacks(widget.offer.kind);
  late String selected = packs[packs.length > 1 ? 1 : 0].$1;
  bool _done = false;

  AppleMembershipProducts get products => widget.products;
  AppleMembershipPurchases get purchases => widget.purchases;

  bool get _completed =>
      purchases.membershipRevision > initialRevision &&
      purchases.lastDeliveredProductID ==
          AppleMembershipProducts.addonProductIDs[selected] &&
      purchases.state == ApplePurchaseState.delivered;

  @override
  void initState() {
    super.initState();
    purchases.addListener(_closeWhenDone);
  }

  @override
  void dispose() {
    purchases.removeListener(_closeWhenDone);
    super.dispose();
  }

  void _closeWhenDone() {
    if (_done || !mounted || !_completed) return;
    _done = true;
    final count = packs.firstWhere((pack) => pack.$1 == selected).$2;
    toast(context, '已到账：${widget.offer.name} $count 次');
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([products, purchases]),
    builder: (context, _) {
      final colors = context.colors;
      final price = products.price(selected);
      final label = purchases.busy
          ? switch (purchases.state) {
              ApplePurchaseState.purchasing => '等待 App Store',
              ApplePurchaseState.confirming => '确认订单中',
              ApplePurchaseState.restoring => '正在恢复购买',
              _ => '准备订单中',
            }
          : purchases.needsRetry
          ? '重试确认'
          : purchases.needsRestore
          ? '恢复并确认购买'
          : '立即购买';
      return Scaffold(
        backgroundColor: colors.canvas,
        appBar: AppPageBar(
          title: const Text('加购 AI 次数'),
          backgroundColor: colors.canvas,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.offer.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final (key, count) in packs)
                    _ApplePackTile(
                      count: count,
                      price: products.price(key),
                      loading: products.loading,
                      selected: key == selected,
                      onTap: purchases.busy || products.price(key) == null
                          ? null
                          : () => setState(() => selected = key),
                    ),
                ],
              ),
            ),
            if (purchases.message != null) ...[
              const SizedBox(height: 12),
              Text(
                purchases.message!,
                style: TextStyle(fontSize: 12, color: colors.accent),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              '通过 App Store 付款，确认后立即到账。加购次数不会过期，只在会员有效期内可用；会员到期后冻结，续费后恢复。',
              style: TextStyle(fontSize: 12, height: 1.5, color: colors.muted),
            ),
          ],
        ),
        bottomNavigationBar: _BottomPayBar(
          label: label,
          busy: purchases.busy,
          amount: '',
          displayAmount: price ?? (products.loading ? '加载中…' : '暂不可用'),
          onPressed:
              purchases.busy ||
                  (price == null &&
                      !purchases.needsRetry &&
                      !purchases.needsRestore)
              ? null
              : () async {
                  if (purchases.needsRetry) {
                    await purchases.retryConfirmation();
                  } else if (purchases.needsRestore) {
                    await purchases.restore();
                  } else {
                    await purchases.purchaseAddon(selected);
                  }
                },
        ),
      );
    },
  );
}

class _ApplePackTile extends StatelessWidget {
  const _ApplePackTile({
    required this.count,
    required this.price,
    required this.loading,
    required this.selected,
    this.onTap,
  });
  final int count;
  final String? price;
  final bool loading, selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? colors.accent : colors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$count 次',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.ink,
                    ),
                  ),
                ),
                Text(
                  price ?? (loading ? '加载中…' : '暂不可用'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: price == null ? colors.muted : colors.accent,
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
