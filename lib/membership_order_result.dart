part of 'membership_page.dart';

/// 会员订单结果页：支付成功后替换确认订单页展示。支付宝已扣款但服务端还没收到
/// 验签通知时先显示“确认中”，并继续查询订单直到开通或超时。
class MembershipOrderResultPage extends StatefulWidget {
  const MembershipOrderResultPage({
    super.key,
    required this.store,
    required this.plan,
    required this.order,
  });
  final AppStore store;
  final MembershipPlan plan;

  /// 服务端返回的会员订单。
  final Map<String, dynamic> order;

  @override
  State<MembershipOrderResultPage> createState() =>
      _MembershipOrderResultPageState();
}

class _MembershipOrderResultPageState extends State<MembershipOrderResultPage> {
  late Map<String, dynamic> order = widget.order;
  bool refreshing = false;

  /// 自动查询结束后仍未到账时提示联系客服。
  bool gaveUp = false;

  bool get paid => order['status'] == 'PAID';

  @override
  void initState() {
    super.initState();
    if (!paid) _poll();
  }

  Future<void> _refresh() async {
    try {
      final result = await widget.store.request(
        'GetMembershipOrdersId',
        path: {'id': '${order['id']}'},
      );
      if (mounted) setState(() => order = result.data);
    } on ApiFailure {
      // 网络抖动时保留当前结果，下次查询或手动刷新再更新。
    }
  }

  /// 通知通常几秒内到达；一分钟后停止自动查询，用户仍可手动刷新。
  Future<void> _poll() async {
    for (var attempt = 0; attempt < 30 && mounted && !paid; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      await _refresh();
    }
    if (mounted && !paid) setState(() => gaveUp = true);
  }

  Future<void> _manualRefresh() async {
    setState(() => refreshing = true);
    await _refresh();
    if (mounted) setState(() => refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final amount = integer(order['amount_cents']);
    final discount = integer(order['discount_cents']);
    final paidAt = DateTime.tryParse('${order['paid_at'] ?? ''}')?.toLocal();
    final endsAt = DateTime.tryParse('${order['membership_ends_at'] ?? ''}')
        ?.toLocal();
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppPageBar(
        title: const Text('支付结果'),
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
                    gradient: paid
                        ? const LinearGradient(colors: _blueGradient)
                        : null,
                    color: paid ? null : colors.border,
                  ),
                  child: paid
                      ? const HugeIcon(
                          icon: HugeIcons.strokeRoundedTick02,
                          size: 34,
                          color: Colors.white,
                          strokeWidth: 2.4,
                        )
                      : SizedBox.square(
                          dimension: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: colors.muted,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                Text(
                  paid ? '支付成功' : '支付结果确认中',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: colors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  paid
                      ? '${widget.plan.orderName}已开通，可立即使用全部会员权益'
                      : gaveUp
                      ? '暂未收到到账通知，可稍后刷新。付款后 30 分钟内仍未开通，请在“隐私与设置 → 意见反馈”联系我们'
                      : '已提交支付，会员通常几秒内开通',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: colors.muted,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '¥${(amount / 100).toStringAsFixed(2)}',
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
                if (discount > 0)
                  _OrderLine('优惠券', '-¥${(discount / 100).toStringAsFixed(2)}'),
                _OrderLine('支付方式', _channelName('${order['channel']}')),
                if (paidAt != null) _OrderLine('支付时间', _dateTime(paidAt)),
                if (paid && endsAt != null)
                  _OrderLine('会员有效期至', _dateTime(endsAt)),
                _OrderLine('订单编号', '${order['id']}'),
              ],
            ),
          ),
          if (!paid) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: refreshing ? null : _manualRefresh,
                child: Text(refreshing ? '查询中…' : '刷新结果'),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          height: 46,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(23),
              gradient: const LinearGradient(colors: _blueGradient),
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
              child: Text(
                paid ? '完成' : '返回会员页',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _dateTime(DateTime value) =>
    '${_day(value)} ${_two(value.hour)}:${_two(value.minute)}';
