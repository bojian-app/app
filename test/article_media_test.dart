import 'dart:convert';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/article_media_picker.dart';
import 'package:bojian_mobile/article_photo.dart';
import 'package:bojian_mobile/resume_importer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';

import 'support/fake_gateway.dart';

const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAEUlEQVR4nGNwmHAAjhiI4wAAglIZAaTN9MkAAAAASUVORK5CYII=';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppStore store;
  late FakeGateway api;
  setUp(() async {
    api = FakeGateway();
    store = AppStore(api: api, storage: MemoryStorage());
    await store.initialize();
    store.session = {'access_token': 'test'};
    api.documents['PostFilesUploads'] = {'id': 29};
  });
  tearDown(() => store.dispose());

  test(
    'Completed image and video references survive draft serialization',
    () async {
      final photo = XFile.fromData(
        base64Decode(_png),
        path: 'photo.png',
        length: 74,
      );
      final media = await checkArticleMedia(photo);
      final still = await uploadArticleMedia(
        store,
        media,
        epoch: store.epoch,
        transfer: (auth, file, mime) async {
          expect(mime, 'image/png');
        },
      );
      final clip = PickedArticleMedia(
        XFile.fromData(
          await photo.readAsBytes(),
          path: 'video.mp4',
          length: 74,
        ),
        'video/mp4',
        duration: const Duration(seconds: 9),
      );
      final movie = await uploadArticleMedia(
        store,
        clip,
        epoch: store.epoch,
        transfer: (auth, file, mime) async {
          expect(mime, 'video/mp4');
        },
      );
      expect(jsonDecode(jsonEncode([still, movie])), [
        {
          'kind': 'image',
          'image': {'file_id': 29},
        },
        {
          'kind': 'video',
          'video': {'file_id': 29, 'duration_ms': 9000},
        },
      ]);
      expect(api.calls, [
        'PostFilesUploads',
        'PostFilesUploadsIdComplete',
        'PostFilesUploads',
        'PostFilesUploadsIdComplete',
      ]);
    },
  );

  test('Renamed gallery images upload using their actual format', () async {
    final bytes = base64Decode(_png);
    for (final name in ['photo.jpg', 'gallery-item', 'photo.mp4']) {
      final file = XFile.fromData(bytes, path: name, length: bytes.length);
      final media = await checkArticleMedia(file);
      expect(media.isVideo, isFalse);
      final block = await uploadArticleMedia(
        store,
        media,
        epoch: store.epoch,
        transfer: (_, uploadedFile, mime) async {
          expect(api.lastBody?['filename'], endsWith('.png'));
          expect(api.lastBody?['content_type'], 'image/png');
          expect(mime, 'image/png');
          expect(await uploadedFile.readAsBytes(), bytes);
        },
      );
      expect(block['kind'], 'image');
    }
  });

  test(
    'Multipart uploads send the in-memory PNG with its correct name',
    () async {
      final bytes = base64Decode(_png);
      final photo = XFile.fromData(bytes, path: 'missing/gallery-export.jpg');
      final client = MockClient((request) async {
        final body = latin1.decode(request.bodyBytes);
        expect(body, contains('name="file"; filename="gallery-export.png"'));
        expect(body, contains('content-type: image/png'));
        expect(body, contains('\r\n\r\n${latin1.decode(bytes)}\r\n--'));
        return http.Response('', 200);
      });
      addTearDown(client.close);
      await uploadResumeDocument(
        {
          'upload_url': 'https://upload.example.com',
          'method': 'POST',
          'fields': {'token': 'test-token', 'key': 'test-photo'},
        },
        photo,
        'image/png',
        client: client,
      );
    },
  );

  test(
    'An incomplete media upload never produces an embeddable reference',
    () async {
      final media = PickedArticleMedia(
        XFile.fromData(base64Decode('AA=='), path: 'a.png', length: 1),
        'image/png',
      );
      await expectLater(
        uploadArticleMedia(
          store,
          media,
          epoch: store.epoch,
          transfer: (_, _, _) async {
            throw const ApiFailure('断网');
          },
        ),
        throwsA(isA<ApiFailure>()),
      );
      expect(api.calls, ['PostFilesUploads']);
    },
  );

  testWidgets(
    'Empty selection, camera, album and video duration instructions',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ArticleMediaPicker()));
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '下一步(0)'))
            .onPressed,
        isNull,
      );
      expect(find.text('拍摄'), findsOneWidget);
      expect(find.text('相册'), findsOneWidget);
      await tester.tap(find.byTooltip('上传说明'));
      await tester.pumpAndSettle();
      expect(find.textContaining('5分钟'), findsOneWidget);
      await tester.tap(find.text('知道了'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('拍摄'));
      await tester.pumpAndSettle();
      expect(find.text('拍照'), findsOneWidget);
      expect(find.text('录视频'), findsOneWidget);
    },
  );

  testWidgets('The picker shows how many more the post can take', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: ArticleMediaPicker(limit: 4)),
    );
    expect(find.text('下一步(0/4)'), findsOneWidget);
    await tester.tap(find.byTooltip('上传说明'));
    await tester.pumpAndSettle();
    expect(find.textContaining('最多 9 个图片或视频'), findsOneWidget);
  });
}
