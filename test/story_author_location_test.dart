import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:bojian_mobile/story_author_identity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

Story article({
  required int authorID,
  String city = '',
  bool guidance = false,
}) => decodeStory({
  'id': guidance ? 2 : 1,
  'author': {'id': authorID, 'display_name': '作者昵称', 'city': city},
  'title': '真实内容标题',
  'content': guidance
      ? {'kind': 'RESUME_GUIDANCE', 'question': '想请大家帮我看看简历'}
      : richContent('文章正文'),
});

Future<void> mount(
  WidgetTester tester,
  AppStore store,
  Story story, {
  bool dark = false,
  double scale = 1,
}) => tester.pumpWidget(
  MaterialApp(
    theme: dark ? appDarkTheme : appTheme,
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Scaffold(
        body: SingleChildScrollView(
          child: StoryCard(story: story, store: store, flat: true),
        ),
      ),
    ),
  ),
);

void main() {
  for (final guidance in [false, true]) {
    testWidgets('Author location belongs to the author (guidance=$guidance)', (
      tester,
    ) async {
      final api = FakeGateway()..documents['GetMe']!['city'] = '广东省';
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await mount(
        tester,
        store,
        article(authorID: store.userID + 1, city: ' 浙江省 ', guidance: guidance),
      );
      expect(find.text('IP属地：浙江'), findsOneWidget);
      expect(find.textContaining('广东'), findsNothing);
      final identity = find.byType(StoryAuthorIdentity);
      final name = find.descendant(of: identity, matching: find.text('作者昵称'));
      expect(
        tester.getTopLeft(find.text('IP属地：浙江')).dy,
        greaterThan(tester.getBottomLeft(name).dy),
      );
      // Other authors without a location never inherit the viewer's location.
      await mount(tester, store, article(authorID: 0, guidance: guidance));
      expect(find.textContaining('IP属地'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Own location follows authenticated profile updates ($guidance)',
      (tester) async {
        final api = FakeGateway()..documents['GetMe']!['city'] = '浙江省';
        final store = await testStore(authenticated: true, api: api);
        addTearDown(store.dispose);
        await mount(
          tester,
          store,
          article(authorID: store.userID, city: '旧属地', guidance: guidance),
        );
        expect(find.text('IP属地：浙江'), findsOneWidget);
        api.documents['GetMe']!['city'] = '广东省';
        await store.load('profile');
        await tester.pump();
        expect(find.text('IP属地：广东'), findsOneWidget);
        expect(find.textContaining('浙江'), findsNothing);
        api.documents['GetMe']!.remove('city');
        await store.load('profile');
        await tester.pump();
        expect(find.textContaining('IP属地'), findsNothing);
        await store.endSession(remote: false);
        await tester.pump();
        expect(find.textContaining('广东'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final dark in [false, true]) {
    testWidgets('Small author information fits narrow large text ($dark)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = await testStore();
      addTearDown(store.dispose);
      for (final guidance in [false, true]) {
        await mount(
          tester,
          store,
          article(authorID: 2, city: '香港特别行政区', guidance: guidance),
          dark: dark,
          scale: 2,
        );
        final location = find.text('IP属地：香港特别行政区');
        expect(location, findsOneWidget);
        final text = tester.widget<Text>(location);
        expect(text.style!.fontSize, 10);
        expect(text.maxLines, 1);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
