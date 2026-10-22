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

  test('Bundled documents retain sections, supplied identity and remaining placeholders', () {
    final terms = legalDocumentFor(LegalDocumentKind.userAgreement);
    final privacy = legalDocumentFor(LegalDocumentKind.privacyPolicy);
    expect(terms.sections.map((section) => section.title), [
      '第一条 定义',
      '第二条 服务内容与功能边界',
      '第三条 协议的订立与同意机制',
      '第四条 账号、登录与会话管理',
      '第五条 用户内容',
      '第六条 用户行为规范',
      '第七条 简历求指点与修改意见的特别约定',
      '第八条 积分与模板服务',
      '第九条 知识产权',
      '第十条 免责声明与责任限制',
      '第十一条 通知与送达',
      '第十二条 法律适用与争议解决',
      '第十三条 附则',
    ]);
    expect(privacy.sections.map((section) => section.title), [
      '一、我们如何收集和使用您的个人信息',
      '二、设备权限与本地功能说明',
      '三、对外提供（委托处理与共享）',
      '四、存储地点、期限与安全措施',
      '五、您的权利',
      '六、账号注销',
      '七、未成年人保护',
      '八、政策更新',
      '九、联系我们',
    ]);
    for (final document in [terms, privacy]) {
      expect(document.metadata, contains('更新日期：2026年10月【　】日'));
      expect(document.metadata, contains('生效日期：2026年10月【　】日'));
      expect(document.plainText, contains('【待补充：撤回渠道】'));
      expect(
        document.sections.map((section) => section.id).toSet(),
        hasLength(document.sections.length),
      );
      expect(
        document.introduction.every((paragraph) => paragraph.emphasized),
        isTrue,
      );
    }
    expect(terms.plainText, contains('【运营主体全称】'));
    expect(terms.plainText, contains('【客服邮箱/电话】'));
    expect(terms.plainText, contains('【待与业务确认余额处理规则】'));
    expect(terms.plainText, contains('【运营主体住所地】'));
    expect(terms.plainText, contains('template-purchase-v1'));
    expect(terms.plainText, contains('DOCX格式导出文件的正文为页面图像'));
    expect(terms.plainText, contains('字段过滤不等于匿名化处理'));
    expect(privacy.metadata, contains('版本：V2.0（替代2026年9月3日版本）'));
    expect(privacy.plainText, contains('完整源文件（包括其中的文字、照片及其他全部内容）'));
    expect(privacy.plainText, contains('该方式不属于端到端加密'));
    expect(privacy.plainText, contains('【最终清除及备份清理期限待补充】'));
    expect(privacy.plainText, contains('【待补充：最低使用年龄、年龄核验及监护人流程】'));
    expect(privacy.plainText, contains('珠海科岚盛网络科技有限公司'));
    expect(privacy.plainText, contains('个人信息保护负责人：冯子健'));
    expect(privacy.plainText, contains('fengzijian@kelantech.cn'));
    expect(
      privacy.sections.first.blocks.whereType<LegalSubheading>(),
      hasLength(15),
    );
  });

  test(
    'Privacy permissions and third-party disclosures retain all table cells',
    () {
      final tables = privacyPolicyDocument.sections
          .expand((section) => section.blocks)
          .whereType<LegalTable>()
          .toList();
      expect(tables, hasLength(2));
      expect(tables.first.headers, ['系统功能', '用途']);
      expect(tables.first.rows, hasLength(8));
      expect(tables.first.rows.map((row) => row.first), [
        '网络（INTERNET）',
        '系统文件选择器',
        '扫一扫相机',
        '系统相机与照片选择器',
        '系统分享面板',
        '剪贴板写入',
        '微信与抖音可见性查询（Android）',
        '通知与权限设置跳转',
      ]);
      expect(tables.first.plainText, contains('不自动读取剪贴板'));
      expect(tables.first.plainText, contains('不获取完整已安装应用列表'));
      expect(tables.first.plainText, contains('同意后用于身份证识别'));
      expect(tables.first.plainText, contains('相册仅访问您选中的照片'));
      expect(tables.last.headers, ['第三方', '数据与用途', '备注']);
      expect(tables.last.rows, hasLength(6));
      expect(tables.last.rows.map((row) => row.first), [
        '百度智能云（百度）',
        '七牛对象存储',
        '短信服务提供方【腾讯云/配置网关，待确认】',
        '微信开放平台 SDK（腾讯，Fluwx 接入）',
        '抖音开放平台 SDK',
        '外部AI文件解析及模型服务【主体待补充】',
      ]);
      expect(tables.last.plainText, contains('存储地域待补充'));
      expect(tables.last.plainText, contains('是否用于模型训练：待补充'));
      for (final table in tables) {
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
    final before = List<String>.of(api.calls);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: SettingsPage(store: store),
      ),
    );
    await tester.pumpAndSettle();

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
      expect(find.text('隐私与设置'), findsOneWidget);
      expect(store.isAuthenticated, isTrue);
    }
  });
}
