import 'dart:convert';

import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:bojian_mobile/feed_media.dart';
import 'package:bojian_mobile/feed_video.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAEUlEQVR4nGNwmHAAjhiI4wAAglIZAaTN9MkAAAAASUVORK5CYII=',
);

Story photoPost(int count) => decodeStory({
  'id': 51,
  'author': {'id': 9, 'display_name': '作者昵称'},
  'title': '',
  'content': {
    'blocks': [
      {
        'kind': 'paragraph',
        'spans': [
          {'text': '周末出去玩'},
        ],
      },
      for (var i = 0; i < count; i++)
        {
          'kind': 'image',
          'image': {'file_id': 100 + i},
        },
    ],
  },
});

Future<void> mount(
  WidgetTester tester,
  AppStore store,
  Story story, {
  bool dark = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? appDarkTheme : appTheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: StoryCard(story: story, store: store, flat: true),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final imageFor = FeedGallery.imageFor;
  setUp(() {
    clearArticleMediaURLs();
    FeedGallery.imageFor = (_, [_ = '']) => MemoryImage(_png);
  });
  tearDown(() => FeedGallery.imageFor = imageFor);

  Future<AppStore> store() async {
    final api = FakeGateway()
      ..documents['GetFilesIdArticleMedia'] = {
        'url': 'https://media.example.com/photo.png',
      };
    return testStore(authenticated: true, api: api);
  }

  test('The card summary leaves out the pictures it shows', () {
    final story = photoPost(2);
    expect(story.excerpt, '周末出去玩\n[图片]\n[图片]');
    expect(story.feedMedia, hasLength(2));
    expect(story.cardExcerpt, '周末出去玩');
  });

  for (final dark in [false, true]) {
    testWidgets('Feed cards show their pictures (dark=$dark)', (tester) async {
      final appStore = await store();
      addTearDown(appStore.dispose);
      await mount(tester, appStore, photoPost(3), dark: dark);
      expect(find.textContaining('[图片]'), findsNothing);
      expect(find.text('周末出去玩'), findsOneWidget);
      for (final id in [100, 101, 102]) {
        expect(find.byKey(ValueKey('feed-photo-f$id')), findsOneWidget);
      }
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('feed-photo-f101')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(FeedMediaViewer), findsOneWidget);
      expect(find.text('2/3'), findsOneWidget);
      expect(find.byType(StoryDetail), findsNothing);
    });
  }

  testWidgets('Grids ask for thumbnails and the viewer for previews', (
    tester,
  ) async {
    final asked = <(String, String)>[];
    FeedGallery.imageFor = (url, [original = '']) {
      asked.add((url, original));
      return MemoryImage(_png);
    };
    const file = 'https://media.example.com/photo.jpg';
    final api = FakeGateway()
      ..documents['GetFilesIdArticleMedia'] = {
        'url': file,
        'thumbnail_url': '$file?small',
        'preview_url': '$file?large',
      };
    final appStore = await testStore(authenticated: true, api: api);
    addTearDown(appStore.dispose);
    await mount(tester, appStore, photoPost(3));
    expect(asked.toSet(), {('$file?small', file)});
    asked.clear();
    await tester.tap(find.byKey(const ValueKey('feed-photo-f101')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(asked, contains(('$file?large', file)));
    expect(asked.map((a) => a.$1), isNot(contains('$file?small')));
  });

  test('A file without renditions is used as it is', () async {
    final appStore = await store();
    addTearDown(appStore.dispose);
    const media = FeedMedia(fileID: 100);
    for (final small in [true, false]) {
      expect(await media.picture(appStore, 52, small: small), (
        url: 'https://media.example.com/photo.png',
        original: '',
      ));
    }
  });

  testWidgets('More than nine pictures show the rest as a count', (
    tester,
  ) async {
    final appStore = await store();
    addTearDown(appStore.dispose);
    await mount(tester, appStore, photoPost(11));
    expect(find.byKey(const ValueKey('feed-photo-f108')), findsOneWidget);
    expect(find.byKey(const ValueKey('feed-photo-f109')), findsNothing);
    expect(find.text('+2'), findsOneWidget);
  });

  testWidgets('A single picture stays modest within the card', (tester) async {
    final appStore = await store();
    addTearDown(appStore.dispose);
    await mount(tester, appStore, photoPost(1));
    // The visible box, not the full-width row that aligns it.
    final box = tester.getSize(
      find.descendant(
        of: find.byKey(const ValueKey('feed-photo-f100')),
        matching: find.byType(ClipRRect),
      ),
    );
    final card = tester.getSize(find.byType(StoryCard));
    expect(box.width, lessThan(card.width * 0.85));
    expect(box.height, lessThanOrEqualTo(320));
    // Square, or barely wider, is no reason to fill the card.
    expect(loneMediaSize(320, 1).width, moreOrLessEquals(320 * 0.62));
    expect(loneMediaSize(320, 1.03).width, lessThan(320 * 0.65));
    expect(loneMediaSize(320, 16 / 9).width, 320);
    expect(tester.takeException(), isNull);
  });

  Story mixedPost(List<Map<String, dynamic>> extra) => decodeStory({
    'id': 52,
    'author': {'id': 9, 'display_name': '作者昵称'},
    'title': '',
    'content': {
      'blocks': [
        {
          'kind': 'video',
          'video': {'file_id': 7, 'duration_ms': 32000},
        },
        {
          'kind': 'image',
          'image': {'file_id': 100},
        },
        {
          'kind': 'video',
          'video': {'file_id': 8, 'duration_ms': 83000},
        },
        ...extra,
      ],
    },
  });

  test('Only the author\'s words make the summary; the rest are entries', () {
    final story = mixedPost([
      {'kind': 'poll', 'poll_id': 5, 'title': '午餐'},
      {'kind': 'link', 'url': 'https://example.com/a'},
      {'kind': 'link', 'url': 'https://example.org/b'},
      {'kind': 'table'},
    ]);
    expect(story.cardExcerpt, isEmpty);
    expect(story.feedMedia.map((item) => item.video), [true, false, true]);
    expect(story.feedAttachments.map((entry) => entry.label), [
      '投票：午餐',
      '链接：example.com 等 2 个',
    ]);
    final table = decodeStory({
      'id': 53,
      'content': {
        'blocks': [
          {'kind': 'table'},
        ],
      },
    });
    expect(table.feedAttachments.single.kind, 'table');
  });

  testWidgets('Mixed media share one grid in the author\'s order', (
    tester,
  ) async {
    final appStore = await store();
    addTearDown(appStore.dispose);
    final createController = FeedVideo.createController;
    addTearDown(() => FeedVideo.createController = createController);
    var opened = 0;
    FeedVideo.createController = (_) {
      opened++;
      throw StateError('no decoder in widget tests');
    };
    await mount(
      tester,
      appStore,
      mixedPost([
        {'kind': 'link', 'url': 'https://example.com/a'},
      ]),
    );
    expect(find.textContaining('['), findsNothing);
    expect(find.text('链接：example.com'), findsOneWidget);
    final first = tester.getRect(find.byKey(const ValueKey('feed-video-7')));
    final photo = tester.getRect(find.byKey(const ValueKey('feed-photo-f100')));
    final last = tester.getRect(find.byKey(const ValueKey('feed-video-8')));
    expect([photo.size, last.size], [first.size, first.size]);
    expect(first.width, moreOrLessEquals(first.height));
    expect(photo.left, greaterThan(first.right));
    expect(last.left, greaterThan(photo.right));
    expect(find.text('00:32'), findsOneWidget);
    expect(find.text('01:23'), findsOneWidget);

    // Only the first video of the row starts by itself.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(opened, 1);

    await tester.tap(find.byKey(const ValueKey('feed-video-play-8')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(FeedMediaViewer), findsOneWidget);
    expect(find.text('3/3'), findsOneWidget);
    expect(find.text('视频加载失败，重试'), findsOneWidget);
    expect(find.byType(StoryDetail), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
