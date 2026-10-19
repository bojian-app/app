import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/guidance_feed_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

Story guidance({int? count}) => decodeStory({
  'id': 9,
  'title': '前端开发工程师-4年-标准简历',
  'author': {'id': 2, 'display_name': '测试作者'},
  'content': {'kind': 'RESUME_GUIDANCE', 'question': '想请大家帮我看看这份简历，有哪些地方可以改进？'},
  'guidance_participant_count': ?count,
  'published_at': '2026-10-18T08:00:00Z',
});

void main() {
  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Question precedes the resume with a real participant total ($dark, $scale)',
        (tester) async {
          tester.view.physicalSize = const Size(320, 720);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final store = await testStore();
          addTearDown(store.dispose);
          final story = guidance(count: 123);
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? appDarkTheme : appTheme,
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: GuidanceFeedCard(
                      story: story,
                      store: store,
                      flat: true,
                    ),
                  ),
                ),
              ),
            ),
          );
          final question = find.byKey(const ValueKey('guidance-question-9'));
          final resume = find.byKey(const ValueKey('guidance-resume-title-9'));
          expect(
            tester.getBottomLeft(question).dy,
            lessThan(tester.getTopLeft(resume).dy),
          );
          // The question is plain content, without a decorated green panel.
          expect(
            find.ancestor(of: question, matching: find.byType(DecoratedBox)),
            findsNothing,
          );
          expect(find.text('123 人参与'), findsOneWidget);
          story.guidanceParticipantCount = 124;
          store.changed();
          await tester.pump();
          expect(find.text('124 人参与'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('Unknown participation never becomes a fabricated zero', (
    tester,
  ) async {
    final store = await testStore();
    addTearDown(store.dispose);
    final story = guidance();
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: GuidanceFeedCard(story: story, store: store, flat: true),
        ),
      ),
    );
    expect(find.text('参与人数暂不可用'), findsOneWidget);
    expect(find.text('0 人参与'), findsNothing);
    story.guidanceParticipantCount = 0;
    store.changed();
    await tester.pump();
    expect(find.text('0 人参与'), findsOneWidget);
  });
  test('Returning from guidance refreshes the confirmed total', () async {
    final api = FakeGateway();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    final story = guidance(count: 2);
    store.stories.add(story);
    api.documents['GetArticlesId'] = {'id': 9, 'guidance_participant_count': 3};
    await store.refreshGuidanceParticipants(story);
    expect(story.guidanceParticipantCount, 3);
    api.failing = 'GetArticlesId';
    await store.refreshGuidanceParticipants(story);
    expect(story.guidanceParticipantCount, 3);
  });
}
