import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/legal_document_page.dart';
import 'package:bojian_mobile/main.dart';
import 'package:bojian_mobile/privacy_consent.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  const settings = MethodChannel('cn.kelance.bojian/settings');
  final calls = <String>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(settings, (call) async {
          calls.add(call.method);
          return call.method == 'deviceInfo'
              ? {'model': 'PJD110', 'os_version': '15', 'stable_id': 'abc'}
              : null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(settings, null);
  });

  Future<(AppStore, MemoryStorage, FakeGateway)> pumpApp(
    WidgetTester tester, {
    MemoryStorage? storage,
  }) async {
    final memory = storage ?? MemoryStorage();
    final api = FakeGateway();
    final store = AppStore(api: api, storage: memory);
    await tester.pumpWidget(
      MyApp(
        startupAnimationEnabled: false,
        bannerAdsEnabled: false,
        store: store,
        requirePrivacyConsent: true,
      ),
    );
    await tester.pumpAndSettle();
    return (store, memory, api);
  }

  testWidgets('First launch asks for consent before reading the device', (
    tester,
  ) async {
    final (store, storage, api) = await pumpApp(tester);
    expect(find.byType(PrivacyConsentDialog), findsOneWidget);
    expect(calls, isNot(contains('deviceInfo')));
    expect(store.deviceID, isEmpty);
    expect(api.calls, isEmpty);

    // 阅读协议不等于同意。
    await tester.tapOnText(
      find.textRange.ofSubstring(
        '《隐私政策》',
        descendentOf: find.byType(PrivacyConsentDialog),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LegalDocumentPage), findsOneWidget);
    Navigator.of(tester.element(find.byType(LegalDocumentPage))).pop();
    await tester.pumpAndSettle();
    expect(calls, isNot(contains('deviceInfo')));

    // 拒绝后二次提示，选择再次查看回到弹窗，仍不读取设备信息。
    await tester.tap(find.byKey(const ValueKey('privacy-consent-decline')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('privacy-consent-review')));
    await tester.pumpAndSettle();
    expect(find.byType(PrivacyConsentDialog), findsOneWidget);
    expect(calls, isNot(contains('deviceInfo')));
    expect(storage.values, isNot(contains(PrivacyConsent.storageKey)));

    await tester.tap(find.byKey(const ValueKey('privacy-consent-accept')));
    await tester.pumpAndSettle();
    expect(find.byType(PrivacyConsentDialog), findsNothing);
    expect(calls, contains('deviceInfo'));
    expect(store.deviceID, isNotEmpty);
    expect(
      storage.values[PrivacyConsent.storageKey],
      PrivacyConsent.currentVersion,
    );
  });

  testWidgets('Consent for the current version is not asked again', (
    tester,
  ) async {
    final storage = MemoryStorage()
      ..values[PrivacyConsent.storageKey] = PrivacyConsent.currentVersion;
    final (store, _, _) = await pumpApp(tester, storage: storage);
    expect(find.byType(PrivacyConsentDialog), findsNothing);
    expect(calls, contains('deviceInfo'));
    expect(store.deviceID, isNotEmpty);
  });

  testWidgets('An older consent version asks again', (tester) async {
    final storage = MemoryStorage()
      ..values[PrivacyConsent.storageKey] = 'terms:1.0,privacy:1.0';
    await pumpApp(tester, storage: storage);
    expect(find.byType(PrivacyConsentDialog), findsOneWidget);
    expect(calls, isNot(contains('deviceInfo')));
  });
}
