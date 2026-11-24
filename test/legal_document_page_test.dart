import 'package:bojian_mobile/agreement_dialog.dart';
import 'package:bojian_mobile/auth_page.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/legal_document.dart';
import 'package:bojian_mobile/legal_document_page.dart';
import 'package:bojian_mobile/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

Future<void> _tapKey(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(target, 180);
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void _expectNoAuthRequests(FakeGateway api) {
  expect(api.calls, isNot(contains('CreateCaptcha')));
  expect(api.calls, isNot(contains('VerifyCaptcha')));
  expect(api.calls, isNot(contains('SendSMS')));
}

void _expectTableValues(Finder table, LegalTable source) {
  for (final value in source.rows.expand((row) => row)) {
    expect(
      find.descendant(of: table, matching: find.text(value)),
      findsOneWidget,
      reason: 'The displayed disclosure must retain the complete table value',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final launches = <MethodCall>[];
  const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');

  setUp(() {
    launches.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcherChannel, (call) async {
          launches.add(call);
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcherChannel, null);
  });

  test(
    'Bundled documents cover store-review sections and keep placeholders',
    () {
      final terms = legalDocumentFor(LegalDocumentKind.userAgreement);
      final privacy = legalDocumentFor(LegalDocumentKind.privacyPolicy);
      expect(terms.sections.map((section) => section.title), [
        '第一条 定义与适用范围',
        '第二条 协议的订立与变更',
        '第三条 账号注册、登录与安全',
        '第四条 服务内容',
        '第五条 AI 功能特别约定',
        '第六条 会员服务与付费条款',
        '第七条 用户内容与知识产权',
        '第八条 用户行为规范与内容审核',
        '第九条 简历求指点特别约定',
        '第十条 账号注销',
        '第十一条 未成年人使用',
        '第十二条 免责与责任限制',
        '第十三条 法律适用与争议解决',
        '第十四条 通知与联系方式',
      ]);
      expect(privacy.sections.map((section) => section.title), [
        '一、我们如何收集和使用您的个人信息',
        '二、设备权限调用说明',
        '三、第三方SDK与对外提供',
        '四、个人信息的存储与保护',
        '五、您的权利',
        '六、注销账号',
        '七、未成年人个人信息保护',
        '八、本地存储',
        '九、本政策的更新',
        '十、联系我们',
      ]);
      expect(
        privacy.metadata,
        contains('版本：V${legalAgreementVersions['privacy']}'),
      );
      for (final document in [terms, privacy]) {
        const date = '2026年11月24日';
        expect(document.metadata, contains('更新日期：$date'));
        expect(document.metadata, contains('生效日期：$date'));
        expect(document.plainText, contains('珠海科岚盛网络科技有限公司'));
        expect(document.plainText, contains('91440403MAD4CAX58L'));
        expect(document.plainText, contains('珠海市斗门区湖心路口翠湖路308号1栋社区用房'));
        expect(document.plainText, contains('重新登录该账号'));
        expect(
          document.sections.map((section) => section.id).toSet(),
          hasLength(document.sections.length),
        );
        expect(
          document.introduction.every((paragraph) => paragraph.emphasized),
          isTrue,
        );
      }
      // 会员规则与会员页一致。
      expect(terms.plainText, contains('9元'));
      expect(terms.plainText, contains('99元'));
      expect(terms.plainText, contains('AI简历生成3次、AI简历优化3次、单段生成10次'));
      expect(terms.plainText, contains('每次0.99元，单段生成每次0.1元'));
      expect(terms.plainText, contains('Android 端不提供自动续费'));
      expect(terms.plainText, contains('三天会员体验包'));
      expect(terms.plainText, contains('积分不出售'));
      // 隐私政策与实际数据处理一致。
      expect(privacy.plainText, contains('Android ID'));
      expect(privacy.plainText, contains('IP属地'));
      expect(privacy.plainText, isNot(contains('OpenRouter')));
      expect(privacy.plainText, contains('自动内容审核'));
      expect(privacy.plainText, contains('备份数据保存30日，超过30日后清除'));
      expect(privacy.plainText, isNot(contains('【待填写')));
      expect(privacy.plainText, contains('腾讯云文本内容安全'));
      expect(privacy.plainText, contains('火山引擎短信服务'));
      expect(privacy.plainText, contains('该方式不属于端到端加密'));
      expect(privacy.plainText, contains('notifier@kelantech.cn'));
      expect(privacy.plainText, contains('粤ICP备2026155383号'));
      expect(privacy.plainText, contains('杭州深度求索人工智能基础技术研究有限公司'));
      expect(
        privacy.plainText,
        contains('deepseek-open-platform-privacy-policy.html'),
      );
      expect(privacy.plainText, isNot(contains('智谱')));
      expect(privacy.plainText, contains('支付宝支付科技有限公司'));
    },
  );

  test(
    'Privacy permissions and third-party disclosures retain all table cells',
    () {
      final tables = privacyPolicyDocument.sections
          .expand((section) => section.blocks)
          .whereType<LegalTable>()
          .toList();
      expect(tables, hasLength(2));
      expect(tables.first.headers, ['权限', '使用场景', '拒绝后的影响']);
      expect(tables.first.rows.map((row) => row.first), [
        '相机',
        '相册（照片）',
        '网络',
        '安装未知应用（仅Android）',
      ]);
      expect(tables.last.headers, ['名称及提供方', '使用目的与场景', '收集或处理的个人信息', '隐私政策']);
      expect(tables.last.rows, hasLength(6));
      for (final table in [
        ...tables,
        ...userAgreementDocument.sections
            .expand((section) => section.blocks)
            .whereType<LegalTable>(),
      ]) {
        expect(
          table.rows.every((row) => row.length == table.headers.length),
          isTrue,
        );
        expect(
          table.rows.expand((row) => row).every((cell) => cell.isNotEmpty),
          isTrue,
        );
      }
    },
  );

  for (final kind in LegalDocumentKind.values) {
    testWidgets('All ${kind.name} sections remain readable on a small screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!,
          ),
          home: LegalDocumentPage(kind: kind),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SelectionArea), findsOneWidget);
      final document = legalDocumentFor(kind);
      if (kind == LegalDocumentKind.privacyPolicy) {
        for (final section in document.sections.where(
          (section) => section.blocks.any((block) => block is LegalTable),
        )) {
          final table = find.byKey(ValueKey('legal-${section.id}-table'));
          expect(table, findsOneWidget);
          expect(tester.getRect(table).left, greaterThanOrEqualTo(20));
          expect(tester.getRect(table).right, lessThanOrEqualTo(300));
          expect(
            find.descendant(of: table, matching: find.byType(Table)),
            findsNothing,
          );
          _expectTableValues(
            table,
            section.blocks.whereType<LegalTable>().single,
          );
        }
      }
      for (final section in document.sections) {
        final target = find.byKey(ValueKey('legal-section-${section.id}'));
        expect(target, findsOneWidget);
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        expect(find.text(section.title), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason: 'Section ${section.title} must not overflow',
        );
      }
      final end = find.byKey(const ValueKey('legal-document-end'));
      await tester.ensureVisible(end);
      await tester.pumpAndSettle();
      expect(tester.getRect(end).bottom, lessThanOrEqualTo(640));
      expect(launches, isEmpty);

      tester.view.physicalSize = const Size(640, 320);
      await tester.pumpAndSettle();
      await tester.ensureVisible(end);
      await tester.pumpAndSettle();
      expect(tester.getRect(end).bottom, lessThanOrEqualTo(320));
      expect(tester.takeException(), isNull);
    });

    testWidgets('${kind.name} directory jumps to the selected section', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!,
          ),
          home: LegalDocumentPage(kind: kind),
        ),
      );
      await tester.pumpAndSettle();
      final section = legalDocumentFor(kind).sections.last;
      await _tapKey(tester, 'legal-directory');
      expect(find.text('${legalDocumentFor(kind).title}目录'), findsOneWidget);
      final target = find.byKey(ValueKey('legal-directory-${section.id}'));
      await tester.scrollUntilVisible(
        target,
        200,
        scrollable: find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      final title = find.text(section.title);
      expect(title, findsOneWidget);
      expect(tester.getRect(title).top, lessThan(640));
      expect(tester.getRect(title).bottom, greaterThan(56));
      expect(tester.takeException(), isNull);
      expect(launches, isEmpty);
    });
  }

  testWidgets('Privacy disclosures use readable tables on wider screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 650);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: const LegalDocumentPage(kind: LegalDocumentKind.privacyPolicy),
      ),
    );
    await tester.pumpAndSettle();
    for (final section in privacyPolicyDocument.sections.where(
      (section) => section.blocks.any((block) => block is LegalTable),
    )) {
      final table = find.byKey(ValueKey('legal-${section.id}-table'));
      expect(
        find.descendant(of: table, matching: find.byType(Table)),
        findsOneWidget,
      );
      await tester.ensureVisible(table);
      await tester.pumpAndSettle();
      expect(tester.getRect(table).width, lessThanOrEqualTo(680));
      _expectTableValues(table, section.blocks.whereType<LegalTable>().single);
      expect(tester.takeException(), isNull);
    }
    expect(launches, isEmpty);
  });

  testWidgets('Auth legal links stay native and preserve explicit consent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = FakeGateway();
    final store = await testStore(
      api: api,
      weChatAuthorizer: FakeWeChatAuthorizer(),
    );
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: AuthPage(store: store),
      ),
    );
    await tester.pumpAndSettle();
    final before = List<String>.of(api.calls);

    for (final entry in [
      ('auth-user-agreement', LegalDocumentKind.userAgreement, false),
      ('auth-privacy-policy', LegalDocumentKind.privacyPolicy, true),
    ]) {
      if (entry.$3) {
        await _tapKey(tester, 'auth-consent');
      }
      await _tapKey(tester, entry.$1);
      expect(find.byType(LegalDocumentPage), findsOneWidget);
      expect(
        tester.widget<LegalDocumentPage>(find.byType(LegalDocumentPage)).kind,
        entry.$2,
      );
      expect(api.calls, before);
      expect(launches, isEmpty);
      _expectNoAuthRequests(api);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(LegalDocumentPage), findsNothing);
      expect(
        tester
            .widget<Checkbox>(find.byKey(const ValueKey('auth-consent')))
            .value,
        entry.$3,
      );
    }
  });

  testWidgets(
    'Reading legal links inside consent dialog does not accept or send requests',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = FakeGateway();
      final store = await testStore(
        api: api,
        weChatAuthorizer: FakeWeChatAuthorizer(),
      );
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: AuthPage(store: store),
        ),
      );
      await tester.pumpAndSettle();
      await _tapKey(tester, 'auth-wechat');
      expect(find.byType(AgreementDialog), findsOneWidget);
      final before = List<String>.of(api.calls);

      for (final entry in [
        ('《用户协议》', LegalDocumentKind.userAgreement),
        ('《隐私政策》', LegalDocumentKind.privacyPolicy),
      ]) {
        await tester.tapOnText(
          find.textRange.ofSubstring(
            entry.$1,
            descendentOf: find.byType(AgreementDialog),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(LegalDocumentPage), findsOneWidget);
        expect(
          tester.widget<LegalDocumentPage>(find.byType(LegalDocumentPage)).kind,
          entry.$2,
        );
        expect(api.calls, before);
        expect(launches, isEmpty);
        _expectNoAuthRequests(api);

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(AgreementDialog), findsOneWidget);
        expect(
          find.byKey(const ValueKey('auth-agree-continue')),
          findsOneWidget,
        );
        _expectNoAuthRequests(api);
      }

      await tester.tap(find.text('暂不同意'));
      await tester.pumpAndSettle();
      expect(find.byType(AgreementDialog), findsNothing);
      expect(
        tester
            .widget<Checkbox>(find.byKey(const ValueKey('auth-consent')))
            .value,
        isFalse,
      );
      expect(api.calls, before);
    },
  );

  testWidgets(
    'Explicit consent continues WeChat authorization after legal reading',
    (tester) async {
      final api = FakeGateway();
      final store = await testStore(
        api: api,
        weChatAuthorizer: FakeWeChatAuthorizer(),
      );
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: AuthPage(store: store),
        ),
      );
      await tester.pumpAndSettle();
      await _tapKey(tester, 'auth-wechat');
      await tester.tapOnText(
        find.textRange.ofSubstring(
          '《隐私政策》',
          descendentOf: find.byType(AgreementDialog),
        ),
      );
      await tester.pumpAndSettle();
      _expectNoAuthRequests(api);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('auth-agree-continue')));
      await tester.pump(const Duration(milliseconds: 350));
      expect(api.calls.where((call) => call == 'WeChatLogin'), hasLength(1));
      expect(api.calls, isNot(contains('CreateCaptcha')));
      expect(api.calls, isNot(contains('SendSMS')));
      expect(launches, isEmpty);
      expect(
        tester
            .widget<Checkbox>(find.byKey(const ValueKey('auth-consent')))
            .value,
        isTrue,
      );
    },
  );

  testWidgets('Settings legal routes preserve session and stay in app', (
    tester,
  ) async {
    final api = FakeGateway();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: SettingsPage(store: store),
      ),
    );
    await tester.pumpAndSettle();
    // Settings itself loads the AI consent state; opening a document must not.
    final before = List<String>.of(api.calls);

    for (final entry in [
      ('settings-user-agreement', LegalDocumentKind.userAgreement),
      ('settings-privacy-policy', LegalDocumentKind.privacyPolicy),
    ]) {
      await _tapKey(tester, entry.$1);
      expect(find.byType(LegalDocumentPage), findsOneWidget);
      expect(
        tester.widget<LegalDocumentPage>(find.byType(LegalDocumentPage)).kind,
        entry.$2,
      );
      expect(api.calls, before);
      expect(launches, isEmpty);
      expect(store.isAuthenticated, isTrue);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('返回'), findsOneWidget);
      expect(store.isAuthenticated, isTrue);
    }
  });
}
