part of 'membership_page.dart';

/// 安卓某个套餐勾选自动续费后的每期价格和可签约渠道，以服务端 auto_renew 为准。
class AutoRenewOption {
  const AutoRenewOption({required this.amountCents, required this.channels});
  final int amountCents;
  final Set<String> channels;

  String get price =>
      (amountCents / 100).toStringAsFixed(amountCents % 100 == 0 ? 0 : 2);
}

/// 按套餐返回已开通代扣的自动续费选项；没有渠道的套餐不出现，下单页也就不显示勾选框。
Future<Map<String, AutoRenewOption>> loadAutoRenewOptions(
  AppStore store,
) async {
  final result = await store.request('GetMembershipPlans');
  final options = <String, AutoRenewOption>{};
  for (final row in result.data['auto_renew'] as List? ?? const []) {
    if (row is! Map) continue;
    final channels = (row['channels'] as List? ?? const [])
        .whereType<String>()
        .toSet();
    if (channels.isEmpty) continue;
    options['${row['plan_code']}'] = AutoRenewOption(
      amountCents: integer(row['amount_cents']),
      channels: channels,
    );
  }
  return options;
}

/// 下单页“自动续费”勾选框，默认不勾选；勾选后写明扣费金额、周期和取消方式。
/// [price] 是带币种的每期价格，如“¥18”，iOS 传 App Store 本地化价格。
class MembershipAutoRenewToggle extends StatelessWidget {
  const MembershipAutoRenewToggle({
    super.key,
    required this.value,
    required this.onChanged,
    required this.plan,
    required this.price,
  });
  final bool value;
  final ValueChanged<bool>? onChanged;
  final MembershipPlan plan;
  final String price;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final unit = plan.code == 'YEAR' ? '年' : '月';
    return Semantics(
      checked: value,
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: value,
                  onChanged: onChanged == null
                      ? null
                      : (checked) => onChanged!(checked ?? false),
                  activeColor: _blueGradient.first,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '自动续费 $price/$unit',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value
                          ? '每$unit自动扣费 $price，在会员到期前扣款并顺延 ${plan.period}；可随时在会员页取消，取消后已开通的会员保留到期满。'
                          : '不勾选为一次性购买，到期不自动扣费。',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: colors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 拉起微信委托代扣签约页，用户从微信返回 App 后才结束。模板配有签约小程序时走小程序，
/// 否则走 OpenBusinessWebview。返回 false 表示未能打开微信。
Future<bool> _openWeChatContractSign(Map sign) async {
  final sdk = Fluwx();
  if (!await sdk.registerApi(
    appId: NativeWeChatAuthorizer.appID,
    universalLink: NativeWeChatAuthorizer.universalLink,
  )) {
    throw const ApiFailure('微信暂不可用，请稍后重试');
  }
  if (!await sdk.isWeChatInstalled) {
    throw const ApiFailure('请先安装微信');
  }
  final returned = _AppReturn();
  try {
    final username = '${sign['miniprogram_username'] ?? ''}';
    final launched = username.isNotEmpty
        ? await sdk.open(
            target: MiniProgram(
              username: username,
              path: '${sign['miniprogram_path'] ?? ''}',
            ),
          )
        : await sdk.autoDeduct(
            data: AutoDeduct.custom(
              queryInfo: {'pre_entrustweb_id': '${sign['pre_entrustweb_id']}'},
            ),
          );
    if (!launched) return false;
    await returned.future.timeout(
      const Duration(minutes: 10),
      onTimeout: () {},
    );
    return true;
  } finally {
    returned.dispose();
  }
}

/// 应用离开前台后再次回到前台时完成。
class _AppReturn with WidgetsBindingObserver {
  _AppReturn() {
    WidgetsBinding.instance.addObserver(this);
  }

  final _completer = Completer<void>();
  bool _left = false;

  Future<void> get future => _completer.future;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _left = true;
    } else if (state == AppLifecycleState.resumed &&
        _left &&
        !_completer.isCompleted) {
      _completer.complete();
    }
  }

  void dispose() => WidgetsBinding.instance.removeObserver(this);
}

/// 会员页上的自动续费状态与“取消自动续费”入口。
class _AutoRenewStatus extends StatelessWidget {
  const _AutoRenewStatus({
    required this.subscription,
    required this.onCancel,
    this.busy = false,
  });
  final Map subscription;
  final VoidCallback onCancel;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final active = subscription['status'] == 'ACTIVE';
    final next = subscription['next_charge_on'];
    final amount = integer(subscription['amount_cents']);
    final channel = _channelName('${subscription['channel']}');
    final name = subscription['plan_code'] == 'YEAR' ? '年卡' : '月卡';
    final detail = !active
        ? '$channel签约确认中，稍后刷新查看'
        : next is String && next.isNotEmpty
        ? '下次扣款 $next · ¥${(amount / 100).toStringAsFixed(amount % 100 == 0 ? 0 : 2)} · $channel'
        : '首期扣款确认中 · $channel';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedRepeat,
            size: 20,
            color: _gold,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active ? '$name自动续费生效中' : '$name自动续费开通中',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: busy ? null : onCancel,
            style: TextButton.styleFrom(
              foregroundColor: _gold,
              minimumSize: const Size(44, 44),
            ),
            child: Text(busy ? '处理中' : '取消自动续费'),
          ),
        ],
      ),
    );
  }
}
