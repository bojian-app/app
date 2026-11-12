import 'profile_identity.dart' show ProfileContentTabs;
import 'app_page_bar.dart';
import 'playful_refresh.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import 'api/bojian_api.dart';
import 'app_icons.dart';
import 'app_store.dart';
import 'form_page_layout.dart';
import 'design.dart';
import 'confirmation_dialog.dart';
import 'template_market_store.dart';
import 'template_live_preview.dart';
import 'network_image_cache.dart';
import 'profile_avatar.dart';
import 'points_coin.dart';
import 'points_page.dart';

/// Every market template is published by the platform.
const officialTemplatePublisher = '博简官方';

class TemplateMarketView extends StatefulWidget {
  const TemplateMarketView({
    super.key,
    required this.store,
    required this.onUseTemplate,
  });
  final AppStore store;
  final void Function(BuildContext context, Map<String, dynamic> template)
  onUseTemplate;
  @override
  State<TemplateMarketView> createState() => _TemplateMarketViewState();
}

class _TemplateMarketViewState extends State<TemplateMarketView>
    with SingleTickerProviderStateMixin {
  static const filters = [
    TemplateMarketFilter.all,
    TemplateMarketFilter.free,
    TemplateMarketFilter.paid,
  ];
  late final tabs = TabController(length: filters.length, vsync: this);
  late final markets = [
    for (final filter in filters)
      TemplateMarketStore(widget.store)..filter = filter,
  ];
  final loaded = <int>{};
  int activeIndex = 0;
  TemplateMarketStore get market => markets[tabs.index];

  void loadNearby() {
    for (final index in [tabs.index - 1, tabs.index, tabs.index + 1]) {
      if (index >= 0 && index < markets.length && loaded.add(index)) {
        unawaited(markets[index].refresh());
      }
    }
    if (activeIndex != tabs.index) {
      activeIndex = tabs.index;
      FocusManager.instance.primaryFocus?.unfocus();
      unawaited(market.loadOwned());
    }
  }

  void searchAll(String value, {bool immediately = false}) {
    for (final entry in markets) {
      entry.search(value, immediately: immediately);
    }
  }

  final search = TextEditingController();
  @override
  void initState() {
    super.initState();
    tabs.addListener(loadNearby);
    loadNearby();
  }

  @override
  void dispose() {
    search.dispose();
    tabs.removeListener(loadNearby);
    tabs.dispose();
    for (final entry in markets) {
      entry.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([tabs, ...markets]),
    builder: (context, _) => Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppPageBar(
        titleSpacing: appPageHorizontalPadding,
        title: const Text('模板市场'),
        actions: [_BalancePill(store: widget.store)],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 600 + 2 * appPageHorizontalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  appPageHorizontalPadding,
                  8,
                  appPageHorizontalPadding,
                  4,
                ),
                child: TextField(
                  controller: search,
                  maxLength: 100,
                  onChanged: searchAll,
                  onSubmitted: (value) => searchAll(value, immediately: true),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: '搜索模板',
                    counterText: '',
                    filled: true,
                    fillColor: (context.isDark
                        ? context.colors.accentSoft
                        : const Color(0xFFF2F3F5)),
                    isDense: true,
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(10),
                      child: AppIcon(
                        AppIcons.search,
                        size: 18,
                        color: context.colors.muted,
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 38),
                    suffixIcon: search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清空搜索',
                            onPressed: () {
                              search.clear();
                              searchAll('', immediately: true);
                            },
                            icon: AppIcon(
                              AppIcons.clear,
                              size: 18,
                              color: context.colors.muted,
                            ),
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              ProfileContentTabs(
                controller: tabs,
                tabBarKey: const ValueKey('template-market-filters'),
                horizontalPadding: appPageHorizontalPadding - 8,
                tabs: [
                  for (final filter in filters)
                    Tab(
                      key: ValueKey('market-tab-${filter.name}'),
                      text: filter.label,
                      height: 36,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  key: const ValueKey('template-market-swipe'),
                  controller: tabs,
                  children: [for (final entry in markets) catalogue(entry)],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget catalogue(TemplateMarketStore market) => AutoPaginate(
    canLoad:
        market.filter != TemplateMarketFilter.owned &&
        market.cursor.isNotEmpty &&
        !market.loading &&
        !market.loadingMore &&
        market.error == null,
    onLoadMore: () => market.load(more: true),
    child: PlayfulRefresh(
      onRefresh: market.refresh,
      hasError: () => market.error != null || market.ownedError != null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final rows = market.visible;
          final own = market.filter == TemplateMarketFilter.owned;
          final loading = own ? market.loadingOwned : market.loading;
          final failure = own ? market.ownedError : market.error;
          return CustomScrollView(
            key: PageStorageKey('market-scroll-${market.filter.name}'),
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              if (!own && market.ownedError != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      appPageHorizontalPadding,
                      0,
                      appPageHorizontalPadding,
                      12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '购买状态暂时无法同步',
                            style: TextStyle(
                              color: context.colors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: market.loadOwned,
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (rows.isEmpty)
                SliverFillRemaining(
                  // EmptyState measures its available height and scrolls internally.
                  hasScrollBody: true,
                  child: _MarketStatus(
                    loading: loading,
                    error: failure,
                    title: search.text.trim().isNotEmpty
                        ? '没有找到相关模板'
                        : own
                        ? '暂无已获取模板'
                        : '暂无上架模板',
                    subtitle: search.text.trim().isNotEmpty
                        ? '试试其他关键词，或切换筛选条件。'
                        : own
                        ? '获取的市场模板会显示在这里。'
                        : '新的模板上架后会显示在这里。',
                    retry: market.refresh,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    appPageHorizontalPadding,
                    0,
                    appPageHorizontalPadding,
                    20,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: _TemplateCard.gridDelegate(
                      context,
                      constraints.maxWidth,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final item = rows[index],
                          acquired = market.ownedIDs.contains(
                            integer(item['id']),
                          );
                      return _TemplateCard(
                        template: item,
                        acquired: acquired,
                        onTap: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => TemplateMarketDetail(
                                market: market,
                                template: item,
                                onUseTemplate: widget.onUseTemplate,
                              ),
                            ),
                          );
                        },
                      );
                    }, childCount: rows.length),
                  ),
                ),
              if (rows.isNotEmpty && failure != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      appPageHorizontalPadding,
                      0,
                      appPageHorizontalPadding,
                      16,
                    ),
                    child: Column(
                      children: [
                        Text(
                          failure,
                          style: TextStyle(
                            color: context.colors.muted,
                            fontSize: 12,
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              market.load(more: market.cursor.isNotEmpty),
                          child: const Text('重新加载'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!own && rows.isNotEmpty)
                SliverToBoxAdapter(
                  child: PageLoadingFooter(visible: market.loadingMore),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class _MarketStatus extends StatelessWidget {
  const _MarketStatus({
    required this.loading,
    required this.error,
    required this.title,
    required this.subtitle,
    required this.retry,
  });
  final bool loading;
  final String? error;
  final String title, subtitle;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => !loading && error == null
      ? EmptyState(title, subtitle)
      : Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else ...[
                  AppIcon(
                    AppIcons.templateMarket,
                    size: 32,
                    color: context.colors.muted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    error == null ? title : '模板加载失败',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error ?? subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.colors.muted,
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextButton(
                        onPressed: retry,
                        child: const Text('重新加载'),
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
}

class MarketTemplateArtwork extends StatelessWidget {
  const MarketTemplateArtwork({
    super.key,
    required this.template,
    this.fit = BoxFit.contain,
  });
  final Map<String, dynamic> template;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    final url = template['thumbnail_url'] as String? ?? '';
    final pending = template['preview_status'] == 'PENDING';
    final fallback = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(
            AppIcons.templatePreview,
            size: 28,
            color: context.colors.muted,
          ),
          const SizedBox(height: 8),
          Text(
            pending ? '预览生成中' : '预览暂不可用',
            style: TextStyle(fontSize: 10, color: context.colors.muted),
          ),
        ],
      ),
    );
    return url.isEmpty
        ? fallback
        : Image(
            image: ResizeImage(CachedNetworkImage(url), width: 720),
            gaplessPlayback: true,
            fit: fit,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
            errorBuilder: (_, _, _) => fallback,
          );
  }
}

/// Points balance in the market app bar; opens the points center.
class _BalancePill extends StatelessWidget {
  const _BalancePill({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final points = store.points;
      if (!store.isAuthenticated || points == null) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(right: appPageHorizontalPadding),
        child: TextButton(
          key: const ValueKey('market-balance'),
          onPressed: () => openPage(
            context,
            Scaffold(
              appBar: AppPageBar(title: const Text('积分中心')),
              body: PointsPage(store: store),
            ),
          ),
          style: TextButton.styleFrom(
            backgroundColor: context.isDark
                ? context.colors.accentSoft
                : const Color(0xFFF2F3F5),
            foregroundColor: context.colors.ink,
            minimumSize: const Size(0, 30),
            padding: const EdgeInsets.fromLTRB(6, 0, 10, 0),
            shape: const StadiumBorder(),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PointsCoin(size: 18),
              const SizedBox(width: 4),
              Text(
                '$points',
                style: const TextStyle(
                  fontFamily: 'ResumeDocument',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                '积分',
                style: TextStyle(fontSize: 12, color: context.colors.muted),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// A market card: just the template's own page, with small tags on its
/// corners.
class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.acquired,
    required this.onTap,
  });
  final Map<String, dynamic> template;
  final bool acquired;
  final VoidCallback onTap;

  static const _pageRatio = 595 / 842;

  static int columns(double width) => width >= 1000
      ? 5
      : width >= 700
      ? 4
      : width >= 500
      ? 3
      : 2;

  /// Rows are as tall as the page preview, so the grid fits any width.
  static SliverGridDelegate gridDelegate(BuildContext context, double width) {
    final count = columns(width);
    final item =
        (width - 2 * appPageHorizontalPadding - 12 * (count - 1)) / count;
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: count,
      crossAxisSpacing: 12,
      mainAxisSpacing: 16,
      mainAxisExtent: item / _pageRatio,
    );
  }

  bool get recent {
    final published = DateTime.tryParse('${template['published_at'] ?? ''}');
    return published != null &&
        DateTime.now().difference(published) < const Duration(days: 14);
  }

  @override
  Widget build(BuildContext context) {
    Widget tag(String text, Color background, BorderRadius radius) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: radius),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          height: 1.1,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14141E3C),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              MarketTemplateArtwork(template: template, fit: BoxFit.cover),
              if (recent && !acquired)
                Positioned(
                  left: 0,
                  top: 0,
                  child: tag(
                    '新',
                    const Color(0xFFF5483B),
                    const BorderRadius.only(bottomRight: Radius.circular(6)),
                  ),
                ),
              if (acquired)
                Positioned(
                  top: 6,
                  right: 6,
                  child: tag(
                    '已获取',
                    const Color(0x8C1A2233),
                    BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Coin and amount, the same price treatment as the points center.
class _PointsPrice extends StatelessWidget {
  const _PointsPrice({required this.points, required this.size});
  final int points;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      PointsCoin(size: size),
      SizedBox(width: size * .2),
      Text(
        '$points',
        style: TextStyle(
          fontFamily: 'ResumeDocument',
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFE07B00),
        ),
      ),
    ],
  );
}

String _publishedLabel(Map<String, dynamic> design) {
  final published = DateTime.tryParse('${design['published_at'] ?? ''}');
  if (published == null) return '';
  final local = published.toLocal();
  return '${local.year}年${local.month}月${local.day}日上架';
}

class TemplateMarketDetail extends StatefulWidget {
  const TemplateMarketDetail({
    super.key,
    required this.market,
    required this.template,
    required this.onUseTemplate,
  });
  final TemplateMarketStore market;
  final Map<String, dynamic> template;
  final void Function(BuildContext context, Map<String, dynamic> template)
  onUseTemplate;
  @override
  State<TemplateMarketDetail> createState() => _TemplateMarketDetailState();
}

class _TemplateMarketDetailState extends State<TemplateMarketDetail>
    with SingleTickerProviderStateMixin {
  late Map<String, dynamic> design = {...widget.template};
  late final purchaseKey = 'template-${widget.template['id']}-${newDeviceID()}';
  bool loading = true, detailsReady = false, busy = false, previewOpen = false;
  bool previewTransitioning = false, closePreviewRequested = false;
  late final previewTransition = AnimationController(
    vsync: this,
    value: 1,
    duration: const Duration(milliseconds: 220),
    reverseDuration: const Duration(milliseconds: 90),
  );
  late final previewOpacity = CurvedAnimation(
    parent: previewTransition,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  late final previewSlide = Tween<Offset>(
    begin: const Offset(0, 0.012),
    end: Offset.zero,
  ).animate(previewOpacity);
  int previewPage = 0;
  String? error;
  int? balance;
  int operation = 0;
  TemplateMarketStore get market => widget.market;
  int get id => integer(widget.template['id']);
  bool get acquired => market.ownedIDs.contains(id);
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final request = ++operation;
    setState(() {
      loading = true;
      detailsReady = false;
      error = null;
      balance = null;
    });
    try {
      final ownership = Future<void>.microtask(market.loadOwned);
      final response = await market.store.request(
        'GetTemplatesId',
        path: {'id': '$id'},
      );
      if (!mounted || request != operation || !market.valid) return;
      final data = {...widget.template, ...response.data};
      setState(() {
        design = data;
        detailsReady = true;
      });
      // Preview can render while ownership and balance are checked. Acquisition
      // remains disabled by `loading` until those checks finish successfully.
      await ownership;
      if (!mounted || request != operation) return;
      if (!market.valid) throw const ApiFailure('登录状态已变化，请返回后重试');
      if (market.ownedError != null) throw ApiFailure(market.ownedError!);
      if (integer(data['price_points']) > 0 && !acquired) {
        final wallet = await market.store.request('GetWallet');
        if (wallet.data['available_points'] == null) {
          throw const ApiFailure('积分余额暂不可用，请重试');
        }
        balance = integer(wallet.data['available_points']);
      }
    } catch (e) {
      if (mounted && request == operation) {
        setState(() => error = e is ApiFailure ? e.message : '模板详情加载失败');
      }
    } finally {
      if (mounted && request == operation) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> acquire() async {
    if (loading || busy || error != null) return;
    if (acquired) {
      widget.onUseTemplate(context, design);
      return;
    }
    final price = integer(design['price_points']);
    if (price > 0) {
      final confirmed = await showAppConfirmation(
        context,
        title: '兑换模板',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${design['name']}'),
            const SizedBox(height: 12),
            Text('本次使用 $price 积分'),
            const SizedBox(height: 8),
            Text('当前余额：${balance ?? 0} 积分'),
          ],
        ),
        confirmEnabled: balance != null && balance! >= price,
        confirmLabel: balance != null && balance! >= price ? '确认兑换' : '积分不足',
      );
      if (confirmed != true || !mounted || !market.valid) return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await market.acquire(
        id: id,
        quotedPrice: price,
        quotedRevision: integer(design['revision']),
        idempotencyKey: purchaseKey,
      );
      if (mounted && market.valid) {
        setState(() => balance = market.store.points);
        toast(context, '获取成功');
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e is ApiFailure ? e.message : '获取失败，请重试');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String get usageLabel {
    final count = int.tryParse('${design['usage_count'] ?? ''}');
    if (count == null || count < 0) {
      return loading ? '正在加载使用人数' : '使用人数暂不可用';
    }
    return '$count 人在用';
  }

  bool get canAcquire =>
      !loading &&
      !busy &&
      error == null &&
      market.valid &&
      (acquired || design['status'] == 'PUBLISHED') &&
      design['compatible'] == true;

  void openPreview(int page) {
    if (previewOpen || previewTransitioning || !mounted || !market.valid) {
      return;
    }
    unawaited(transitionPreview(true, page));
  }

  void closePreview() {
    if (previewTransitioning) {
      closePreviewRequested = true;
      return;
    }
    if (previewOpen) unawaited(transitionPreview(false, previewPage));
  }

  Future<void> transitionPreview(bool expanded, int page) async {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    setState(() => previewTransitioning = true);
    try {
      if (!reduceMotion) await previewTransition.reverse().orCancel;
      if (!mounted) return;
      setState(() {
        previewPage = page;
        previewOpen = expanded;
      });
      if (!reduceMotion) {
        // Change the native viewport once, while hidden. Allow its resize and
        // page positioning to settle before revealing it; don't resize per tick.
        await WidgetsBinding.instance.endOfFrame;
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        await previewTransition.forward().orCancel;
      }
    } on TickerCanceled {
      // Leaving the screen disposes the active transition.
    } finally {
      if (mounted) {
        setState(() => previewTransitioning = false);
        if (closePreviewRequested) {
          closePreviewRequested = false;
          closePreview();
        }
      }
    }
  }

  @override
  void dispose() {
    previewOpacity.dispose();
    previewTransition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: market,
    builder: (context, _) => PopScope(
      canPop: !previewOpen && !previewTransitioning,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && (previewOpen || previewTransitioning)) closePreview();
      },
      child: Scaffold(
        backgroundColor: context.colors.surface,
        appBar: AppPageBar(
          leading: IconButton(
            tooltip: previewOpen ? '返回模板详情' : '返回',
            onPressed: () {
              if (previewOpen || previewTransitioning) {
                closePreview();
              } else {
                Navigator.of(context).maybePop();
              }
            },
            icon: AppIcon(AppIcons.back, size: 22, color: context.colors.ink),
          ),
          title: Text(
            '${design['name'] ?? '简历模板'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: IgnorePointer(
          ignoring: previewTransitioning,
          child: FadeTransition(
            key: const ValueKey('template-preview-transition'),
            opacity: previewOpacity,
            child: SlideTransition(
              position: previewSlide,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: previewOpen ? double.infinity : 860,
                      ),
                      child: Padding(
                        padding: previewOpen
                            ? EdgeInsets.only(bottom: bottomInset)
                            : const EdgeInsets.fromLTRB(
                                appPageHorizontalPadding,
                                10,
                                appPageHorizontalPadding,
                                0,
                              ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  final info = Padding(
                                    key: const ValueKey('template-detail-info'),
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (!previewOpen) ...[
                                          Row(
                                            children: [
                                              const ProfileAvatar(
                                                key: ValueKey(
                                                  'template-publisher-avatar',
                                                ),
                                                seed: 'official',
                                                url: '',
                                                size: 30,
                                                borderRadius: 15,
                                              ),
                                              const SizedBox(width: 9),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      officialTemplatePublisher,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        height: 1.4,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color:
                                                            context.colors.ink,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 3),
                                                    DefaultTextStyle.merge(
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        height: 1.25,
                                                        color: context
                                                            .colors
                                                            .muted,
                                                      ),
                                                      child: Wrap(
                                                        spacing: 10,
                                                        runSpacing: 3,
                                                        children: [
                                                          Text(
                                                            usageLabel,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: [
                                              for (final chip in [
                                                integer(
                                                          design['price_points'],
                                                        ) ==
                                                        0
                                                    ? '免费'
                                                    : '${integer(design['price_points'])} 积分',
                                                if (acquired) '已获取',
                                                if (_publishedLabel(design)
                                                    .isNotEmpty)
                                                  _publishedLabel(design),
                                              ])
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: context.colors.inset,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    chip,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          context.colors.muted,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                        if (!previewOpen) ...[
                                          const SizedBox(height: 24),
                                          Text(
                                            '关于这个模板',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: context.colors.ink,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '${design['description'] ?? ''}'
                                                    .trim()
                                                    .isEmpty
                                                ? '暂无介绍'
                                                : '${design['description']}'
                                                      .trim(),
                                            style: TextStyle(
                                              fontSize: 13,
                                              height: 1.7,
                                              color: context.colors.muted,
                                            ),
                                          ),
                                        ],
                                        if (!previewOpen && error != null) ...[
                                          const SizedBox(height: 16),
                                          Text(
                                            error!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              height: 1.5,
                                              color: context.colors.muted,
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: busy ? null : load,
                                            child: const Text('重试'),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                  final header = previewOpen ? null : info;
                                  return !detailsReady && loading
                                      ? PreviewWithHeader(
                                          header: header,
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        )
                                      : detailsReady &&
                                            design['compatible'] == true &&
                                            market.valid
                                      ? TemplateLivePreview(
                                          key: ValueKey(
                                            'preview-$id-$operation',
                                          ),
                                          store: market.store,
                                          templateID: id,
                                          version: integer(design['version']),
                                          watermark: '未经授权，商用追责',
                                          fullscreen: previewOpen,
                                          header: header,
                                          initialPage: previewPage,
                                        )
                                      : PreviewWithHeader(
                                          header: header,
                                          child: Center(
                                            child: Padding(
                                              padding: const EdgeInsets.all(24),
                                              child: Text(
                                                error ?? '模板正在准备，暂时无法预览',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: context.colors.muted,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        bottomNavigationBar: previewOpen
            ? null
            : IgnorePointer(
                ignoring: previewTransitioning,
                child: FadeTransition(
                  opacity: previewOpacity,
                  child: BottomActionBar(
                    maxWidth: 860,
                    child: Row(
                      children: [
                        if (!acquired) ...[
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (integer(design['price_points']) == 0)
                                  const Text(
                                    '免费',
                                    style: TextStyle(
                                      fontSize: 18,
                                      height: 1.3,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF13A58C),
                                    ),
                                  )
                                else
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: _PointsPrice(
                                      points: integer(design['price_points']),
                                      size: 20,
                                    ),
                                  ),
                                if (balance != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '我的积分 $balance',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.colors.muted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                        Expanded(
                          flex: acquired ? 1 : 2,
                          child: FilledButton(
                            onPressed: canAcquire ? acquire : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: context.colors.accent,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 46),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              busy
                                  ? '正在处理…'
                                  : acquired
                                  ? '使用模板'
                                  : integer(design['price_points']) == 0
                                  ? '免费获取'
                                  : '积分兑换',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    ),
  );
}
