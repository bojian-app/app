import 'dart:convert';
import 'dart:io';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:bojian_mobile/resume_photo.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late XFile photo;
  late FakeGateway gateway;
  late AppStore store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('resume-photo-test-');
    final file = File('${directory.path}/photo.png');
    await file.writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAEUlEQVR4nGNwmHAAjhiI4wAAglIZAaTN9MkAAAAASUVORK5CYII=',
      ),
    );
    photo = XFile(file.path);
    gateway = FakeGateway();
    store = AppStore(api: gateway, storage: MemoryStorage());
    await store.initialize();
    store.session = {'access_token': 'test'};
    gateway.documents['PostResumesIdPhotoUploads'] = {'id': 9};
    gateway.documents['PostResumesIdPhotoCommit'] = {
      'id': 1,
      'revision': 8,
      'title': '简历',
      'photo_file_id': 9,
      'photo_url': 'https://example.com/portrait.png',
      'content': <String, dynamic>{},
    };
  });
  tearDown(() async {
    store.dispose();
    await directory.delete(recursive: true);
  });

  test('Resume photo metadata survives decoding and copying', () {
    final draft = decodeResume(gateway.documents['PostResumesIdPhotoCommit']!)
        .copy();
    expect(draft.photoFileID, 9);
    expect(draft.photoURL, 'https://example.com/portrait.png');
  });

  test(
    'Photo is uploaded, completed then committed to the same resume',
    () async {
      var uploaded = false;
      final result = await uploadResumePhoto(
        store,
        ResumeDraft(id: 1, title: '简历'),
        photo,
        upload: (auth, file, mime) async {
          expect(auth['id'], 9);
          expect(mime, 'image/png');
          expect(file.name, 'photo.png');
          uploaded = true;
        },
      );
      expect(uploaded, isTrue);
      expect(gateway.calls, [
        'PostResumesIdPhotoUploads',
        'PostFilesUploadsIdComplete',
        'PostResumesIdPhotoCommit',
        'GetResumes',
      ]);
      expect(result.revision, 8);
      expect(result.photoFileID, 9);
    },
  );

  test('Failed completion does not commit a photo', () async {
    gateway.failing = 'PostFilesUploadsIdComplete';
    await expectLater(
      uploadResumePhoto(
        store,
        ResumeDraft(id: 1, title: '简历'),
        photo,
        upload: (_, _, _) async {},
      ),
      throwsA(isA<ApiFailure>()),
    );
    expect(gateway.calls, isNot(contains('PostResumesIdPhotoCommit')));
  });

  test(
    'Changed session during upload prevents completion and commit',
    () async {
      await expectLater(
        uploadResumePhoto(
          store,
          ResumeDraft(id: 1, title: '简历'),
          photo,
          upload: (_, _, _) async {
            store.epoch++;
          },
        ),
        throwsA(isA<ApiFailure>()),
      );
      expect(gateway.calls, ['PostResumesIdPhotoUploads']);
    },
  );

  test('Invalid image never requests an upload authorization', () async {
    await File(photo.path).writeAsString('not a photo');
    await expectLater(
      uploadResumePhoto(
        store,
        ResumeDraft(id: 1, title: '简历'),
        photo,
        upload: (_, _, _) async {},
      ),
      throwsA(isA<ApiFailure>()),
    );
    expect(gateway.calls, isEmpty);
  });

  testWidgets('New resume editor exposes an avatar upload control', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ResumeEditor(
          store: store,
          draft: ResumeDraft(id: 0, title: '新的简历'),
        ),
      ),
    );
    expect(find.text('简历头像'), findsOneWidget);
    expect(find.text('上传头像'), findsOneWidget);
    expect(gateway.calls, isEmpty);
  });
}
