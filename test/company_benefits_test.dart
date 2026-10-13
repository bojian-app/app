import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_bottom_navigation.dart';
import 'package:bojian_mobile/app_icons.dart';
import 'package:bojian_mobile/app_shell.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/company_benefits.dart';
import 'package:bojian_mobile/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class BenefitsFilterGateway extends FakeGateway {
  final queries = <Map<String, String>>[];
  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) {
    if (method == 'GetCompanyBenefits') queries.add(Map.of(query));
    return super.call(
      method,
      path: path,
      query: query,
      body: body,
      headers: headers,
    );
  }
}

Future<AppStore> storeFor(FakeGateway api) async {
  final store = AppStore(api: api, storage: MemoryStorage());
  await store.initialize();
  store.session = {'access_token': 'test', 'refresh_token': 'test'};
  return store;
}

Map<String, dynamic> content({bool sources = true}) => {
  'company_name': '测试企业',
  'province': '广东省',
  'city': '广州市',
  'industry': '软件',
  'job_scope': '全职员工',
  'valid_as_of': '2026-10-10',
  'benefits': {'leave': '双休'},
  if (sources)
    'sources': {
      'leave': {
        'url': 'https://company.example.com/careers',
        'publisher': '测试企业',
        'published_on': '2026-10-10',
      },
    },
};

Map<String, dynamic> publicRecord({bool reviewed = true}) => {
  'id': 1,
  'content': content(sources: reviewed),
  'verified_at': '2026-10-10T05:00:00Z',
  if (reviewed) 'source_reviewed_at': '2026-10-10T05:00:00Z',
};

Future<void> scrollTo(
  WidgetTester tester,
  Finder finder, [
  double delta = 500,
]) async {
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  test('Complaint text respects the server UTF-8 limit for combined emoji', () {
    expect(validateBenefitReportDescription('我是企业代表，公告的岗位适用范围有误。'), isNull);
    expect(
      validateBenefitReportDescription(List.filled(50, '👨‍👩‍👧‍👦').join()),
      isNotNull,
    );
  });

  test('Source links reject executable, credentialed and intranet URLs', () {
    for (final url in [
      'javascript:alert(1)',
      'file:///secret',
      'https://user:pass@company.example.com/a',
      'http://127.0.0.1/a',
      'http://0x7f.0x000001/a',
      'https://example.com:',
      'https://@example.com/a',
      r'https://example.com/a\b',
      'http://[::1]/a',
      'https://localhost/a',
      'https://hr.internal/a',
      'https://hr.local/a',
      '//company.example.com/a',
    ]) {
      expect(benefitSourceUri(url), isNull, reason: url);
    }
    expect(benefitSourceUri('https://company.example.com/careers'), isNotNull);
    expect(benefitSourceUri('http://company.example.com/careers'), isNotNull);
  });

  testWidgets(
    'Search and city filters fit a narrow phone without oversized icons',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = BenefitsFilterGateway();
      final store = await storeFor(api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(body: CompanyBenefitsPage(store: store)),
        ),
      );
      await tester.pumpAndSettle();
      final search = find.byKey(const ValueKey('benefit-search'));
      final searchIcon = find.descendant(
        of: search,
        matching: find.byType(AppIcon),
      );
      expect(tester.getSize(searchIcon).width, 20);
      expect(find.byTooltip('清空搜索'), findsNothing);
      await tester.enterText(search, '不存在的企业');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(api.queries.last['query'], '不存在的企业');
      expect(find.text('没有找到相关企业'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('benefit-city-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('杭州'));
      await tester.tap(find.text('查看企业'));
      await tester.pumpAndSettle();
      expect(api.queries.last['city'], '杭州市');
      await scrollTo(tester, find.text('清除筛选'));
      await tester.tap(find.text('清除筛选'));
      await tester.pumpAndSettle();
      expect(api.queries.last['city'], isEmpty);
      expect(api.queries.last['query'], isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Submission exposes selected benefits only and keeps actions above keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = FakeGateway();
      final store = await storeFor(api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: BenefitSubmissionPage(store: store),
        ),
      );
      await tester.pumpAndSettle();
      await scrollTo(
        tester,
        find.byKey(const ValueKey('benefit-category-leave')),
      );
      await tester.tap(find.byKey(const ValueKey('benefit-category-leave')));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.byKey(const ValueKey('benefit-value-leave')));
      await tester.enterText(
        find.byKey(const ValueKey('benefit-value-leave')),
        '公开休假安排',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('benefit-value-growth')), findsNothing);
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('提交平台审核')).bottom,
        lessThanOrEqualTo(348),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Landscape search remains usable when the keyboard reduces available height',
    (tester) async {
      tester.view.physicalSize = const Size(740, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = FakeGateway();
      final store = await storeFor(api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: AppShell(store: store),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('discovery-company-benefits')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('benefit-search')),
        '企业',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('benefit-search')))
            .controller!
            .text,
        '企业',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Independent benefits navigation shows honest empty state', (
    tester,
  ) async {
    final api = FakeGateway();
    final store = await storeFor(api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: AppShell(store: store),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('discovery-company-benefits')));
    await tester.pumpAndSettle();
    expect(find.text('企业福利'), findsOneWidget);
    expect(find.text('企业福利正在收录'), findsOneWidget);
    expect(api.calls, contains('GetCompanyBenefits'));
    await tester.tap(find.text('我的提交'));
    await tester.pumpAndSettle();
    expect(find.text('还没有提交记录'), findsOneWidget);
    expect(api.calls, contains('GetMeCompanyBenefitSubmissions'));
  });

  testWidgets(
    'Discovery loads benefits on demand and retains search after nested routes',
    (tester) async {
      final api = FakeGateway();
      final store = await storeFor(api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: AppShell(store: store),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.calls, isNot(contains('GetCompanyBenefits')));
      expect(api.calls, isNot(contains('GetMeCompanyBenefitSubmissions')));
      expect(find.byType(AppBottomNavigation), findsOneWidget);
      expect(find.byKey(const ValueKey('nav-4')), findsNothing);

      final discoverySearch = find.byKey(const ValueKey('discovery-search'));
      final originalController = tester
          .widget<TextField>(discoverySearch)
          .controller;
      await tester.enterText(discoverySearch, '面试经验');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(api.calls, isNot(contains('GetCompanyBenefits')));
      await tester.tap(
        find.byKey(const ValueKey('discovery-company-benefits')),
      );
      await tester.pumpAndSettle();
      expect(
        api.calls.where((call) => call == 'GetCompanyBenefits'),
        hasLength(1),
      );
      expect(find.byType(AppBottomNavigation), findsNothing);
      expect(find.byKey(const ValueKey('discovery-search')), findsNothing);
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.text('企业福利正在收录'), findsOneWidget);

      await tester.tap(find.text('我的提交'));
      await tester.pumpAndSettle();
      expect(find.text('还没有提交记录'), findsOneWidget);
      expect(find.byType(AppBottomNavigation), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('企业福利正在收录'), findsOneWidget);
      expect(find.byType(AppBottomNavigation), findsNothing);
      final requestsBeforeReturningToDiscovery = api.calls
          .where((call) => call == 'GetCompanyBenefits')
          .length;
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(AppBottomNavigation), findsOneWidget);
      expect(
        find.byKey(const ValueKey('discovery-company-benefits')),
        findsOneWidget,
      );
      final restoredController = tester
          .widget<TextField>(discoverySearch)
          .controller;
      expect(restoredController, same(originalController));
      expect(restoredController!.text, '面试经验');
      expect(
        api.calls.where((call) => call == 'GetCompanyBenefits'),
        hasLength(requestsBeforeReturningToDiscovery),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Public detail shows each source, scope and date without proofs',
    (tester) async {
      final api = FakeGateway();
      api.documents['GetCompanyBenefitsId'] = publicRecord();
      final store = await storeFor(api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: BenefitDetailPage(store: store, id: '1'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('测试企业'), findsOneWidget);
      expect(find.text('全职员工'), findsOneWidget);
      expect(find.text('双休'), findsOneWidget);
      expect(find.textContaining('在职证明'), findsNothing);
      await scrollTo(tester, find.text('查看来源 · company.example.com'));
      expect(find.text('发布主体：测试企业'), findsOneWidget);
      expect(find.textContaining('官方'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Old server records without reviewed sources are not publicly rendered',
    (tester) async {
      final api = FakeGateway();
      api.documents['GetCompanyBenefits'] = {
        'items': [publicRecord(reviewed: false)],
      };
      api.documents['GetCompanyBenefitsId'] = publicRecord(reviewed: false);
      final store = await storeFor(api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(body: CompanyBenefitsPage(store: store)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('测试企业'), findsNothing);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: BenefitDetailPage(store: store, id: '1'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('测试企业'), findsNothing);
      expect(find.textContaining('正在核验公开来源'), findsOneWidget);
    },
  );

  testWidgets(
    'Supplement sends public sources and revision, drops old attachments, keeps retry key',
    (tester) async {
      final api = FakeGateway();
      api.failing = 'PatchCompanyBenefitSubmissionsId';
      final store = await storeFor(api);
      addTearDown(store.dispose);
      final existing = {
        'id': 1,
        'revision': 3,
        'content': content(),
        'status': 'NEEDS_MORE',
        'files': [
          {'id': 11, 'name': '证明.pdf', 'purpose': 'EMPLOYMENT_PROOF'},
          {'id': 12, 'name': '待遇.png', 'purpose': 'BENEFIT_EVIDENCE'},
        ],
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: BenefitSubmissionPage(store: store, existing: existing),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('添加材料'), findsNothing);
      await scrollTo(
        tester,
        find.byKey(const ValueKey('benefit-source-confirmation')),
      );
      await tester.tap(
        find.byKey(const ValueKey('benefit-source-confirmation')),
      );
      await scrollTo(tester, find.text('提交平台审核'));
      await tester.tap(find.text('提交平台审核'));
      await tester.pumpAndSettle();
      expect(api.lastBody?['revision'], 3);
      expect(api.lastBody?['employment_file_ids'], isEmpty);
      expect(api.lastBody?['evidence_file_ids'], isEmpty);
      expect(
        (api.lastBody?['content'] as Map)['sources'],
        (content()['sources']),
      );
      expect(find.text('服务器暂不可用'), findsOneWidget);
      final key = api.lastHeaders?['Idempotency-Key'];
      expect(key, isNotEmpty);
      await tester.tap(find.text('提交平台审核'));
      await tester.pumpAndSettle();
      expect(api.lastHeaders?['Idempotency-Key'], key);
      expect(api.calls, isNot(contains('PostFilesUploads')));
    },
  );

  testWidgets(
    'A source can be entered before its benefit summary and submitted',
    (tester) async {
      final api = FakeGateway()..failing = 'PostCompanyBenefitSubmissions';
      final store = await storeFor(api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: BenefitSubmissionPage(
            store: store,
            company: {
              'id': 1,
              'content': {
                ...content(sources: false),
                'benefits': <String, String>{},
              },
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final url = find.byKey(const ValueKey('benefit-source-salary-url'));
      await scrollTo(tester, url);
      await tester.enterText(url, 'https://company.example.com/careers');
      final publisher = find.byKey(
        const ValueKey('benefit-source-salary-publisher'),
      );
      await scrollTo(tester, publisher);
      await tester.enterText(publisher, '测试企业');
      final summary = find.byKey(const ValueKey('benefit-value-salary'));
      await scrollTo(tester, summary, -300);
      await tester.enterText(summary, '公开招聘公告列明岗位薪资范围');
      await tester.pumpAndSettle();
      await scrollTo(tester, url);
      expect(
        tester.widget<TextFormField>(url).controller!.text,
        'https://company.example.com/careers',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      final confirmation = find.byKey(
        const ValueKey('benefit-source-confirmation'),
      );
      await scrollTo(tester, confirmation);
      await tester.tap(confirmation);
      await tester.pumpAndSettle();
      await tester.tap(find.text('提交平台审核'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('PostCompanyBenefitSubmissions'));
      expect((api.lastBody!['content'] as Map)['sources'], {
        'salary': {
          'url': 'https://company.example.com/careers',
          'publisher': '测试企业',
        },
      });
    },
  );

  testWidgets('Missing per-benefit source prevents submission', (tester) async {
    final api = FakeGateway();
    final store = await storeFor(api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: BenefitSubmissionPage(
          store: store,
          company: {'id': 1, 'content': content(sources: false)},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await scrollTo(
      tester,
      find.byKey(const ValueKey('benefit-source-confirmation')),
    );
    await tester.tap(find.byKey(const ValueKey('benefit-source-confirmation')));
    await scrollTo(tester, find.text('提交平台审核'));
    await tester.tap(find.text('提交平台审核'));
    await tester.pumpAndSettle();
    expect(api.calls, isNot(contains('PostCompanyBenefitSubmissions')));
    await scrollTo(
      tester,
      find.byKey(const ValueKey('benefit-source-leave-url')),
      500,
    );
    expect(find.text('请填写企业合法公开页面的 HTTP/HTTPS 链接'), findsOneWidget);
  });

  testWidgets('Editing a source clears the user confirmation', (tester) async {
    final api = FakeGateway();
    final store = await storeFor(api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: BenefitSubmissionPage(
          store: store,
          company: {'id': 1, 'content': content()},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await scrollTo(
      tester,
      find.byKey(const ValueKey('benefit-source-confirmation')),
    );
    await tester.tap(find.byKey(const ValueKey('benefit-source-confirmation')));
    await scrollTo(
      tester,
      find.byKey(const ValueKey('benefit-source-leave-url')),
      500,
    );
    await tester.enterText(
      find.byKey(const ValueKey('benefit-source-leave-url')),
      'https://company.example.com/new-careers',
    );
    await tester.pumpAndSettle();
    await scrollTo(
      tester,
      find.byKey(const ValueKey('benefit-source-confirmation')),
    );
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('benefit-source-confirmation')),
          )
          .value,
      isFalse,
    );
  });

  testWidgets(
    'Public detail accepts a specific complaint and returns receipt',
    (tester) async {
      final api = FakeGateway();
      api.documents['GetCompanyBenefitsId'] = publicRecord();
      api.documents['PostReports'] = {'id': 21, 'status': 'PENDING'};
      final store = await storeFor(api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: BenefitDetailPage(store: store, id: '1'),
        ),
      );
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('纠错 / 投诉'));
      await tester.tap(find.text('纠错 / 投诉'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('benefit-report-description')),
        '我是该企业授权代表，休假条目引用的公告适用范围有误。',
      );
      await scrollTo(tester, find.text('提交纠错 / 投诉'));
      await tester.tap(find.text('提交纠错 / 投诉'));
      await tester.pumpAndSettle();
      expect(api.lastBody?['subject_type'], 'COMPANY_BENEFIT');
      expect(api.lastBody?['subject_id'], 1);
      expect(api.lastBody?['reason_code'], 'SOURCE_ERROR');
      expect(find.textContaining('受理编号：21'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
