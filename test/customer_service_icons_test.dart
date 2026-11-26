import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_graphics/vector_graphics.dart' show AssetBytesLoader;

Future<Uint8List> _pixels(PictureInfo icon, int size) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)..scale(size / icon.size.width);
  canvas.drawPicture(icon.picture);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled service icons render like their original SVGs', () async {
    final icons = Directory('assets/customer_service/icons')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.svg'));
    expect(icons, isNotEmpty);
    for (final file in icons) {
      final source = await vg.loadPicture(
        SvgStringLoader(await file.readAsString()),
        null,
      );
      final bundled = await vg.loadPicture(
        AssetBytesLoader(file.path.replaceAll(r'\', '/')),
        null,
      );
      try {
        expect(bundled.size, source.size);
        for (final size in [56, 84]) {
          expect(
            await _pixels(bundled, size),
            await _pixels(source, size),
            reason: '${file.path} at ${size}px',
          );
        }
      } finally {
        source.picture.dispose();
        bundled.picture.dispose();
      }
    }
  });
}
