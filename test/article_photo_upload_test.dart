import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/article_media_picker.dart';
import 'package:bojian_mobile/article_photo_shrink.dart';
import 'package:bojian_mobile/article_photo.dart';
import 'package:bojian_mobile/when_near_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Noise, so the file stays large however it is encoded.
img.Image noise(int width, int height, {int channels = 3}) {
  final random = Random(7);
  final image = img.Image(width: width, height: height, numChannels: channels);
  for (final pixel in image) {
    pixel
      ..r = random.nextInt(256)
      ..g = random.nextInt(256)
      ..b = random.nextInt(256);
    if (channels == 4) pixel.a = 128;
  }
  return image;
}

Future<(int, int)> sizeOf(List<int> bytes) async {
  final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
  final frame = (await codec.getNextFrame()).image;
  return (frame.width, frame.height);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('A large photo is cut to size and stays the right way up', () async {
    final photo = noise(3000, 2000);
    // Held upright: stored on its side, with the turn noted in the file.
    photo.exif.imageIfd.orientation = 6;
    final original = img.encodeJpg(photo);
    expect(await sizeOf(original), (2000, 3000));
    final smaller = (await shrinkPhoto(original))!;
    expect(smaller.length, lessThan(original.length / 2));
    final (width, height) = await sizeOf(smaller);
    expect(height / width, closeTo(1.5, .01));
    expect(width, inInclusiveRange(photoShortSide - 2, 2162));
  });

  test('Small, see-through and unreadable files go as they are', () async {
    expect(await shrinkPhoto(img.encodeJpg(noise(200, 200))), isNull);
    final seeThrough = img.encodePng(noise(800, 800, channels: 4));
    expect(seeThrough.length, greaterThan(photoKeptBytes));
    expect(await shrinkPhoto(seeThrough), isNull);
    expect(await shrinkPhoto(Uint8List(photoKeptBytes + 1)), isNull);
  });

  test('A shrunk photo is uploaded as the JPEG it became', () async {
    final bytes = img.encodePng(noise(1600, 1600));
    final media = PickedArticleMedia(
      XFile.fromData(bytes, path: 'screen.png'),
      'image/png',
    );
    final (:file, :mime) = await media.forUpload();
    expect(mime, 'image/jpeg');
    final sent = await file.readAsBytes();
    expect(await file.length(), sent.length);
    expect(sent.length, lessThan(bytes.length));
    expect(await sizeOf(sent), (photoShortSide, photoShortSide));
  });

  test('Files go up a few at a time and keep their order', () async {
    final files = [
      for (var i = 0; i < 8; i++)
        PickedArticleMedia(XFile('$i.jpg'), 'image/jpeg'),
    ];
    final waiting = <String, Completer<void>>{};
    final progress = <int>[];
    final result = uploadArticleMediaFiles(files, (file) async {
      await (waiting[file.file.path] = Completer<void>()).future;
      return {'name': file.file.path};
    }, onProgress: (done, _) => progress.add(done));
    await pumpEventQueue();
    expect(waiting.length, articleUploadsAtOnce);
    // Later ones finishing first changes nothing about their order.
    while (waiting.values.any((c) => !c.isCompleted)) {
      waiting.values.lastWhere((c) => !c.isCompleted).complete();
      await pumpEventQueue();
    }
    final (:blocks, :error) = await result;
    expect(error, isNull);
    expect(blocks.map((b) => b['name']), [for (final f in files) f.file.path]);
    expect(progress, [0, 1, 2, 3, 4, 5, 6, 7, 8]);
  });

  test('After a failure no more files are started', () async {
    final started = <String>[];
    final (:blocks, :error) = await uploadArticleMediaFiles(
      [
        for (var i = 0; i < 9; i++)
          PickedArticleMedia(XFile('$i.jpg'), 'image/jpeg'),
      ],
      (file) async {
        started.add(file.file.path);
        if (file.file.path == '1.jpg') throw const ApiFailure('断网');
        return {'name': file.file.path};
      },
    );
    expect('$error', '断网');
    expect(started.length, lessThan(9));
    expect(blocks.length, started.length - 1);
  });

  testWidgets('Pictures far down a page wait until the reader gets near', (
    tester,
  ) async {
    final asked = <int>{};
    final scroll = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          controller: scroll,
          child: Column(
            children: [
              for (var i = 0; i < 20; i++)
                WhenNearViewport(
                  onNear: () => asked.add(i),
                  child: const SizedBox(height: 300, width: 300),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(asked, containsAll([0, 1, 2]));
    expect(asked, isNot(contains(8)));
    scroll.jumpTo(3000);
    await tester.pump();
    await tester.pump();
    expect(asked, contains(11));
    expect(asked, isNot(contains(19)));
  });
}
