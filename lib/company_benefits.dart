import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api/bojian_api.dart';
import 'app_icons.dart';
import 'app_store.dart';
import 'company_benefits_art.dart';
import 'date_wheel_picker.dart';
import 'design.dart';
import 'playful_refresh.dart';

const benefitLabels = {
  'salary': '薪资结构',
  'insurance': '五险一金',
  'hours': '工作时间',
  'leave': '休假制度',
  'bonus': '奖金与激励',
  'allowance': '补贴与关怀',
  'growth': '成长与培训',
  'other': '其他福利',
};
const benefitStatuses = {
  'PENDING': '审核中',
  'NEEDS_MORE': '待补充公开来源',
  'APPROVED': '已收录',
  'REJECTED': '未通过',
};
Map<String, dynamic> benefitMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

Uri? benefitSourceUri(String value) {
  final raw = value.trim();
  final uri = Uri.tryParse(raw);
  final authority = RegExp(
    r'^https?://([^/?#]*)',
    caseSensitive: false,
  ).firstMatch(raw)?.group(1);
  if (value.length > 2048 ||
      value.contains(RegExp(r'[\\\r\n\t]')) ||
      authority == null ||
      authority.isEmpty ||
      authority.contains('@') ||
      authority.contains('%') ||
      authority.endsWith(':') ||
      uri == null ||
      !['https', 'http'].contains(uri.scheme) ||
      !uri.hasAuthority ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
  if (host.length > 253 ||
      !RegExp(r'^[a-z0-9-]+(?:\.[a-z0-9-]+)+$').hasMatch(host) ||
      RegExp(r'^(?:[0-9]+|0x[0-9a-f]+|0b[01]+|0o[0-7]+)$')
          .hasMatch(host.split('.').last) ||
      host
          .split('.')
          .any(
            (label) =>
                label.length > 63 ||
                label.startsWith('-') ||
                label.endsWith('-'),
          ) ||
      [
        'localhost',
        'local',
        'internal',
        'intranet',
        'lan',
        'home',
        'home.arpa',
        'test',
        'invalid',
        'example',
      ].any((suffix) => host == suffix || host.endsWith('.$suffix'))) {
    return null;
  }
  try {
    if (uri.hasPort && (uri.port < 1 || uri.port > 65535)) return null;
  } on FormatException {
    return null;
  }
  return uri;
}

String? validateBenefitReportDescription(String value) {
  final text = value.trim();
  if (text.length < 10) return '请至少填写10字说明';
  if (utf8.encode(text).length > 1000) return '说明内容过长，请减少文字或表情';
  return null;
}

bool hasReviewedBenefitSources(Map<String, dynamic> item) {
  if (DateTime.tryParse('${item['source_reviewed_at'] ?? ''}') == null) {
    return false;
  }
  final content = benefitMap(item['content']);
  final benefits = benefitMap(content['benefits']);
  final sources = benefitMap(content['sources']);
  return benefits.isNotEmpty &&
      benefits.keys.every((key) {
        final source = benefitMap(sources[key]);
        return benefitLabels.containsKey(key) &&
            benefitSourceUri('${source['url'] ?? ''}') != null &&
            '${source['publisher'] ?? ''}'.trim().isNotEmpty;
      });
}

class CompanyBenefitsPage extends StatefulWidget {
  const CompanyBenefitsPage({
    super.key,
    required this.store,
    this.mine = false,
    this.standalone = false,
  });
  final AppStore store;
  final bool mine;
  final bool standalone;
  @override
  State<CompanyBenefitsPage> createState() => _CompanyBenefitsPageState();
}

class _CompanyBenefitsPageState extends State<CompanyBenefitsPage> {
  final search = TextEditingController();
  final city = TextEditingController();
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? error;
  String? cursor;
  String appliedSearch = '';
  String appliedCity = '';
  int generation = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    city.dispose();
    super.dispose();
  }

  Future<void> load({bool more = false}) async {
    if (more && (loading || cursor == null)) return;
    final version = ++generation;
    final requestSearch = more ? appliedSearch : search.text.trim();
    final requestCity = more ? appliedCity : city.text.trim();
    setState(() {
      loading = true;
      error = null;
      if (!more) {
        if (requestSearch != appliedSearch || requestCity != appliedCity) {
          items = [];
          cursor = null;
        }
        appliedSearch = requestSearch;
        appliedCity = requestCity;
      }
    });
    try {
      final result = await widget.store.request(
        widget.mine ? 'GetMeCompanyBenefitSubmissions' : 'GetCompanyBenefits',
        query: {
          if (!widget.mine) 'query': requestSearch,
          if (!widget.mine) 'city': requestCity,
          if (more && cursor != null) 'cursor': cursor!,
        },
      );
      if (!mounted || version != generation) return;
      final next = (result.data['items'] as List? ?? [])
          .map(benefitMap)
          .where((item) => widget.mine || hasReviewedBenefitSources(item))
          .toList();
      setState(() {
        items = more ? [...items, ...next] : next;
        cursor = result.data['next_cursor']?.toString();
      });
    } catch (e) {
      if (mounted && version == generation) {
        setState(() => error = e is ApiFailure ? e.message : '加载失败，请重试');
      }
    } finally {
      if (mounted && version == generation) setState(() => loading = false);
    }
  }

  Future<void> open(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) await load();
  }

  Future<void> filterCity() async {
    dismissKeyboard();
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _BenefitCitySheet(initialCity: city.text),
    );
    if (!mounted || selected == null) return;
    city.text = selected;
    await load();
  }

  void clearFilters() {
    search.clear();
    city.clear();
    dismissKeyboard();
    load();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = appliedSearch.isNotEmpty || appliedCity.isNotEmpty;
    final body = LayoutBuilder(
      builder: (context, viewport) => Column(
        children: [
          if (!widget.mine)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: viewport.maxHeight * .5),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!widget.standalone)
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '企业福利',
                                style: TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w700,
                                  color: ink,
                                ),
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF617086),
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => open(
                                CompanyBenefitsPage(
                                  store: widget.store,
                                  mine: true,
                                ),
                              ),
                              child: const Text(
                                '我的提交',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      if (MediaQuery.sizeOf(context).height > 440) ...[
                        const SizedBox(height: 8),
                        const Text(
                          '了解待遇，选择适合自己的工作',
                          style: TextStyle(
                            color: muted,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      TextField(
                        key: const ValueKey('benefit-search'),
                        controller: search,
                        textInputAction: TextInputAction.search,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) {
                          dismissKeyboard();
                          load();
                        },
                        decoration: InputDecoration(
                          hintText: '搜索企业名称',
                          fillColor: Colors.white,
                          prefixIcon: const Padding(
                            padding: EdgeInsets.all(15),
                            child: AppIcon(
                              AppIcons.search,
                              size: 20,
                              color: muted,
                            ),
                          ),
                          suffixIcon: search.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: '清空搜索',
                                  onPressed: () {
                                    search.clear();
                                    dismissKeyboard();
                                    load();
                                  },
                                  icon: const AppIcon(
                                    AppIcons.clear,
                                    size: 18,
                                    color: muted,
                                  ),
                                ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: blue.withValues(alpha: .25),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Flexible(
                            child: TextButton(
                              key: const ValueKey('benefit-city-filter'),
                              onPressed: filterCity,
                              style: TextButton.styleFrom(
                                foregroundColor: ink,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                  vertical: 10,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AppIcon(
                                    AppIcons.location,
                                    size: 16,
                                    color: city.text.isEmpty ? muted : blue,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      city.text.isEmpty ? '全国' : city.text,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const AppIcon(
                                    AppIcons.expand,
                                    size: 12,
                                    color: muted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () =>
                                showBenefitCollectionRules(context),
                            style: TextButton.styleFrom(foregroundColor: muted),
                            child: const Text(
                              '收录规则',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final emptyHeight = max(360.0, constraints.maxHeight - 28);
                return PlayfulRefresh(
                  onRefresh: load,
                  hasError: () => error != null,
                  child: ListView(
                    key: const ValueKey('benefit-results'),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
                    children: [
                      if (loading && items.isEmpty)
                        SizedBox(
                          height: emptyHeight,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      if (error != null && items.isEmpty)
                        SizedBox(
                          height: emptyHeight,
                          child: _BenefitEmptyState(
                            title: '暂时没能加载',
                            subtitle: error!,
                            action: '重新加载',
                            onAction: load,
                          ),
                        ),
                      if (!loading && error == null && items.isEmpty)
                        SizedBox(
                          height: emptyHeight,
                          child: _BenefitEmptyState(
                            title: widget.mine
                                ? '还没有提交记录'
                                : filtered
                                ? '没有找到相关企业'
                                : '企业福利正在收录',
                            subtitle: widget.mine
                                ? '推荐的企业与收录进度，会显示在这里。'
                                : filtered
                                ? '试试其他企业名称，或切换城市。'
                                : '发现企业公开的福利信息？\n分享来源，帮助大家了解更多。',
                            action: filtered && !widget.mine
                                ? '清除筛选'
                                : '推荐一家企业',
                            onAction: filtered && !widget.mine
                                ? clearFilters
                                : () => open(
                                    BenefitSubmissionPage(store: widget.store),
                                  ),
                          ),
                        ),
                      for (final item in items)
                        _BenefitCard(
                          item: item,
                          mine: widget.mine,
                          onTap: () => open(
                            BenefitDetailPage(
                              store: widget.store,
                              id: item['id'].toString(),
                              mine: widget.mine,
                            ),
                          ),
                        ),
                      if (items.isNotEmpty && error != null)
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: TextButton(
                            onPressed: load,
                            child: Text('$error · 重试'),
                          ),
                        ),
                      if (cursor != null)
                        TextButton(
                          onPressed: loading ? null : () => load(more: true),
                          child: Text(loading ? '加载中…' : '查看更多'),
                        ),
                      if (items.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Center(
                            child: TextButton.icon(
                              onPressed: () => open(
                                BenefitSubmissionPage(store: widget.store),
                              ),
                              icon: const AppIcon(AppIcons.add, size: 16),
                              label: const Text('推荐一家企业'),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
    if (widget.mine) {
      return Scaffold(
        appBar: AppBar(title: const Text('我的提交')),
        body: body,
      );
    }
    if (widget.standalone) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('企业福利'),
          actions: [
            TextButton(
              onPressed: () =>
                  open(CompanyBenefitsPage(store: widget.store, mine: true)),
              child: const Text('我的提交'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: body,
            ),
          ),
        ),
      );
    }
    return body;
  }
}

Future<void> showBenefitCollectionRules(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '收录规则',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '只收录企业合法公开的信息',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                '请提供企业官网、官方招聘公告等公开来源。每项福利都要有对应依据，并注明适用岗位、地区和日期。',
                style: TextStyle(color: muted, fontSize: 13, height: 1.8),
              ),
              const SizedBox(height: 18),
              const Text(
                '内部资料请勿提交',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                '不接收劳动合同、工资明细、未公开制度、内网或员工群资料，也不以匿名泄漏链接作为收录依据。平台会另行核验公开来源。',
                style: TextStyle(color: muted, fontSize: 13, height: 1.8),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('知道了'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

class _BenefitCitySheet extends StatefulWidget {
  const _BenefitCitySheet({required this.initialCity});
  final String initialCity;
  @override
  State<_BenefitCitySheet> createState() => _BenefitCitySheetState();
}

class _BenefitCitySheetState extends State<_BenefitCitySheet> {
  late final controller = TextEditingController(text: widget.initialCity);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      24,
      24,
      MediaQuery.viewInsetsOf(context).bottom +
          MediaQuery.paddingOf(context).bottom +
          24,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '筛选城市',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          TextField(
            key: const ValueKey('benefit-city-input'),
            controller: controller,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: '输入完整城市名称，如：杭州市'),
            onSubmitted: (_) => Navigator.pop(context, controller.text.trim()),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in const {
                '全国': '',
                '北京': '北京市',
                '上海': '上海市',
                '广州': '广州市',
                '深圳': '深圳市',
                '杭州': '杭州市',
                '成都': '成都市',
              }.entries)
                ChoiceChip(
                  label: Text(entry.key),
                  selected: controller.text == entry.value,
                  onSelected: (_) =>
                      setState(() => controller.text = entry.value),
                  selectedColor: const Color(0xFFEAF1FF),
                  side: BorderSide.none,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: controller.text == entry.value ? blue : ink,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('查看企业'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _BenefitEmptyState extends StatelessWidget {
  const _BenefitEmptyState({
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onAction,
  });
  final String title, subtitle, action;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CompanyBenefitsArt(),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontSize: 12, height: 1.7),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              minimumSize: const Size(160, 44),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(action),
          ),
        ],
      ),
    ),
  );
}

AppIconData benefitIcon(String category) => switch (category) {
  'salary' || 'bonus' => AppIcons.coins,
  'insurance' => AppIcons.accountSecurity,
  'hours' || 'leave' => AppIcons.date,
  'allowance' => AppIcons.liked,
  'growth' => AppIcons.education,
  _ => AppIcons.work,
};

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({
    required this.item,
    required this.mine,
    required this.onTap,
  });
  final Map<String, dynamic> item;
  final bool mine;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final content = benefitMap(item['content']);
    final benefits = benefitMap(content['benefits']);
    final location = [
      content['city'],
      content['industry'],
    ].where((v) => v != null && '$v'.trim().isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4FD),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: AppIcon(
                          AppIcons.companyBenefits,
                          size: 24,
                          color: blue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${content['company_name'] ?? ''}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                          if (location.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              location,
                              style: const TextStyle(
                                fontSize: 11,
                                color: muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (mine) ...[
                      const SizedBox(width: 8),
                      _BenefitTag(benefitStatuses[item['status']] ?? '审核中'),
                    ] else
                      const AppIcon(AppIcons.forward, size: 16, color: muted),
                  ],
                ),
                const SizedBox(height: 16),
                if (benefits.isNotEmpty)
                  Text(
                    '${benefits.values.first}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: ink,
                      height: 1.6,
                    ),
                  ),
                if (benefits.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final key in benefits.keys.take(4))
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F7FB),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            benefitLabels[key] ?? '福利待遇',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF748298),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${content['job_scope'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: muted),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${content['valid_as_of'] ?? ''}',
                      style: const TextStyle(fontSize: 10, color: muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BenefitTag extends StatelessWidget {
  const _BenefitTag(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    final attention = label == benefitStatuses['NEEDS_MORE'];
    final approved = label == benefitStatuses['APPROVED'];
    final color = attention
        ? const Color(0xFFB77A3A)
        : approved
        ? const Color(0xFF448A72)
        : blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color)),
    );
  }
}

class BenefitDetailPage extends StatefulWidget {
  const BenefitDetailPage({
    super.key,
    required this.store,
    required this.id,
    this.mine = false,
  });
  final AppStore store;
  final String id;
  final bool mine;
  @override
  State<BenefitDetailPage> createState() => _BenefitDetailPageState();
}

class _BenefitDetailPageState extends State<BenefitDetailPage> {
  Map<String, dynamic>? item;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result = await widget.store.request(
        widget.mine ? 'GetCompanyBenefitSubmissionsId' : 'GetCompanyBenefitsId',
        path: {'id': widget.id},
      );
      if (!widget.mine && !hasReviewedBenefitSources(result.data)) {
        throw const ApiFailure('该记录正在核验公开来源，暂不展示');
      }
      if (mounted) {
        setState(() {
          item = result.data;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e is ApiFailure ? e.message : '加载失败，请重试');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = benefitMap(item?['content']);
    final benefits = benefitMap(content['benefits']);
    final location = [
      content['province'],
      content['city'],
      content['industry'],
    ].where((v) => v != null && '$v'.trim().isNotEmpty).toSet().join(' · ');
    final feedback = '${item?['review_reason'] ?? ''}'.trim();
    return Scaffold(
      appBar: AppBar(title: Text(widget.mine ? '收录进度' : '企业福利')),
      body: item == null
          ? Center(
              child: error == null
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: TextButton(
                        onPressed: load,
                        child: Text('$error · 重试'),
                      ),
                    ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F4FD),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Center(
                              child: AppIcon(
                                AppIcons.companyBenefits,
                                size: 27,
                                color: blue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${content['company_name'] ?? ''}',
                                  style: const TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w700,
                                    height: 1.4,
                                  ),
                                ),
                                if (location.isNotEmpty) ...[
                                  const SizedBox(height: 7),
                                  Text(
                                    location,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: muted,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _BenefitTag(
                          widget.mine
                              ? benefitStatuses[item!['status']] ?? '审核中'
                              : '平台收录',
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      const Text(
                        '适用范围',
                        style: TextStyle(color: muted, fontSize: 11),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${content['job_scope'] ?? ''}',
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '待遇对应日期：${content['valid_as_of'] ?? ''}',
                        style: const TextStyle(color: muted, fontSize: 11),
                      ),
                      if (!widget.mine) ...[
                        const SizedBox(height: 6),
                        Text(
                          '来源核验日期：${item!['source_reviewed_at'].toString().split('T').first}',
                          style: const TextStyle(color: muted, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                for (final entry in benefits.entries)
                  _BenefitSection(
                    title: benefitLabels[entry.key] ?? '福利待遇',
                    icon: benefitIcon(entry.key),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${entry.value}',
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.8,
                            color: ink,
                          ),
                        ),
                        _BenefitSource(
                          source: benefitMap(
                            benefitMap(content['sources'])[entry.key],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (widget.mine) ...[
                  _BenefitSection(
                    title: '审核反馈',
                    icon: AppIcons.submitReview,
                    child: Text(
                      feedback.isEmpty ? '信息已提交，正在核验公开来源。' : feedback,
                      style: const TextStyle(fontSize: 13, height: 1.7),
                    ),
                  ),
                  if ((item!['files'] as List? ?? []).isNotEmpty)
                    _BenefitSection(
                      title: '历史附件',
                      icon: AppIcons.folder,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '仅显示文件记录，不用于本次公开收录。',
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                          const SizedBox(height: 10),
                          for (final f in (item!['files'] as List? ?? []).map(
                            benefitMap,
                          ))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '${f['purpose'] == 'EMPLOYMENT_PROOF' ? '在职证明' : '福利举证'}：${f['name']}',
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (item!['status'] == 'NEEDS_MORE' ||
                      item!['status'] == 'REJECTED')
                    FilledButton(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => BenefitSubmissionPage(
                              store: widget.store,
                              existing: item,
                            ),
                          ),
                        );
                        if (mounted) await load();
                      },
                      child: const Text('补充公开来源并重新提交'),
                    ),
                ] else ...[
                  const SizedBox(height: 6),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '不同岗位和地区的待遇可能不同，以企业最新公开信息为准。',
                      style: TextStyle(color: muted, fontSize: 11, height: 1.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => BenefitSubmissionPage(
                                store: widget.store,
                                company: item,
                              ),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF64738B),
                            side: const BorderSide(color: Color(0xFFE1E6EF)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const AppIcon(AppIcons.add, size: 15),
                          label: const Text(
                            '补充公开信息',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => _BenefitReportPage(
                                store: widget.store,
                                id: widget.id,
                              ),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF64738B),
                            side: const BorderSide(color: Color(0xFFE1E6EF)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const AppIcon(AppIcons.feedback, size: 15),
                          label: const Text(
                            '纠错 / 投诉',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

class _BenefitSection extends StatelessWidget {
  const _BenefitSection({required this.title, required this.child, this.icon});
  final String title;
  final Widget child;
  final AppIconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              AppIcon(icon!, size: 18, color: blue),
              const SizedBox(width: 9),
            ],
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class _BenefitSource extends StatelessWidget {
  const _BenefitSource({required this.source});
  final Map<String, dynamic> source;
  @override
  Widget build(BuildContext context) {
    final uri = benefitSourceUri('${source['url'] ?? ''}');
    if (uri == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text('待补充合法公开来源', style: TextStyle(color: muted, fontSize: 12)),
      );
    }
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '发布主体：${source['publisher'] ?? ''}',
            style: const TextStyle(
              color: Color(0xFF748298),
              fontSize: 11,
              height: 1.6,
            ),
          ),
          if ('${source['published_on'] ?? ''}'.isNotEmpty)
            Text(
              '来源发布日期：${source['published_on']}',
              style: const TextStyle(color: muted, fontSize: 11, height: 1.6),
            ),
          TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              textStyle: const TextStyle(fontSize: 11),
            ),
            onPressed: () => runRequest(context, () async {
              if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                throw const ApiFailure('无法打开来源链接');
              }
            }),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    '查看来源 · ${uri.host}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                const AppIcon(AppIcons.external, size: 13),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitReportPage extends StatefulWidget {
  const _BenefitReportPage({required this.store, required this.id});
  final AppStore store;
  final String id;
  @override
  State<_BenefitReportPage> createState() => _BenefitReportPageState();
}

class _BenefitReportPageState extends State<_BenefitReportPage> {
  final form = GlobalKey<FormState>();
  final description = TextEditingController();
  final reasons = const {
    'SOURCE_ERROR': '来源或待遇信息有误',
    'TRADE_SECRET': '涉嫌泄露商业秘密',
    'UNAUTHORIZED': '涉嫌未经授权披露',
    'PERSONAL_INFORMATION': '涉及个人信息',
  };
  String reason = 'SOURCE_ERROR';
  bool busy = false;
  String? error;
  late final int accountEpoch;

  @override
  void initState() {
    super.initState();
    accountEpoch = widget.store.epoch;
  }

  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    dismissKeyboard();
    if (!form.currentState!.validate()) return;
    if (!widget.store.alive || widget.store.epoch != accountEpoch) {
      toast(context, '账号已切换，请重新打开页面');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final response = await widget.store.request(
        'PostReports',
        body: {
          'subject_type': 'COMPANY_BENEFIT',
          'subject_id': int.parse(widget.id),
          'reason_code': reason,
          'description': description.text.trim(),
        },
      );
      if (!mounted || widget.store.epoch != accountEpoch) return;
      final id = response.data['id'];
      if (id == null) throw const ApiFailure('未收到受理编号，请稍后重试');
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('已提交，等待核查'),
          content: Text('受理编号：$id。平台将核查具体条目及来源，并根据核查情况处理。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => error = e is ApiFailure ? e.message : '提交失败，请重试');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('信息纠错 / 侵权投诉')),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              '说明有问题的具体条目、你的权利关系以及可核验的公开线索。请勿在描述中复制商业秘密原文、身份证号、工资明细或他人个人信息。',
              style: TextStyle(color: muted, fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: reason,
              decoration: const InputDecoration(labelText: '问题类型'),
              items: [
                for (final entry in reasons.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: busy
                  ? null
                  : (value) => setState(() => reason = value!),
            ),
            const SizedBox(height: 20),
            TextFormField(
              key: const ValueKey('benefit-report-description'),
              controller: description,
              enabled: !busy,
              minLines: 5,
              maxLines: 8,
              maxLength: 200,
              decoration: const InputDecoration(labelText: '条目、权利关系与核验线索'),
              validator: (value) =>
                  validateBenefitReportDescription(value ?? ''),
            ),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: busy ? null : submit,
              child: Text(busy ? '提交中…' : '提交纠错 / 投诉'),
            ),
          ],
        ),
      ),
    ),
  );
}

class BenefitSubmissionPage extends StatefulWidget {
  const BenefitSubmissionPage({
    super.key,
    required this.store,
    this.existing,
    this.company,
  });
  final AppStore store;
  final Map<String, dynamic>? existing;
  final Map<String, dynamic>? company;
  @override
  State<BenefitSubmissionPage> createState() => _BenefitSubmissionPageState();
}

class _BenefitSubmissionPageState extends State<BenefitSubmissionPage> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  final values = <String, TextEditingController>{};
  final sources = <String, Map<String, TextEditingController>>{};
  final selectedBenefits = <String>{};
  late DateTime date;
  bool busy = false;
  bool sourceConfirmed = false;
  bool attemptedSubmission = false;
  String? error;
  String requestKey = '';
  late final int accountEpoch;

  @override
  void initState() {
    super.initState();
    accountEpoch = widget.store.epoch;
    final data = benefitMap((widget.existing ?? widget.company)?['content']);
    for (final key in [
      'company_name',
      'province',
      'city',
      'industry',
      'job_scope',
    ]) {
      fields[key] = TextEditingController(text: '${data[key] ?? ''}');
    }
    final benefits = benefitMap(data['benefits']);
    final existingSources = benefitMap(data['sources']);
    for (final key in benefitLabels.keys) {
      values[key] = TextEditingController(text: '${benefits[key] ?? ''}');
      if (values[key]!.text.trim().isNotEmpty) selectedBenefits.add(key);
      final source = benefitMap(existingSources[key]);
      sources[key] = {
        for (final name in ['url', 'publisher', 'published_on'])
          name: TextEditingController(text: '${source[name] ?? ''}'),
      };
    }
    if (selectedBenefits.isEmpty) selectedBenefits.add('salary');
    date = DateTime.tryParse('${data['valid_as_of'] ?? ''}') ?? DateTime.now();
  }

  @override
  void dispose() {
    for (final c in [
      ...fields.values,
      ...values.values,
      ...sources.values.expand((source) => source.values),
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get accountValid =>
      widget.store.alive && widget.store.epoch == accountEpoch;
  String get dateText =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  void changed() => setState(() {
    requestKey = '';
    sourceConfirmed = false;
    error = null;
  });

  Future<void> submit() async {
    dismissKeyboard();
    setState(() => attemptedSubmission = true);
    if (!form.currentState!.validate()) {
      setState(() => error = '请检查必填信息和每项公开来源');
      return;
    }
    if (!accountValid) {
      toast(context, '账号已切换，请重新打开页面');
      return;
    }
    final benefits = {
      for (final entry in values.entries)
        if (entry.value.text.trim().isNotEmpty)
          entry.key: entry.value.text.trim(),
    };
    if (benefits.isEmpty) {
      toast(context, '请至少填写一项福利待遇及其公开来源');
      return;
    }
    // Validate controller values too: fields outside the viewport can be unmounted.
    for (final key in ['company_name', 'province', 'city', 'job_scope']) {
      if (fields[key]!.text.trim().isEmpty) {
        setState(() => error = '请填写完整的企业名称、地区和适用岗位');
        return;
      }
    }
    for (final key in benefits.keys) {
      for (final name in ['url', 'publisher', 'published_on']) {
        final message = sourceValidation(
          name,
          sources[key]![name]!.text.trim(),
        );
        if (message != null) {
          setState(() => error = '${benefitLabels[key]}：$message');
          return;
        }
      }
    }
    if (!sourceConfirmed) {
      toast(context, '请确认内容来自企业合法公开渠道');
      return;
    }
    requestKey = requestKey.isEmpty
        ? List.generate(
            24,
            (_) =>
                Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
          ).join()
        : requestKey;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.request(
        widget.existing == null
            ? 'PostCompanyBenefitSubmissions'
            : 'PatchCompanyBenefitSubmissionsId',
        path: {
          if (widget.existing != null) 'id': widget.existing!['id'].toString(),
        },
        extra: {'Idempotency-Key': requestKey},
        body: {
          'company_id': widget.existing?['company_id'] ?? widget.company?['id'],
          'content': {
            for (final entry in fields.entries)
              entry.key: entry.value.text.trim(),
            'valid_as_of': dateText,
            'benefits': benefits,
            'sources': {
              for (final key in benefits.keys)
                key: {
                  for (final entry in sources[key]!.entries)
                    if (entry.value.text.trim().isNotEmpty)
                      entry.key: entry.value.text.trim(),
                },
            },
          },
          // Old internal attachments are never reused by the public-source flow.
          'employment_file_ids': <int>[],
          'evidence_file_ids': <int>[],
          if (widget.existing != null) 'revision': widget.existing!['revision'],
        },
      );
      if (!mounted || !accountValid) return;
      toast(context, '已提交，等待平台核验公开来源');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => error = e is ApiFailure ? e.message : '提交失败，请重试');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  InputDecoration decoration(String hint) => InputDecoration(
    hintText: hint,
    counterText: '',
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
    fillColor: const Color(0xFFF5F7FB),
    hintStyle: const TextStyle(color: muted, fontSize: 13),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFF0F2F6)),
    ),
  );

  Widget input(
    String key,
    String label, {
    bool required = true,
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            required ? label : '$label（选填）',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        TextFormField(
          key: ValueKey('benefit-field-$key'),
          controller: fields[key],
          enabled: !busy,
          style: const TextStyle(fontSize: 14),
          maxLength: key == 'company_name'
              ? 120
              : key == 'job_scope'
              ? 100
              : key == 'industry'
              ? 60
              : 40,
          textInputAction: TextInputAction.next,
          decoration: decoration(hint ?? label),
          validator: (v) =>
              required && (v?.trim().isEmpty ?? true) ? '请填写$label' : null,
          onChanged: (_) => changed(),
        ),
      ],
    ),
  );

  Widget sourceInput(String key, String name, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
      TextFormField(
        key: ValueKey('benefit-source-$key-$name'),
        controller: sources[key]![name],
        enabled: !busy,
        style: const TextStyle(fontSize: 13),
        keyboardType: name == 'url' ? TextInputType.url : TextInputType.text,
        autocorrect: name != 'url',
        textInputAction: TextInputAction.next,
        maxLength: name == 'url'
            ? 2048
            : name == 'publisher'
            ? 120
            : 10,
        decoration: decoration(
          name == 'url'
              ? 'https://'
              : name == 'publisher'
              ? '企业或官方发布主体'
              : 'YYYY-MM-DD',
        ),
        onChanged: (_) => changed(),
        validator: (value) => values[key]!.text.trim().isEmpty
            ? null
            : sourceValidation(name, value?.trim() ?? ''),
      ),
    ],
  );

  String? sourceValidation(String name, String text) {
    if (name == 'url') {
      return benefitSourceUri(text) == null
          ? '请填写企业合法公开页面的 HTTP/HTTPS 链接'
          : null;
    }
    if (name == 'publisher') {
      return text.runes.length < 2 ? '请填写企业公开来源的发布主体（至少2字）' : null;
    }
    if (text.isEmpty) return null;
    final parsed = DateTime.tryParse(text);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text) ||
        parsed == null ||
        '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}' !=
            text ||
        parsed.isAfter(DateTime.now())) {
      return '请填写有效的发布日期（YYYY-MM-DD），不能晚于今天';
    }
    return null;
  }

  Future<void> toggleBenefit(String key) async {
    if (busy) return;
    if (selectedBenefits.contains(key)) {
      final hasContent =
          values[key]!.text.trim().isNotEmpty ||
          sources[key]!.values.any((value) => value.text.trim().isNotEmpty);
      if (hasContent) {
        dismissKeyboard();
        final discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('移除${benefitLabels[key]}？'),
            content: const Text('这一项已填写的摘要和公开来源将被清除。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('继续保留'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('移除'),
              ),
            ],
          ),
        );
        if (discard != true || !mounted) return;
      }
      values[key]!.clear();
      for (final value in sources[key]!.values) {
        value.clear();
      }
      selectedBenefits.remove(key);
    } else {
      selectedBenefits.add(key);
    }
    changed();
  }

  void showCollectionRules() {
    dismissKeyboard();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '公开信息收录规则',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              rulesRow(
                AppIcons.external,
                '提供企业公开渠道',
                '使用企业官网、官方招聘公告等合法公开页面。每项待遇分别填写对应链接和发布主体。',
              ),
              rulesRow(
                AppIcons.edit,
                '只整理来源中的事实',
                '摘要应与公开页面一致，注明适用岗位与日期，不补充未经公开的内容。',
              ),
              rulesRow(
                AppIcons.privacyPolicy,
                '内部资料不予收录',
                '请勿提交内网、员工群、匿名泄漏链接，或未公开制度、薪资明细、劳动合同及个人信息。本页面不支持上传内部材料。',
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('我知道了'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget rulesRow(AppIconData icon, String title, String detail) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: blue.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: AppIcon(icon, size: 18, color: blue)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                detail,
                style: const TextStyle(color: muted, fontSize: 13, height: 1.6),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget sectionTitle(String number, String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: blue.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              color: blue,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(color: muted, fontSize: 12, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget benefitCard(String key) => Container(
    key: ValueKey('benefit-editor-$key'),
    margin: const EdgeInsets.only(top: 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: borderColor),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                benefitLabels[key]!,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: '移除${benefitLabels[key]}',
              visualDensity: VisualDensity.compact,
              onPressed: busy ? null : () => toggleBenefit(key),
              icon: const AppIcon(AppIcons.close, size: 18, color: muted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey('benefit-value-$key'),
          controller: values[key],
          enabled: !busy,
          minLines: 2,
          maxLines: 5,
          maxLength: 2000,
          style: const TextStyle(fontSize: 14, height: 1.5),
          decoration: decoration('简要整理公开待遇，注明适用条件'),
          onChanged: (_) => changed(),
        ),
        const SizedBox(height: 18),
        const Divider(height: 1),
        const SizedBox(height: 16),
        const Row(
          children: [
            AppIcon(AppIcons.external, size: 15, color: blue),
            SizedBox(width: 7),
            Text(
              '这项待遇的公开来源',
              style: TextStyle(
                color: blue,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        sourceInput(key, 'url', '来源地址（必填）'),
        const SizedBox(height: 14),
        sourceInput(key, 'publisher', '来源发布主体'),
        const SizedBox(height: 14),
        sourceInput(key, 'published_on', '发布日期（选填）'),
      ],
    ),
  );

  Widget submissionFooter() => Material(
    color: Colors.white,
    child: Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CheckboxListTile(
              key: const ValueKey('benefit-source-confirmation'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              visualDensity: VisualDensity.compact,
              controlAffinity: ListTileControlAffinity.leading,
              value: sourceConfirmed,
              onChanged: busy
                  ? null
                  : (value) => setState(() => sourceConfirmed = value ?? false),
              title: const Text(
                '确认仅提交企业公开信息，未包含内部资料或个人信息。',
                style: TextStyle(fontSize: 12, height: 1.5, color: muted),
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            const SizedBox(height: 3),
            FilledButton(
              onPressed: busy ? null : submit,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (busy) ...[
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(busy ? '正在处理，请稍候…' : '提交平台审核'),
                    if (!busy) ...[
                      const SizedBox(width: 10),
                      const AppIcon(AppIcons.arrowForward, size: 18),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? '分享企业福利' : '补充公开来源'),
        actions: const [DismissKeyboardButton(), SizedBox(width: 6)],
      ),
      body: Form(
        key: form,
        autovalidateMode: attemptedSubmission
            ? AutovalidateMode.always
            : AutovalidateMode.disabled,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                children: [
                  const Text(
                    '整理企业公开福利',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.5,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    '选好待遇类别，附上来源，帮助大家了解企业。',
                    style: TextStyle(color: muted, fontSize: 12, height: 1.6),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF3FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const AppIcon(
                          AppIcons.privacyPolicy,
                          size: 17,
                          color: blue,
                        ),
                        const SizedBox(width: 9),
                        const Expanded(
                          child: Text(
                            '仅收录公开信息\n请勿提交企业内部资料',
                            style: TextStyle(
                              color: ink,
                              fontSize: 11,
                              height: 1.5,
                            ),
                          ),
                        ),
                        TextButton(
                          key: const ValueKey('benefit-collection-rules'),
                          onPressed: showCollectionRules,
                          child: const Text('收录规则'),
                        ),
                      ],
                    ),
                  ),
                  if ((widget.existing?['files'] as List? ?? []).isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        '历史附件不会用于本次公开信息收录。',
                        style: TextStyle(
                          color: muted,
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  sectionTitle('01', '企业与适用范围', '让福利信息对应到具体企业和岗位'),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: borderColor),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        input('company_name', '企业完整名称', hint: '填写企业全称'),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: input('province', '省份')),
                            const SizedBox(width: 12),
                            Expanded(child: input('city', '城市')),
                          ],
                        ),
                        input(
                          'industry',
                          '行业',
                          required: false,
                          hint: '企业所属行业',
                        ),
                        input('job_scope', '适用岗位 / 员工范围', hint: '注明适用岗位、地区等条件'),
                        const Divider(height: 1),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const AppIcon(
                              AppIcons.date,
                              size: 17,
                              color: muted,
                            ),
                            const SizedBox(width: 9),
                            const Expanded(
                              child: Text(
                                '待遇对应日期',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () async {
                                      dismissKeyboard();
                                      final picked = await showDateWheelPicker(
                                        context,
                                        title: '待遇对应日期',
                                        initialDate: date,
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime.now(),
                                      );
                                      if (picked != null && mounted) {
                                        date = picked;
                                        changed();
                                      }
                                    },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(dateText),
                                  const SizedBox(width: 5),
                                  const AppIcon(AppIcons.expand, size: 15),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  sectionTitle('02', '选择要分享的待遇', '至少填写一项，每项分别提供公开来源'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in benefitLabels.entries)
                        FilterChip(
                          key: ValueKey('benefit-category-${entry.key}'),
                          label: Text(entry.value),
                          selected: selectedBenefits.contains(entry.key),
                          onSelected: busy
                              ? null
                              : (_) => toggleBenefit(entry.key),
                          showCheckmark: true,
                          checkmarkColor: blue,
                          labelStyle: TextStyle(
                            color: selectedBenefits.contains(entry.key)
                                ? blue
                                : muted,
                            fontSize: 12,
                            fontWeight: selectedBenefits.contains(entry.key)
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                          selectedColor: const Color(0xFFEAF0FF),
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: selectedBenefits.contains(entry.key)
                                ? blue.withValues(alpha: .18)
                                : borderColor,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 7,
                          ),
                        ),
                    ],
                  ),
                  if (selectedBenefits.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: Text(
                        '点击上方类别，开始整理一项福利。',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ),
                  for (final key in benefitLabels.keys)
                    if (selectedBenefits.contains(key)) benefitCard(key),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            submissionFooter(),
          ],
        ),
      ),
    ),
  );
}
