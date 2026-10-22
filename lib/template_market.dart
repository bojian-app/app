import 'user_display_name.dart';
import 'playful_refresh.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import 'api/bojian_api.dart';
import 'app_icons.dart';
import 'app_store.dart';
import 'design.dart';
import 'confirmation_dialog.dart';
import 'template_market_store.dart';
import 'template_live_preview.dart';
import 'profile_avatar.dart';

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

class _TemplateMarketViewState extends State<TemplateMarketView> {
  late final market = TemplateMarketStore(widget.store);
  final search = TextEditingController();
  @override
  void initState() {
    super.initState();
    market.refresh();
  }

  @override
  void dispose() {
    search.dispose();
    market.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: market,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('模板市场'),
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: context.colors.ink,
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: TextField(
              controller: search,
              maxLength: 100,
              onChanged: market.search,
              onSubmitted: (value) => market.search(value, immediately: true),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: market.filter == TemplateMarketFilter.owned
                    ? '搜索已获取模板'
                    : '搜索模板或作者',
                counterText: '',
                filled: true,
                fillColor: (context.isDark
                    ? context.colors.accentSoft
                    : const Color(0xFFEDF0F5)),
                prefixIcon: Padding(
                  padding: EdgeInsets.all(13),
                  child: AppIcon(
                    AppIcons.search,
                    size: 20,
                    color: context.colors.muted,
                  ),
                ),
                suffixIcon: search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清空搜索',
                        onPressed: () {
                          search.clear();
                          market.search('', immediately: true);
                        },
                        icon: AppIcon(
                          AppIcons.clear,
                          size: 18,
                          color: context.colors.muted,
                        ),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: SingleChildScrollView(
              key: const ValueKey('template-market-filters'),
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final filter in TemplateMarketFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          filter.label,
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: market.filter == filter,
                        showCheckmark: false,
                        selectedColor: (context.isDark
                            ? context.colors.accentSoft
                            : const Color(0xFFE4EDFF)),
                        backgroundColor: context.colors.surface,
                        side: BorderSide(
                          color: market.filter == filter
                              ? const Color(0xFFB6CCFF)
                              : context.colors.border,
                        ),
                        onSelected: (_) {
                          FocusManager.instance.primaryFocus?.unfocus();
                          market.select(filter);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
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
                    physics: const AlwaysScrollableScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      if (!own && market.ownedError != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
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
                          hasScrollBody: false,
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
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          sliver: SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: constraints.maxWidth >= 1000
                                      ? 5
                                      : constraints.maxWidth >= 700
                                      ? 4
                                      : constraints.maxWidth >= 500
                                      ? 3
                                      : 2,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: .59,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
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
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
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
                                  onPressed: () => market.load(
                                    more: market.cursor.isNotEmpty,
                                  ),
                                  child: const Text('重新加载'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (!own &&
                          rows.isNotEmpty &&
                          market.cursor.isNotEmpty &&
                          failure == null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Center(
                              child: market.loadingMore
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : TextButton(
                                      onPressed: () => market.load(more: true),
                                      child: const Text('加载更多'),
                                    ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
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
  Widget build(BuildContext context) => Center(
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                child: TextButton(onPressed: retry, child: const Text('重新加载')),
              ),
          ],
        ],
      ),
    ),
  );
}

class MarketTemplateArtwork extends StatelessWidget {
  const MarketTemplateArtwork({super.key, required this.template});
  final Map<String, dynamic> template;
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
        : Image.network(
            url,
            cacheWidth: 720,
            fit: BoxFit.contain,
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

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.acquired,
    required this.onTap,
  });
  final Map<String, dynamic> template;
  final bool acquired;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: context.colors.surface,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: context.colors.border),
    ),
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: (context.isDark
                        ? context.colors.accentSoft
                        : const Color(0xFFF0F3F8)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: AspectRatio(
                        aspectRatio: 595.28 / 841.89,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x0C172B4D),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: MarketTemplateArtwork(template: template),
                        ),
                      ),
                    ),
                  ),
                ),
                if (acquired)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (context.isDark
                            ? context.colors.accentSoft
                            : const Color(0xFFE8F5EF)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '已获取',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF39816B),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${template['name']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    userDisplayName(template['creator_name']),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: context.colors.muted),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  integer(template['price_points']) == 0
                      ? '免费'
                      : '${template['price_points']} 积分',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.colors.accent,
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
  bool loading = true, busy = false, previewOpen = false;
  final detailScroll = ScrollController();
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
  double inlineScrollOffset = 0;
  int previewPage = 0;
  String? error;
  int? balance;
  int operation = 0;
  Map<String, dynamic> creator = {};
  TemplateMarketStore get market => widget.market;
  int get id => integer(widget.template['id']);
  bool get acquired => market.ownedIDs.contains(id);
  bool get authored => market.authored.contains(id);
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final request = ++operation;
    setState(() {
      loading = true;
      error = null;
      balance = null;
      creator = {};
    });
    try {
      final response = await market.store.request(
        'GetTemplatesId',
        path: {'id': '$id'},
      );
      await market.loadOwned();
      if (!market.valid) throw const ApiFailure('登录状态已变化，请返回后重试');
      if (market.ownedError != null) throw ApiFailure(market.ownedError!);
      final data = {...widget.template, ...response.data};
      if (integer(data['price_points']) > 0 && !acquired && !authored) {
        final wallet = await market.store.request('GetWallet');
        if (wallet.data['available_points'] == null) {
          throw const ApiFailure('积分余额暂不可用，请重试');
        }
        balance = integer(wallet.data['available_points']);
      }
      if (mounted && request == operation && market.valid) {
        setState(() => design = data);
        unawaited(loadCreator(data, request));
      }
    } catch (e) {
      if (mounted && request == operation) {
        setState(() => error = e is ApiFailure ? e.message : '模板详情加载失败');
      }
    } finally {
      if (mounted && request == operation) setState(() => loading = false);
    }
  }

  Future<void> acquire() async {
    if (loading || busy || error != null) return;
    if (acquired) {
      widget.onUseTemplate(context, design);
      return;
    }
    final price = integer(design['price_points']);
    if (price > 0 && !authored) {
      final confirmed = await showAppConfirmation(
        context,
        title: '购买模板',
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
        confirmLabel: balance != null && balance! >= price ? '确认购买' : '积分不足',
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

  Future<void> loadCreator(Map<String, dynamic> data, int request) async {
    final creatorID = integer(data['creator_id']);
    if (creatorID <= 0) return;
    try {
      final response = await market.store.request(
        'GetTemplateAuthorsId',
        path: {'id': '$creatorID'},
      );
      if (mounted && request == operation && market.valid) {
        setState(() => creator = response.data);
      }
    } catch (_) {
      // An unavailable/private profile must not block preview or acquisition.
      // Refreshing details also refreshes the avatar's signed URL.
    }
  }

  String get authorName {
    final nickname = '${creator['nickname'] ?? ''}'.trim();
    if (nickname.isNotEmpty) return nickname;
    final name = '${design['creator_name'] ?? ''}'.trim();
    return name.isNotEmpty && name != '模板作者' ? name : userDisplayName(null);
  }

  String get authorAvatar {
    final url = '${creator['avatar_url'] ?? ''}'.trim();
    return url.isNotEmpty
        ? url
        : authored
        ? market.store.avatarURL
        : '';
  }

  String get authorProvince =>
      '${creator['city'] ?? ''}'.trim().replaceFirst(RegExp(r'省$'), '');

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
    inlineScrollOffset = detailScroll.hasClients ? detailScroll.offset : 0;
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
      restoreDetailScroll(expanded ? 0 : inlineScrollOffset);
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

  void restoreDetailScroll(double offset) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !detailScroll.hasClients) return;
      detailScroll.jumpTo(
        offset.clamp(0, detailScroll.position.maxScrollExtent),
      );
    });
  }

  @override
  void dispose() {
    previewOpacity.dispose();
    previewTransition.dispose();
    detailScroll.dispose();
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
        appBar: AppBar(
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
          backgroundColor: context.colors.surface,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleSpacing: 0,
          titleTextStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: context.colors.ink,
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
                  final previewHeight = previewOpen
                      ? (constraints.maxHeight - bottomInset).clamp(
                          0.0,
                          double.infinity,
                        )
                      : (constraints.maxHeight - 100).clamp(350.0, 760.0);
                  return SingleChildScrollView(
                    controller: detailScroll,
                    physics: previewOpen
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: previewOpen ? double.infinity : 860,
                        ),
                        child: Padding(
                          padding: previewOpen
                              ? EdgeInsets.only(bottom: bottomInset)
                              : const EdgeInsets.fromLTRB(20, 10, 20, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Keep the preview's element path stable when expanding:
                              // recreating its WebView repeats font loading and pagination.
                              Visibility(
                                visible: !previewOpen,
                                maintainState: true,
                                child: Row(
                                  children: [
                                    ProfileAvatar(
                                      key: const ValueKey(
                                        'template-author-avatar',
                                      ),
                                      seed:
                                          '${creator['public_id'] ?? design['creator_id'] ?? authorName}',
                                      url: authorAvatar,
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
                                            authorName,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              height: 1.4,
                                              fontWeight: FontWeight.w500,
                                              color: context.colors.ink,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          DefaultTextStyle.merge(
                                            style: TextStyle(
                                              fontSize: 10,
                                              height: 1.25,
                                              color: context.colors.muted,
                                            ),
                                            child: Wrap(
                                              spacing: 10,
                                              runSpacing: 3,
                                              children: [
                                                if (authorProvince.isNotEmpty)
                                                  Text(
                                                    'IP属地：$authorProvince',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                Text(
                                                  usageLabel,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: previewOpen ? 0 : 20),
                              SizedBox(
                                height: previewHeight,
                                child: loading
                                    ? const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : design['compatible'] == true &&
                                          market.valid
                                    ? TemplateLivePreview(
                                        key: ValueKey('preview-$id-$operation'),
                                        store: market.store,
                                        templateID: id,
                                        version: integer(design['version']),
                                        author: authorName,
                                        onOpenPage: openPreview,
                                        fullscreen: previewOpen,
                                        initialPage: previewPage,
                                      )
                                    : Center(
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
                              ),
                              if (!previewOpen &&
                                  '${design['description'] ?? ''}'
                                      .trim()
                                      .isNotEmpty) ...[
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
                                  '${design['description']}',
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
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      border: Border(
                        top: BorderSide(color: context.colors.border),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Center(
                        heightFactor: 1,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 860),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                            child: Row(
                              children: [
                                if (!acquired) ...[
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          authored ||
                                                  integer(
                                                        design['price_points'],
                                                      ) ==
                                                      0
                                              ? '免费'
                                              : '${design['price_points']} 积分',
                                          style: TextStyle(
                                            fontSize: 18,
                                            height: 1.3,
                                            fontWeight: FontWeight.w600,
                                            color: context.colors.ink,
                                          ),
                                        ),
                                        if (balance != null && !authored) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            '余额 $balance 积分',
                                            style: TextStyle(
                                              fontSize: 11,
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
                                          : authored ||
                                                integer(
                                                      design['price_points'],
                                                    ) ==
                                                    0
                                          ? '免费获取'
                                          : '积分购买',
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
                ),
              ),
      ),
    ),
  );
}
