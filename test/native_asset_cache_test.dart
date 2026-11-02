import 'dart:convert';
import 'dart:ui' as ui;

import 'package:bojian_mobile/resume_native_market.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('immutable template images share backing data and have independent lifetimes', () async {
    final data = await rootBundle.load('assets/templates/preview_portrait.png');
    final payload = {
      'assets': {
        'paper': base64Encode(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        ),
      },
      'layout': {
        'format': 'bojian-native-layout',
        'schemaVersion': '1.0',
        'page': {
          'size': {'width': 794, 'height': 1123},
          'contentPadding': {'top': 20, 'bottom': 20, 'left': 20, 'right': 20},
          'background': {'color': '#FFFFFF', 'asset': 'paper', 'fit': 'fill'},
        },
        'assets': {
          'paper': {'type': 'png'},
        },
        'textStyles': <String, dynamic>{},
        'sections': [
          for (final id in [
            'personal_info',
            'job_expectation',
            'self_evaluation',
            'work_experiences',
            'projects',
            'educations',
            'skills',
            'certifications',
          ])
            {'id': id, 'type': 'column', 'children': <dynamic>[]},
        ],
      },
    };
    final first = await NativeMarketDocument.load(payload, {}, null);
    final second = await NativeMarketDocument.load(payload, {}, null);
    try {
      expect(
        identical(
          first.renderer.assetBytes['paper'],
          second.renderer.assetBytes['paper'],
        ),
        isTrue,
      );
      expect(
        first.renderer.images['paper']!.isCloneOf(
          second.renderer.images['paper']!,
        ),
        isTrue,
      );
      first.dispose();
      PaintingBinding.instance.imageCache.clear();
      // Evicting the shared cache or disposing a thumbnail cannot invalidate an
      // active preview/export's owned image handle.
      expect(
        await second.renderer.images['paper']!.toByteData(
          format: ui.ImageByteFormat.png,
        ),
        isNotNull,
      );
    } finally {
      first.dispose();
      second.dispose();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    }
  });
}
