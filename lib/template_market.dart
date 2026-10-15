import 'user_display_name.dart';
import 'playful_refresh.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import 'api/bojian_api.dart';
import 'app_icons.dart';
import 'app_store.dart';
import 'design.dart';
import 'template_market_store.dart';

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
        titleTextStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: ink,
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
                fillColor: const Color(0xFFEDF0F5),
                prefixIcon: const Padding(
                  padding: EdgeInsets.all(13),
                  child: AppIcon(AppIcons.search, size: 20, color: muted),
                ),
                suffixIcon: search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清空搜索',
                        onPressed: () {
                          search.clear();
                          market.search('', immediately: true);
                        },
                        icon: const AppIcon(
                          AppIcons.clear,
                          size: 18,
                          color: muted,
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
                      selectedColor: const Color(0xFFE4EDFF),
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: market.filter == filter
                            ? const Color(0xFFB6CCFF)
                            : borderColor,
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
                                const Expanded(
                                  child: Text(
                                    '购买状态暂时无法同步',
                                    style: TextStyle(
                                      color: muted,
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
                                  style: const TextStyle(
                                    color: muted,
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
            const AppIcon(AppIcons.templateMarket, size: 32, color: muted),
            const SizedBox(height: 16),
            Text(
              error == null ? title : '模板加载失败',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              error ?? subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontSize: 12, height: 1.6),
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
          const AppIcon(AppIcons.templatePreview, size: 28, color: muted),
          const SizedBox(height: 8),
          Text(
            pending ? '预览生成中' : '预览暂不可用',
            style: const TextStyle(fontSize: 10, color: muted),
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
    color: Colors.white,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: borderColor),
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
                    color: const Color(0xFFF0F3F8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: AspectRatio(
                        aspectRatio: 595.28 / 841.89,
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
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
                        color: const Color(0xFFE8F5EF),
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
                    style: const TextStyle(fontSize: 10, color: muted),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  integer(template['price_points']) == 0
                      ? '免费'
                      : '${template['price_points']} 积分',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: blue,
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

class _TemplateMarketDetailState extends State<TemplateMarketDetail> {
  late Map<String, dynamic> design = {...widget.template};
  late final purchaseKey = 'template-${widget.template['id']}-${newDeviceID()}';
  bool loading = true, busy = false;
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
      error = null;
      balance = null;
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
      if (integer(data['price_points']) > 0 &&
          !acquired &&
          !market.authored.contains(id)) {
        final wallet = await market.store.request('GetWallet');
        if (wallet.data['available_points'] == null) {
          throw const ApiFailure('积分余额暂不可用，请重试');
        }
        balance = integer(wallet.data['available_points']);
      }
      try {
        final preview = await market.store.request(
          'GetTemplatesIdPreviewAssets',
          path: {'id': '$id'},
        );
        data.addAll(preview.data);
      } catch (_) {
        /* Retain catalogue preview if assets are still generating. */
      }
      if (mounted && request == operation && market.valid) {
        setState(() => design = data);
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
    if (price > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('购买模板'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${design['name']}'),
              const SizedBox(height: 16),
              Text(
                '本次使用 $price 积分',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                '当前余额：${balance ?? 0} 积分',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: balance != null && balance! >= price
                  ? () => Navigator.pop(context, true)
                  : null,
              child: Text(
                balance != null && balance! >= price ? '确认购买' : '积分不足',
              ),
            ),
          ],
        ),
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
        toast(context, '模板已加入我的模板');
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e is ApiFailure ? e.message : '获取失败，请重试');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: market,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('模板详情'),
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        actions: [
          IconButton(
            tooltip: '刷新详情',
            onPressed: loading || busy ? null : load,
            icon: const AppIcon(AppIcons.refresh, size: 20),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final preview = Column(
                    children: [
                      SizedBox(
                        width: constraints.maxWidth >= 650 ? 280 : 232,
                        child: AspectRatio(
                          aspectRatio: 595.28 / 841.89,
                          child: Material(
                            color: Colors.white,
                            elevation: 1,
                            child: MarketTemplateArtwork(template: design),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => _TemplateZoom(template: design),
                          ),
                        ),
                        child: const Text('查看大图'),
                      ),
                    ],
                  );
                  final information = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${design['name']}',
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '作者 · ${userDisplayName(design['creator_name'])}',
                        style: const TextStyle(fontSize: 12, color: muted),
                      ),
                      const SizedBox(height: 16),
                      if ('${design['description'] ?? ''}'.trim().isNotEmpty)
                        Text(
                          '${design['description']}',
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.7,
                            color: ink,
                          ),
                        ),
                      if (acquired)
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: Text(
                            '已加入我的模板',
                            style: TextStyle(
                              color: Color(0xFF39816B),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      if (balance != null && !acquired)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            '积分余额 ${balance!}',
                            style: const TextStyle(color: muted, fontSize: 12),
                          ),
                        ),
                      if (!loading &&
                          error == null &&
                          design['compatible'] != true)
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: Text(
                            '模板正在准备，暂时无法获取',
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                        ),
                      if (loading)
                        const Padding(
                          padding: EdgeInsets.only(top: 20),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                error!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                              TextButton(
                                onPressed: busy ? null : load,
                                child: const Text('刷新后重试'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                  return constraints.maxWidth >= 650
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: preview),
                            const SizedBox(width: 28),
                            Expanded(child: information),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(child: preview),
                            const SizedBox(height: 12),
                            information,
                          ],
                        );
                },
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      acquired
                          ? '已获取'
                          : integer(design['price_points']) == 0
                          ? '免费'
                          : '${design['price_points']} 积分',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: blue,
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed:
                        loading ||
                            busy ||
                            error != null ||
                            !market.valid ||
                            market.authored.contains(id) ||
                            design['compatible'] != true
                        ? null
                        : acquire,
                    child: Text(
                      busy
                          ? '正在处理…'
                          : market.authored.contains(id)
                          ? '自己发布的模板'
                          : acquired
                          ? '使用模板'
                          : integer(design['price_points']) == 0
                          ? '免费获取'
                          : '积分购买',
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

class _TemplateZoom extends StatelessWidget {
  const _TemplateZoom({required this.template});
  final Map<String, dynamic> template;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('${template['name']}', style: const TextStyle(fontSize: 16)),
    ),
    body: InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: AspectRatio(
            aspectRatio: 595.28 / 841.89,
            child: ColoredBox(
              color: Colors.white,
              child: MarketTemplateArtwork(template: template),
            ),
          ),
        ),
      ),
    ),
  );
}
