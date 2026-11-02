import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_link_share.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'resume_preview_menu_test.dart' show openPreview, action;
import 'support/fake_gateway.dart';

void main() {
  testWidgets(
    'Menu creates and copies link, then revokes it; failures preserve controls',
    (tester) async {
      final api = FakeGateway();
      final url = 'https://bojian.kelance.cn/resume-review/${'a' * 64}';
      api.documents['GetResumesIdExternalLink'] = {'active': false};
      api.documents['PostResumesIdExternalLink'] = {'active': true, 'url': url};
      api.documents['DeleteResumesIdExternalLink'] = {'active': false};
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      store.resumes.add(ResumeDraft(id: 42, title: '我的简历'));
      await openPreview(tester, store);
      await action(tester, 'request-help');
      expect(find.byType(ResumeLinkShare), findsOneWidget);
      expect(find.text('链接分享'), findsOneWidget);
      expect(find.text('找人帮改'), findsNothing);
      api.failing = 'PostResumesIdExternalLink';
      await tester.tap(find.byKey(const ValueKey('resume-link-copy')));
      await tester.pumpAndSettle();
      expect(copied, isNull);
      expect(find.text('服务器暂不可用'), findsOneWidget);
      api.failing = null;
      await tester.tap(find.byKey(const ValueKey('resume-link-copy')));
      await tester.pumpAndSettle();
      expect(copied, url);
      expect(find.text('复制链接'), findsOneWidget);
      api.failing = 'DeleteResumesIdExternalLink';
      await tester.tap(find.byKey(const ValueKey('resume-link-revoke')));
      await tester.pumpAndSettle();
      expect(find.text('停用链接'), findsOneWidget);
      api.failing = null;
      await tester.tap(find.byKey(const ValueKey('resume-link-revoke')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('resume-link-revoke')), findsNothing);
      expect(find.text('生成并复制链接'), findsOneWidget);
    },
  );

  testWidgets('Account change prevents link generation', (tester) async {
    final api = FakeGateway()
      ..documents['GetResumesIdExternalLink'] = {'active': false};
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResumeLinkShare(
            store: store,
            resume: ResumeDraft(id: 42, title: '我的简历'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await store.endSession(remote: false);
    await tester.tap(find.byKey(const ValueKey('resume-link-copy')));
    await tester.pumpAndSettle();
    expect(api.calls, isNot(contains('PostResumesIdExternalLink')));
    expect(find.text('账号已切换，请重试'), findsOneWidget);
  });
}
