part of 'membership_page.dart';

class _AppleProductNotice extends StatelessWidget {
  const _AppleProductNotice({required this.products, this.membership = false});
  final AppleMembershipProducts products;
  final bool membership;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          products.error ?? '',
          style: TextStyle(
            fontSize: 12,
            color: membership
                ? _MembershipColors.of(context).muted
                : context.colors.muted,
          ),
        ),
      ),
      TextButton(
        onPressed: products.loading ? null : products.load,
        style: membership
            ? TextButton.styleFrom(
                foregroundColor: _MembershipColors.of(context).accent,
              )
            : null,
        child: const Text('刷新'),
      ),
    ],
  );
}

class _AppleMembershipCheckoutPage extends StatefulWidget {
  const _AppleMembershipCheckoutPage({
    required this.plan,
    required this.products,
    required this.purchases,
  });
  final MembershipPlan plan;
  final AppleMembershipProducts products;
  final AppleMembershipPurchases purchases;

  @override
  State<_AppleMembershipCheckoutPage> createState() =>
      _AppleMembershipCheckoutPageState();
}

class _AppleMembershipCheckoutPageState
    extends State<_AppleMembershipCheckoutPage> {
  late final int initialRevision = widget.purchases.membershipRevision;
  // 自动续费须由用户主动勾选。
  bool autoRenew = false;
  bool _resultShown = false;
  MembershipPlan get plan => widget.plan;
  AppleMembershipProducts get products => widget.products;
  AppleMembershipPurchases get purchases => widget.purchases;

  bool get _completed =>
      purchases.membershipRevision > initialRevision &&
      purchases.lastDeliveredProductID ==
          AppleMembershipProducts.productIDs[AppleMembershipProducts.productKey(
            plan.code,
            autoRenew: autoRenew,
          )] &&
      purchases.state == ApplePurchaseState.delivered;

  @override
  void initState() {
    super.initState();
    purchases.addListener(_showResultWhenDone);
  }

  @override
  void dispose() {
    purchases.removeListener(_showResultWhenDone);
    super.dispose();
  }

  /// 付款确认到账后用结果页替换确认订单页，返回时直接回到会员页。
  void _showResultWhenDone() {
    if (_resultShown || !mounted || !_completed) return;
    _resultShown = true;
    Navigator.of(context).pushReplacement(
      CupertinoPageRoute<void>(
        builder: (_) => _AppleMembershipResultPage(
          store: purchases.store,
          plan: plan,
          price: products.priceLabel(plan.code, autoRenew: autoRenew),
          autoRenew: autoRenew,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([products, purchases]),
    builder: (context, _) {
      final colors = context.colors;
      final price = products.priceLabel(plan.code, autoRenew: autoRenew);
      final available = products.available(plan.code, autoRenew: autoRenew);
      final completed =
          purchases.membershipRevision > initialRevision &&
          purchases.lastDeliveredProductID ==
              AppleMembershipProducts
                  .productIDs[AppleMembershipProducts.productKey(
                plan.code,
                autoRenew: autoRenew,
              )] &&
          purchases.state == ApplePurchaseState.delivered;
      final waiting = purchases.awaitingApproval(
        plan.code,
        autoRenew: autoRenew,
      );
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
          : waiting
          ? '等待批准'
          : completed
          ? '购买已确认'
          : available
          ? (autoRenew ? '确认开通' : '确认购买')
          : '商品暂不可用';
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
                      _PlanThumb(plan: plan),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan.orderName,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: colors.ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '有效期 ${plan.period}',
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Divider(height: 1, color: colors.border),
                  const SizedBox(height: 12),
                  _OrderLine('商品价格', price, emphasize: true),
                  _OrderLine(
                    '续费方式',
                    autoRenew ? '每${_renewUnit(plan)}自动续费' : '到期不自动续费',
                  ),
                  _AppleAutoRenewToggle(
                    value: autoRenew,
                    plan: plan,
                    price: products.priceLabel(plan.code, autoRenew: true),
                    onChanged: purchases.busy
                        ? null
                        : (value) => setState(() => autoRenew = value),
                  ),
                  // 仅在商品加载失败时显示错误与刷新入口
                  if (products.error != null)
                    _AppleProductNotice(products: products),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Card(
              child: Row(
                children: [
                  Icon(Icons.apple, size: 30, color: colors.ink),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'App Store 内购',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '通过你的 Apple 账户付款',
                          style: TextStyle(fontSize: 12, color: colors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '会员权益',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final (_, title, _, benefit) in _benefits)
                    _OrderLine(title, benefit),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              purchases.message ?? '付款后由系统确认会员权益。如已付款但未到账，请重试确认或恢复购买。',
              style: TextStyle(fontSize: 13, height: 1.5, color: colors.muted),
            ),
            Wrap(
              spacing: 4,
              children: [
                TextButton(
                  onPressed: purchases.busy ? null : purchases.restore,
                  child: const Text('恢复购买'),
                ),
                TextButton(
                  onPressed: () => _manageSubscriptions(context),
                  child: const Text('管理自动续费'),
                ),
                TextButton(
                  onPressed: () => openPage<void>(
                    context,
                    const LegalDocumentPage(
                      kind: LegalDocumentKind.userAgreement,
                    ),
                  ),
                  child: const Text('用户协议'),
                ),
                TextButton(
                  onPressed: () => openPage<void>(
                    context,
                    const LegalDocumentPage(
                      kind: LegalDocumentKind.privacyPolicy,
                    ),
                  ),
                  child: const Text('隐私政策'),
                ),
              ],
            ),
          ],
        ),
        bottomNavigationBar: _BottomPayBar(
          label: label,
          busy: purchases.busy,
          amount: '',
          displayAmount: price,
          onPressed:
              purchases.busy ||
                  waiting ||
                  completed ||
                  (!available &&
                      !purchases.needsRetry &&
                      !purchases.needsRestore)
              ? null
              : () async {
                  if (purchases.needsRetry) {
                    await purchases.retryConfirmation();
                  } else if (purchases.needsRestore) {
                    await purchases.restore();
                  } else {
                    await purchases.purchase(plan.code, autoRenew: autoRenew);
                  }
                },
        ),
      );
    },
  );
}

String _renewUnit(MembershipPlan plan) => plan.code == 'YEAR' ? '年' : '月';

Future<void> _manageSubscriptions(BuildContext context) async {
  try {
    await AppleMembershipProducts.manageSubscriptions();
  } on PlatformException catch (e) {
    if (context.mounted) toast(context, e.message ?? '暂时无法打开订阅管理');
  } on MissingPluginException {
    if (context.mounted) toast(context, '当前设备暂不支持订阅管理');
  }
}

/// 自动续费勾选与扣费规则说明（App Store 审核要求在购买前展示）。
class _AppleAutoRenewToggle extends StatelessWidget {
  const _AppleAutoRenewToggle({
    required this.value,
    required this.plan,
    required this.price,
    required this.onChanged,
  });
  final bool value;
  final MembershipPlan plan;
  final String price;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        borderRadius: BorderRadius.circular(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: Checkbox(
                value: value,
                onChanged: onChanged == null ? null : (v) => onChanged!(v!),
                activeColor: colors.accent,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '到期自动续费 $price/${_renewUnit(plan)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '勾选后通过 Apple 账户每${_renewUnit(plan)}自动扣费，'
                      '到期前 24 小时内续费，价格以 App Store 显示为准。'
                      '如需取消，请在到期前至少 24 小时在「管理自动续费」或系统设置中关闭。',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: colors.muted,
                      ),
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

/// App Store 购买结果页：确认到账后替换确认订单页展示。
class _AppleMembershipResultPage extends StatefulWidget {
  const _AppleMembershipResultPage({
    required this.store,
    required this.plan,
    required this.price,
    required this.autoRenew,
  });
  final AppStore store;
  final MembershipPlan plan;
  final String price;
  final bool autoRenew;

  @override
  State<_AppleMembershipResultPage> createState() =>
      _AppleMembershipResultPageState();
}

class _AppleMembershipResultPageState
    extends State<_AppleMembershipResultPage> {
  final DateTime paidAt = DateTime.now();
  DateTime? endsAt;

  @override
  void initState() {
    super.initState();
    _loadEndsAt();
  }

  Future<void> _loadEndsAt() async {
    try {
      final result = await widget.store.request('GetMembership');
      final value = result.data['ends_at'];
      final ends = value is String ? DateTime.tryParse(value)?.toLocal() : null;
      if (mounted && result.data['active'] == true && ends != null) {
        setState(() => endsAt = ends);
      }
    } catch (_) {
      // 有效期只是补充信息，读取失败时不显示该行。
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppPageBar(
        title: const Text('购买结果'),
        backgroundColor: colors.canvas,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _Card(
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: context.colors.palette.purchaseGradient,
                  ),
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedTick02,
                    size: 34,
                    color: Colors.white,
                    strokeWidth: 2.4,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '支付成功',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: colors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${widget.plan.orderName}已开通，可立即使用全部会员权益',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: colors.muted,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  widget.price,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: colors.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Card(
            child: Column(
              children: [
                _OrderLine('商品', widget.plan.orderName),
                _OrderLine('支付方式', 'App Store'),
                if (widget.autoRenew) _OrderLine('到期自动续费', '已开启'),
                _OrderLine('支付时间', _dateTime(paidAt)),
                if (endsAt != null) _OrderLine('会员有效期至', _dateTime(endsAt!)),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          height: 46,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(23),
              gradient: context.colors.palette.purchaseGradient,
            ),
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(23),
                ),
              ),
              child: const Text(
                '完成',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
