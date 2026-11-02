import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:bojian_mobile/resume_native_market.dart';
import 'package:bojian_mobile/resume_native_export.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = Platform.environment['BOJIAN_NATIVE_TEST_DIR'];
  test(
    'Native package paginates and exports real text without duplication or loss',
    () async {
      final root = Directory(fixture!);
      final out =
          Platform.environment['BOJIAN_NATIVE_TEST_OUTPUT'] ??
          Directory.systemTemp.createTempSync('native-package-test-').path;
      final layout = jsonDecode(
        await File('${root.path}/layout.json').readAsString(),
      ) as Map;
      final assets = <String, String>{};
      for (final entry in (layout['assets'] as Map).entries) {
        assets[entry.key as String] = base64Encode(
          await File('${root.path}/${entry.value['path']}').readAsBytes(),
        );
      }
      final samples = Platform.environment['BOJIAN_NATIVE_TEST_SAMPLES']!;
      for (final sample in ['short', 'long']) {
        final fields = Map<String, dynamic>.from(
          jsonDecode(await File('$samples/$sample.json').readAsString()) as Map,
        );
        final photo = (await rootBundle.load(
          'assets/templates/preview_portrait.png',
        )).buffer.asUint8List();
        // Preview must use the device font even after preparing an export.
        final preview = await NativeMarketDocument.load(
          {'layout': layout, 'assets': assets},
          fields,
          photo,
        );
        try {
          expect(preview.renderer.useSystemFont, isTrue);
          final key = (layout['textStyles'] as Map).keys.first as String;
          expect(preview.renderer.textStyle(key).fontFamily, isNull);
          await preview.export(isCancelled: () => false, onProgress: (_) {});
          expect(preview.renderer.textStyle(key).fontFamily, isNull);
        } finally {
          preview.dispose();
        }
        final doc = await NativeMarketDocument.load(
          {'layout': layout, 'assets': assets},
          fields,
          photo,
          useSystemFont: false,
        );
        try {
          expect(doc.document.pages.length, 2);
          for (final run in doc.document.report['textRuns'] as List) {
            final exported = (run['exportLines'] as List)
                .expand((l) => l['spans'] as List)
                .map((s) => s['text'])
                .join();
            expect(
              exported,
              (run['text'] as String).replaceAll('\n', ''),
              reason: '$sample: ${run['text']}',
            );
          }
          final export = await doc.export(
            isCancelled: () => false,
            onProgress: (_) {},
          );
          expect(export.pages.length, 2);
          for (final format in ['PDF', 'DOCX']) {
            final file = await exportNativeResume(
              capture: ({required isCancelled, required onProgress}) async =>
                  export,
              title: 'isolate-export',
              format: format,
              isCancelled: () => false,
              onProgress: (_) {},
            );
            expect(await File(file.path).length(), greaterThan(0));
            await File(file.path).parent.delete(recursive: true);
          }
          expect(
            export.pages.every(
              (p) => p.lines.isNotEmpty && p.background != null && !p.wordFlow,
            ),
            isTrue,
          );
          final regular = (await rootBundle.load(resumeFontRegularAsset)).buffer
              .asUint8List();
          final medium = (await rootBundle.load(resumeFontMediumAsset)).buffer
              .asUint8List();
          final bold = (await rootBundle.load(resumeFontBoldAsset)).buffer
              .asUint8List();
          for (final format in ['PDF', 'DOCX']) {
            final bytes = await encodeNativeResume(
              export,
              format,
              regular,
              bold,
              medium: medium,
            );
            await File('$out/$sample.${format.toLowerCase()}')
                .writeAsBytes(bytes);
            if (format == 'DOCX') {
              final zip = ZipDecoder().decodeBytes(bytes);
              final xml = utf8.decode(
                zip.findFile('word/document.xml')!.content as List<int>,
              );
              expect(xml, contains(fields['name']));
              expect(xml, contains('工作经历'));
              expect(xml, isNot(contains('<w:txbxContent>')));
              expect(xml, isNot(contains('<wps:txbx>')));
              expect(xml, contains('<w:sdtContent>'));
              expect(xml, contains('<w:tbl>'));
              expect(xml, contains('<w:headerReference'));
              expect(zip.findFile('word/header.xml'), isNotNull);
              expect(xml, isNot(contains('w:fitText')));
              // Every rich source field is one editing region, including all
              // paragraphs; automatic visual wrapping must never insert breaks.
              for (final field in RegExp(
                r'<w:sdt>.*?</w:sdt>',
                dotAll: true,
              ).allMatches(xml)) {
                expect(field.group(0), isNot(contains('<w:br/>')));
              }
              // Adjacent grids must remain independent in Word/LibreOffice.
              expect(xml, isNot(contains('</w:tbl><w:tbl>')));
            }
          }
          final images = await doc.capture(
            isCancelled: () => false,
            onProgress: (_) {},
          );
          await File('$out/$sample-native.png').writeAsBytes(images.first);
        } finally {
          doc.dispose();
        }
      }
    },
    skip: fixture == null
        ? 'Set BOJIAN_NATIVE_TEST_DIR and BOJIAN_NATIVE_TEST_SAMPLES for package acceptance.'
        : false,
  );
}
