import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bojian_mobile/network_image_cache.dart';
import 'package:bojian_mobile/profile_avatar.dart';
import 'package:bojian_mobile/resume_photo_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Signatures do not change an image identity', () {
    const object = 'https://cdn.example.com/users/1/AVATAR/1-a.png';
    expect(stableImageKey('$object?e=1700000000&token=ak:sig1'), object);
    expect(stableImageKey('$object?e=1800000000&token=ak:sig2'), object);
    expect(
      stableImageKey(
        '$object?X-Amz-Expires=900&X-Amz-Signature=abc&imageView2=1',
      ),
      '$object?imageView2=1',
    );
    expect(
      stableImageKey('$object?token=only-content-token'),
      contains('token'),
    );
    expect(
      CachedNetworkImage('$object?e=1&token=a'),
      CachedNetworkImage('$object?e=2&token=b'),
    );
    expect(
      profileAvatarImage('$object?e=1&token=a'),
      profileAvatarImage('$object?e=2&token=b'),
    );
    const fixed = 'https://api.example.com/api/v1/resumes/1/photo/token';
    expect(
      const ResumePhotoImage(fixed, fileID: 1),
      isNot(const ResumePhotoImage(fixed, fileID: 2)),
    );
  });

  group('NetworkImageStore', () {
    late Directory directory;
    late int downloads;
    late NetworkImageStore previous;
    NetworkImageStore store({bool fail = false}) => NetworkImageStore(
      directory: () async => directory,
      download: (url) async {
        downloads++;
        if (fail) throw const HttpException('expired');
        return Uint8List.fromList(url.toString().codeUnits);
      },
    );

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('image-cache-test-');
      downloads = 0;
      previous = NetworkImageStore.instance;
    });
    tearDown(() async {
      NetworkImageStore.instance = previous;
      await directory.delete(recursive: true);
    });

    test('Bytes are kept on disk under the stable key', () async {
      const key = 'https://cdn.example.com/a.png';
      final first = store();
      final results = await Future.wait([
        first.load('$key?e=1&token=a', key),
        first.load('$key?e=1&token=a', key),
      ]);
      expect(downloads, 1);
      // A new signature in a later session is served from disk.
      final reopened = store(fail: true);
      expect(await reopened.load('$key?e=2&token=b', key), results.first);
      expect(downloads, 1);
      expect(await reopened.diskBytes(), greaterThan(0));
      await reopened.clear();
      expect(await reopened.read(key), isNull);
    });

    test('Failed downloads are not cached', () async {
      const key = 'https://cdn.example.com/b.png';
      await expectLater(store(fail: true).load(key, key), throwsA(anything));
      expect(await store().read(key), isNull);
      await store().load(key, key);
      expect(downloads, 2);
    });

    testWidgets('A rendition that cannot be had gives way to the original', (
      tester,
    ) async {
      final asked = <String>[];
      await tester.runAsync(() async {
        final file = await createSystemAvatarFile(3);
        final png = await file.readAsBytes();
        await discardSystemAvatarFile(file);
        NetworkImageStore.instance = NetworkImageStore(
          directory: () async => directory,
          download: (url) async {
            asked.add('$url');
            if (url.query.contains('imageMogr2')) {
              throw const HttpException('too large to resize');
            }
            return png;
          },
        );
        const object = 'https://cdn.example.com/users/9/POST_ASSET/long.png';
        const rendition =
            '$object?imageMogr2/auto-orient%7CimageView2/3/w/1440/h/1440/q/85'
            '&e=1&token=a';
        const original = '$object?e=1&token=b';
        // Each size is its own file on the device.
        expect(stableImageKey(rendition), isNot(stableImageKey(original)));
        expect(
          stableImageKey(rendition),
          stableImageKey(rendition.replaceFirst('e=1&token=a', 'e=2&token=c')),
        );
        // The signature covers the address as the server wrote it.
        expect(Uri.parse(rendition).toString(), rendition);
        final loaded = Completer<void>();
        final stream = const CachedNetworkImage(
          rendition,
          fallback: original,
        ).resolve(ImageConfiguration.empty);
        final listener = ImageStreamListener(
          (_, _) => loaded.complete(),
          onError: (error, _) => loaded.completeError(error),
        );
        stream.addListener(listener);
        await loaded.future;
        stream.removeListener(listener);
      });
      expect(asked.map((url) => url.contains('imageMogr2')), [true, false]);
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
    });

    testWidgets('One avatar download serves every page and size', (
      tester,
    ) async {
      final png = await tester.runAsync(() async {
        final file = await createSystemAvatarFile(2);
        try {
          return await file.readAsBytes();
        } finally {
          await discardSystemAvatarFile(file);
        }
      });
      NetworkImageStore.instance = NetworkImageStore(
        directory: () async => directory,
        download: (_) async {
          downloads++;
          return png!;
        },
      );
      const object = 'https://cdn.example.com/users/9/AVATAR/9-face.png';
      // The first page loads the avatar once.
      await tester.runAsync(() async {
        final loaded = Completer<void>();
        final stream = profileAvatarImage('$object?e=1&token=a')
            .resolve(ImageConfiguration.empty);
        final listener = ImageStreamListener(
          (_, _) => loaded.complete(),
          onError: (error, _) => loaded.completeError(error),
        );
        stream.addListener(listener);
        await loaded.future;
        stream.removeListener(listener);
      });
      expect(downloads, 1);
      // Another page, size and signature paints from memory in its first frame.
      await tester.pumpWidget(
        const MaterialApp(
          home: Column(
            children: [
              ProfileAvatar(seed: '9', url: '$object?e=2&token=b', size: 72),
              ProfileAvatar(seed: '9', url: '$object?e=3&token=c', size: 40),
            ],
          ),
        ),
      );
      expect(downloads, 1);
      final painted = tester.widgetList<RawImage>(find.byType(RawImage));
      expect(painted, hasLength(2));
      expect(painted.every((image) => image.image != null), isTrue);
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
    });
  });
}
