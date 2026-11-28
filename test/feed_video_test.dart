import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:bojian_mobile/feed_media.dart';
import 'package:bojian_mobile/feed_video.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

import 'support/fake_gateway.dart';

Story videoPost() => decodeStory({
  'id': 41,
  'author': {'id': 9, 'display_name': '作者昵称'},
  'title': '',
  'content': {
    'blocks': [
      {
        'kind': 'paragraph',
        'spans': [
          {'text': '这效果做的真好'},
        ],
      },
      {
        'kind': 'video',
        'video': {'file_id': 7, 'duration_ms': 83000},
      },
    ],
  },
});

Future<void> mount(WidgetTester tester, AppStore store, {bool dark = false}) =>
    tester.pumpWidget(
      MaterialApp(
        theme: dark ? appDarkTheme : appTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StoryCard(story: videoPost(), store: store, flat: true),
          ),
        ),
      ),
    );

void main() {
  final createController = FeedVideo.createController;
  setUp(clearArticleMediaURLs);
  tearDown(() => FeedVideo.createController = createController);

  test('The card summary leaves out the video it plays', () {
    final story = videoPost();
    expect(story.excerpt, '这效果做的真好\n[视频]');
    expect(story.feedMedia.single.video, isTrue);
    expect(story.feedMedia.single.data, {'file_id': 7, 'duration_ms': 83000});
    expect(story.cardExcerpt, '这效果做的真好');
  });

  for (final dark in [false, true]) {
    testWidgets(
      'Feed cards show a video player, fetched on play (dark=$dark)',
      (tester) async {
        final api = FakeGateway()
          ..documents['GetFilesIdArticleMedia'] = {
            'url': 'https://media.example.com/clip.mp4',
          };
        final store = await testStore(authenticated: true, api: api);
        addTearDown(store.dispose);
        final opened = <Uri>[];
        FeedVideo.createController = (url) {
          opened.add(url);
          throw StateError('no decoder in widget tests');
        };

        await mount(tester, store, dark: dark);
        expect(find.byKey(const ValueKey('feed-video-7')), findsOneWidget);
        expect(find.textContaining('[视频]'), findsNothing);
        expect(find.text('这效果做的真好'), findsOneWidget);
        expect(find.text('01:23'), findsOneWidget);
        // Nothing is requested or decoded before the reader presses play.
        expect(api.calls, isNot(contains('GetFilesIdArticleMedia')));
        expect(opened, isEmpty);
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const ValueKey('feed-video-play-7')));
        await tester.pumpAndSettle();
        expect(api.calls, contains('GetFilesIdArticleMedia'));
        expect(opened, [Uri.parse('https://media.example.com/clip.mp4')]);
        // A failed load stays on the card with a retry, not the post page.
        expect(find.byKey(const ValueKey('feed-video-retry')), findsOneWidget);
        expect(find.byType(StoryDetail), findsNothing);
        expect(find.byType(VideoPlayer), findsNothing);
      },
    );
  }

  testWidgets('A video in view starts by itself once scrolling settles', (
    tester,
  ) async {
    final api = FakeGateway()
      ..documents['GetFilesIdArticleMedia'] = {
        'url': 'https://media.example.com/clip.mp4',
      };
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    final opened = <Uri>[];
    FeedVideo.createController = (url) {
      opened.add(url);
      throw StateError('no decoder in widget tests');
    };

    await mount(tester, store);
    await tester.pump(const Duration(milliseconds: 100));
    expect(opened, isEmpty);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(api.calls, contains('GetFilesIdArticleMedia'));
    expect(opened, [Uri.parse('https://media.example.com/clip.mp4')]);
    // A failed autoplay waits for the reader instead of trying again.
    expect(find.byKey(const ValueKey('feed-video-retry')), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(opened, hasLength(1));
  });
}
