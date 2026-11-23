import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api/bojian_api.dart';
import 'app_icons.dart';
import 'app_page_bar.dart';
import 'app_store.dart';
import 'design.dart';
import 'playful_refresh.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key, required this.store});
  final AppStore store;

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  List<Map<String, dynamic>> orders = [];
  String cursor = '';
  String? error;
  bool loading = false, loadingMore = false, retryMore = false;
  int generation = 0;
  late int session;

  @override
  void initState() {
    super.initState();
    session = widget.store.epoch;
    widget.store.addListener(_sessionChanged);
    _load();
  }

  void _sessionChanged() {
    if (session == widget.store.epoch) return;
    session = widget.store.epoch;
    generation++;
    setState(() {
      orders = [];
      cursor = '';
      error = null;
      loading = loadingMore = false;
    });
    if (widget.store.isAuthenticated) _load();
  }

  @override
  void dispose() {
    widget.store.removeListener(_sessionChanged);
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (!widget.store.isAuthenticated) return;
    if (more && (cursor.isEmpty || loading || loadingMore)) return;
    final request = more ? generation : ++generation;
    final epoch = widget.store.epoch;
    bool current() =>
        mounted && generation == request && widget.store.epoch == epoch;
    setState(() {
      error = null;
      if (more) {
        loadingMore = true;
      } else {
        loading = true;
        loadingMore = false;
      }
    });
    try {
      final response = await widget.store.request(
        'GetMembershipOrderHistory',
        query: {'limit': '20', if (more) 'cursor': cursor},
      );
      if (!current()) return;
      if (response.data['items'] is! List) {
        throw const FormatException('Missing order records');
      }
      final page = items(response.data);
      setState(() {
        final existing = more
            ? orders.map((row) => row['id']).toSet()
            : <Object?>{};
        orders = [
          if (more) ...orders,
          ...page.where((row) => !existing.contains(row['id'])),
        ];
        cursor = response.nextCursor;
      });
    } catch (exception) {
      if (current()) {
        setState(() {
          retryMore = more;
          error = exception is ApiFailure ? exception.message : '订单记录加载失败，请重试';
        });
      }
    } finally {
      if (current()) setState(() => loading = loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.isDark ? context.colors.canvas : Colors.white,
    appBar: AppPageBar(title: const Text('订单记录')),
    body: !widget.store.isAuthenticated
        ? const Center(child: Text('登录后查看订单记录'))
        : PlayfulRefresh(
            onRefresh: () => _load(),
            hasError: () => error != null,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (loading && orders.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (orders.isEmpty && error == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: Column(
                      children: [
                        AppIcon(
                          AppIcons.article,
                          size: 38,
                          color: context.colors.muted,
                        ),
                        const SizedBox(height: 14),
                        const Text('暂无订单记录'),
                        const SizedBox(height: 6),
                        Text(
                          '购买会员或 AI 次数后可在这里查看',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final order in orders)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _OrderRecord(order: order),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        Text(error!, textAlign: TextAlign.center),
                        TextButton(
                          onPressed: loading || loadingMore
                              ? null
                              : () => _load(more: retryMore),
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  )
                else if (loadingMore)
                  const Center(child: CircularProgressIndicator())
                else if (cursor.isNotEmpty)
                  TextButton(
                    onPressed: loading ? null : () => _load(more: true),
                    child: const Text('加载更多'),
                  )
                else if (orders.isNotEmpty)
                  Center(
                    child: Text(
                      '没有更多订单了',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
  );
}

class _OrderRecord extends StatelessWidget {
  const _OrderRecord({required this.order});
  final Map<String, dynamic> order;

  String get number => '${order['order_no'] ?? ''}';
  String get channel => switch (order['channel']) {
    'ALIPAY' => '支付宝',
    'WECHAT' => '微信支付',
    'APPLE' => 'App Store',
    _ => '其他支付方式',
  };
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${order['title'] ?? '订单'}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                orderStatusLabel(order['status']),
                style: TextStyle(
                  fontSize: 12,
                  color: order['status'] == 'PAID'
                      ? colors.accent
                      : colors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  channel,
                  style: TextStyle(fontSize: 12, color: colors.muted),
                ),
              ),
              Text(
                orderAmountLabel(order),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colors.ink,
                ),
              ),
            ],
          ),
          if (order['environment'] == 'Sandbox')
            Text(
              'Apple 沙盒测试订单',
              style: TextStyle(fontSize: 12, color: colors.muted),
            ),
          const SizedBox(height: 10),
          Text(
            '下单时间  ${_orderTime(order['created_at'])}',
            style: TextStyle(fontSize: 12, color: colors.muted),
          ),
          if (order['paid_at'] != null) ...[
            const SizedBox(height: 4),
            Text(
              '支付时间  ${_orderTime(order['paid_at'])}',
              style: TextStyle(fontSize: 12, color: colors.muted),
            ),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  '订单号  $number',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: colors.muted,
                  ),
                ),
              ),
              IconButton(
                tooltip: '复制订单号',
                onPressed: number.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: number));
                        if (context.mounted) toast(context, '订单号已复制');
                      },
                icon: AppIcon(AppIcons.copy, size: 16, color: colors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String orderDateLabel(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _orderTime(Object? value) {
  final at = DateTime.tryParse('$value')?.toLocal();
  if (at == null) return '—';
  String two(int number) => number.toString().padLeft(2, '0');
  return '${orderDateLabel(at)} ${two(at.hour)}:${two(at.minute)}';
}

String orderStatusLabel(Object? status) => switch (status) {
  'PENDING' => '待支付',
  'PAID' => '已支付',
  'CLOSED' => '已关闭',
  'REVOKED' => '已退款 / 撤销',
  'EXPIRED' => '权益已过期',
  _ => '状态待确认',
};

String orderAmountLabel(Map<String, dynamic> order) {
  final value = integer(order['amount_milliunits']);
  final currency = '${order['currency'] ?? 'CNY'}';
  final fraction = (value % 1000).toString().padLeft(3, '0');
  final decimals = value % 10 == 0 ? fraction.substring(0, 2) : fraction;
  return '${currency == 'CNY' ? '¥' : '$currency '}${value ~/ 1000}.$decimals';
}
