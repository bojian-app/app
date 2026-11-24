import 'package:bojian_mobile/ai_consent.dart';
import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_ai_optimization_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

Future<void> open(WidgetTester tester, AppStore store) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ResumeAIOptimizationPage(
        store: store,
        resume: ResumeDraft(
          id: 42,
          title: '简历',
          source: {
            'projects': [
              {'name': '平台'},
            ],
          },
        ),
      ),
    ),
  );
  // The page shows a running progress indicator behind the dialog.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

class RefusingGateway extends FakeGateway {
  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) {
    if (method == 'PostResumeWorkDescriptions') {
      throw const ApiFailure('请先同意', code: aiConsentRequiredCode);
    }
    return super.call(
      method,
      path: path,
      query: query,
      body: body,
      headers: headers,
    );
  }
}

FakeGateway gateway() => FakeGateway()
  ..documents['GetResumesIdPolishJobs'] = {'id': null}
  ..documents['PostResumesIdPolishJobs'] = {'id': 12, 'status': 'QUEUED'}
  ..documents['GetPolishJobsId'] = {'status': 'RUNNING'};

void main() {
  testWidgets('Declining AI consent sends nothing to the model', (
    tester,
  ) async {
    final api = gateway();
    final store = await testStore(
      authenticated: true,
      aiConsentGranted: false,
      api: api,
    );
    addTearDown(store.dispose);
    await open(tester, store);
    expect(find.byType(AiConsentDialog), findsOneWidget);
    expect(find.textContaining('api-service@deepseek.com'), findsOneWidget);
    expect(find.textContaining('模型训练'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ai-consent-decline')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(api.calls, isNot(contains('PostResumesIdPolishJobs')));
    expect(await AiConsent.granted(store), isFalse);
  });

  testWidgets('Accepting AI consent is remembered per account', (tester) async {
    final api = gateway();
    final store = await testStore(
      authenticated: true,
      aiConsentGranted: false,
      api: api,
    );
    addTearDown(store.dispose);
    await open(tester, store);
    await tester.tap(find.byKey(const ValueKey('ai-consent-accept')));
    await tester.pump();
    await tester.pump();
    expect(
      api.calls,
      containsAllInOrder(['PutMeAiConsent', 'PostResumesIdPolishJobs']),
    );
    expect(await AiConsent.granted(store), isTrue);
    expect(
      await store.storage.read(aiConsentStorageKey(store.userID + 1)),
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
  });

  test('Withdrawing AI consent is recorded on the server', () async {
    final api = FakeGateway();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    expect(await AiConsent.granted(store), isTrue);
    await AiConsent.withdraw(store);
    expect(api.calls, contains('DeleteMeAiConsent'));
    expect(await AiConsent.granted(store), isFalse);
    expect(await AiConsent.refresh(store), isFalse);
  });

  testWidgets('Consent given on another install skips the dialog', (
    tester,
  ) async {
    final api = gateway()
      ..documents['GetMeAiConsent'] = {
        'granted': true,
        'version': aiConsentVersion,
      };
    final store = await testStore(
      authenticated: true,
      aiConsentGranted: false,
      api: api,
    );
    addTearDown(store.dispose);
    await open(tester, store);
    expect(find.byType(AiConsentDialog), findsNothing);
    expect(api.calls, contains('PostResumesIdPolishJobs'));
    expect(await AiConsent.granted(store), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  test('Server refusal clears the cached consent', () async {
    final api = RefusingGateway();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await expectLater(
      store.request('PostResumeWorkDescriptions', body: const {}),
      throwsA(isA<ApiFailure>()),
    );
    expect(await AiConsent.granted(store), isFalse);
  });
}
