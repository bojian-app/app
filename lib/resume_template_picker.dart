import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'dart:async';

import 'api/bojian_api.dart';
import 'app_icons.dart';
import 'app_store.dart';
import 'confirmation_dialog.dart';
import 'design.dart';
import 'resume_document.dart';
import 'resume_templates.dart';
import 'resume_thumbnail.dart';
import 'template_market_store.dart';

class ResumeTemplatePicker extends StatefulWidget {
  const ResumeTemplatePicker({
    super.key,
    required this.store,
    required this.resume,
    this.heightFactor = .88,
  });
  final AppStore store;
  final ResumeDraft resume;
  final double heightFactor;
  @override
  State<ResumeTemplatePicker> createState() => _ResumeTemplatePickerState();
}

class _ResumeTemplatePickerState extends State<ResumeTemplatePicker> {
  late int selected = widget.resume.marketTemplateID;
  late final TemplateMarketStore market = TemplateMarketStore(widget.store);
  List<Map<String, dynamic>> purchased = [];
  bool loading = true, saving = false, buying = false;
  String? loadError, error;
  int operation = 0;

  @override
  void initState() {
    super.initState();
    market.addListener(marketChanged);
    unawaited(market.appleProducts?.load());
    unawaited(market.refresh());
    load();
  }

  @override
  void dispose() {
    market.removeListener(marketChanged);
    market.dispose();
    super.dispose();
  }

  void marketChanged() {
    if (mounted) setState(() {});
  }

  Future<void> load() async {
    final request = ++operation;
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final result = await widget.store.purchasedResumeTemplates();
      if (!mounted || request != operation) return;
      setState(() => purchased = result);
    } catch (e) {
      if (mounted && request == operation) {
        setState(() => loadError = e is ApiFailure ? e.message : '已购买模板加载失败');
      }
    } finally {
      if (mounted && request == operation) setState(() => loading = false);
    }
  }

  Set<int> get usableIDs => {0, ...purchased.map((row) => integer(row['id']))};

  /// Market templates the account cannot use yet, in catalogue order.
  List<Map<String, dynamic>> get locked => market.templates
      .where(
        (row) =>
            integer(row['id']) > 0 &&
            !usableIDs.contains(integer(row['id'])) &&
            row['compatible'] != false,
      )
      .toList();

  Map<String, dynamic>? get lockedSelection {
    if (usableIDs.contains(selected)) return null;
    for (final row in locked) {
      if (integer(row['id']) == selected) return row;
    }
    return null;
  }

  static bool isPaid(Map<String, dynamic> row) => row['pricing_type'] == 'PAID';

  Map<String, dynamic>? catalogueRow(int id) {
    for (final row in market.templates) {
      if (integer(row['id']) == id) return row;
    }
    return null;
  }

  bool paidTemplate(Map<String, dynamic> row) {
    if (isPaid(row)) return true;
    final listed = catalogueRow(integer(row['id']));
    return listed != null && isPaid(listed);
  }

  int priceOf(Map<String, dynamic> row) {
    final own = integer(row['price_cents']);
    return own > 0
        ? own
        : integer(catalogueRow(integer(row['id']))?['price_cents']);
  }

  /// A paid template that is not bought for good. Members can use it for
  /// free while subscribed, but the permanent purchase is still offered.
  bool buyable(Map<String, dynamic> row) {
    final id = integer(row['id']);
    return id > 0 &&
        paidTemplate(row) &&
        !market.loadingOwned &&
        market.ownedError == null &&
        !market.ownedIDs.contains(id);
  }

  Future<void> buy(Map<String, dynamic> row) async {
    final id = integer(row['id']);
    if (saving || buying || !market.canPurchase(id)) return;
    final confirming =
        market.applePurchases?.needsRetry == true ||
        market.applePurchases?.needsRestore == true;
    setState(() {
      buying = true;
      error = null;
    });
    try {
      final ok =
          confirming ||
          await showAppConfirmation(
                context,
                title: '购买模板',
                content: Text(
                  '${market.priceLabel(id, priceOf(row))} 永久拥有该模板，不受会员到期影响。',
                ),
                cancelLabel: '取消',
                confirmLabel: market.applePurchases == null
                    ? '支付宝支付'
                    : 'App Store 购买',
              ) ==
              true;
      if (!ok || !mounted) return;
      final done = await market.purchase(id: id);
      if (!mounted) return;
      if (done) {
        await load();
        if (mounted) toast(context, '购买成功');
      }
    } catch (e) {
      if (mounted) toast(context, e is ApiFailure ? e.message : '购买失败，请重试');
    } finally {
      if (mounted) setState(() => buying = false);
    }
  }

  Future<void> apply() async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      if (selected == 0) {
        await widget.store.changeResumeLayout(
          widget.resume.id,
          ResumeLayout.standard,
        );
      } else {
        final pending = lockedSelection;
        if (pending != null) {
          // A free template is claimed the moment it is used.
          if (isPaid(pending)) throw const ApiFailure('请先购买该模板');
          final detail = await widget.store.request(
            'GetTemplatesId',
            path: {'id': '$selected'},
          );
          await market.acquire(
            id: selected,
            quotedRevision: integer(detail.data['revision']),
          );
        }
        await widget.store.changeResumeMarketTemplate(
          widget.resume.id,
          selected,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => error = e is ApiFailure ? e.message : '模板切换失败，请重试');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final choices = <Map<String, dynamic>>[
      {'id': 0, 'name': ResumeLayout.standard.title},
      ...purchased,
      ...locked,
    ];
    final pending = lockedSelection;
    final needsPurchase = pending != null && isPaid(pending);
    final available = choices.any((row) => integer(row['id']) == selected);
    final pendingID = pending == null ? 0 : integer(pending['id']);
    final busy = saving || buying;
    Map<String, dynamic>? memberRow;
    if (pending == null && selected != 0) {
      for (final row in purchased) {
        if (integer(row['id']) == selected) memberRow = row;
      }
    }
    final memberBuy = memberRow != null && buyable(memberRow);
    final action = needsPurchase
        ? (buying
              ? '正在处理…'
              : market.purchaseLabel(
                  pendingID,
                  integer(pending['price_cents']),
                ))
        : (saving ? '正在切换…' : '使用选中模板');
    final actionEnabled =
        !busy &&
        available &&
        !(needsPurchase && !market.canPurchase(pendingID));
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * widget.heightFactor,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '切换模板',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: saving ? null : () => Navigator.pop(context),
                    icon: const AppIcon(AppIcons.close, size: 20),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 900
                      ? 6
                      : constraints.maxWidth >= 600
                      ? 5
                      : 3;
                  return AutoPaginate(
                    canLoad:
                        market.cursor.isNotEmpty &&
                        !market.loading &&
                        !market.loadingMore &&
                        market.error == null,
                    onLoadMore: () => market.load(more: true),
                    child: CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                          sliver: SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: resumePaperSize.aspectRatio,
                                  mainAxisExtent: constraints.maxHeight < 260
                                      ? (constraints.maxHeight - 16).clamp(
                                          120.0,
                                          230.0,
                                        )
                                      : null,
                                ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => tile(choices[index]),
                              childCount: choices.length,
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            child:
                                loading || market.loading || market.loadingMore
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : loadError != null || market.error != null
                                ? Column(
                                    children: [
                                      Text(
                                        loadError ?? market.error!,
                                        style: TextStyle(
                                          color: context.colors.muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          if (loadError != null) load();
                                          if (market.error != null) {
                                            unawaited(market.refresh());
                                          }
                                        },
                                        child: const Text('重新加载'),
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: context.colors.surface,
                border: Border(top: BorderSide(color: context.colors.border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        error!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      if (memberBuy) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: busy || !market.canPurchase(selected)
                                ? null
                                : () => buy(memberRow!),
                            child: Text(
                              buying
                                  ? '正在处理…'
                                  : market.purchaseLabel(
                                      selected,
                                      priceOf(memberRow),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: FilledButton(
                          onPressed: !actionEnabled
                              ? null
                              : needsPurchase
                              ? () => buy(pending)
                              : apply,
                          child: Text(action),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget tile(Map<String, dynamic> design) {
    final id = integer(design['id']);
    final active = id == selected;
    final current = id == widget.resume.marketTemplateID;
    final lockedTile = id != 0 && !usableIDs.contains(id);
    final paidTile = lockedTile && isPaid(design);
    final priced = id != 0 && buyable(design);
    return Semantics(
      selected: active,
      button: true,
      label:
          '${design['name']}${current ? '，使用中' : ''}${paidTile ? '，需购买' : ''}',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: saving || buying
              ? null
              : () => setState(() {
                  selected = id;
                  error = null;
                }),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.zero,
              border: Border.all(
                color: active ? context.colors.accent : context.colors.border,
                width: active ? 1.5 : 1,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: EdgeInsets.zero,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: resumePaperSize.aspectRatio,
                      child: id == 0
                          ? StandardResumeThumbnail(resume: widget.resume)
                          : MarketResumeThumbnail(
                              url: design['thumbnail_url'] as String? ?? '',
                            ),
                    ),
                  ),
                ),
                if (lockedTile || priced)
                  Positioned(
                    left: 4,
                    bottom: 4,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xCC000000),
                          borderRadius: BorderRadius.zero,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          child: Text(
                            lockedTile && !isPaid(design)
                                ? '免费'
                                : market.priceLabel(id, priceOf(design)),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (current)
                  Positioned(
                    top: 12,
                    right: -23,
                    child: IgnorePointer(
                      child: Transform.rotate(
                        angle: math.pi / 4,
                        child: Container(
                          width: 90,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: context.colors.palette.seed,
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x26000000),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            '使用中',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              height: 1,
                            ),
                          ),
                        ),
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
