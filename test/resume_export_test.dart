import 'dart:io';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_export.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

import 'support/fake_gateway.dart';
import 'support/resume_editor_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeGateway api;
  late AppStore store;
  setUp(() async {
    api = FakeGateway();
    store = AppStore(api: api, storage: MemoryStorage());
    await store.initialize();
    store.session = {'access_token': 'test'};
    api.documents['PostResumeExports'] = {'id': 12};
    api.documents['GetResumeExportsId'] = {
      'status': 'SUCCEEDED',
      'download_url': 'https://origin.example.com/file?token=private',
    };
  });
  tearDown(() => store.dispose());
  for (final format in ['PDF', 'DOCX']) {
    test(
      'Export $format creates a real job and downloads correct file type',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'bojian-resume-export-',
        );
        final downloader = ResumeExporter(
          store,
          delay: (_) async {},
          download: (url, name, mime, cancelled) async {
            expect(url.scheme, 'https');
            expect(name, '简历.$format'.toLowerCase());
            expect(mime, exportMimeTypes[format]);
            final f = File('${directory.path}/$name');
            await f.writeAsString('test');
            return XFile(f.path, mimeType: mime);
          },
        );
        final file = await downloader.export(
          ResumeDraft(id: 1, title: '简历'),
          format,
          onProgress: (_) {},
          isCancelled: () => false,
        );
        expect(api.calls, ['PostResumeExports', 'GetResumeExportsId']);
        await clearExportFile(file);
        expect(await directory.exists(), isFalse);
      },
    );
  }
  test('Cancelled export stops polling and never downloads', () async {
    api.documents['GetResumeExportsId'] = {'status': 'RUNNING'};
    var cancel = false;
    final exporter = ResumeExporter(
      store,
      delay: (_) async {
        cancel = true;
      },
      download: (_, _, _, _) async {
        fail('download after cancellation');
      },
    );
    await expectLater(
      exporter.export(
        ResumeDraft(id: 1, title: '简历'),
        'PDF',
        onProgress: (_) {},
        isCancelled: () => cancel,
      ),
      throwsA(isA<ExportCancelled>()),
    );
    expect(api.calls, ['PostResumeExports', 'GetResumeExportsId']);
  });
  test('Failed job never exposes server error or signed URL', () async {
    api.documents['GetResumeExportsId'] = {
      'status': 'FAILED',
      'error_message': 'token=secret',
    };
    await expectLater(
      ResumeExporter(store, delay: (_) async {}).export(
        ResumeDraft(id: 1, title: '简历'),
        'PDF',
        onProgress: (_) {},
        isCancelled: () => false,
      ),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.message,
          'safe error',
          isNot(contains('secret')),
        ),
      ),
    );
  });
  test('Invalid download URL is rejected before downloading', () async {
    api.documents['GetResumeExportsId'] = {
      'status': 'SUCCEEDED',
      'download_url': 'http://insecure.example.com/file',
    };
    await expectLater(
      ResumeExporter(store, delay: (_) async {}).export(
        ResumeDraft(id: 1, title: '简历'),
        'PDF',
        onProgress: (_) {},
        isCancelled: () => false,
      ),
      throwsA(isA<ApiFailure>()),
    );
  });
  testWidgets('Format chooser exposes Word and PDF', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResumeExportSheet(
            store: store,
            resume: ResumeDraft(id: 1, title: '简历'),
          ),
        ),
      ),
    );
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('Word'), findsOneWidget);
  });
  testWidgets(
    'Editor switches independent sections without losing saved input',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ResumeEditor(
            store: store,
            draft: ResumeDraft(id: 0, title: '简历'),
          ),
        ),
      );
      await openResumeSection(tester, 0);
      await tester.enterText(find.byKey(const ValueKey('resume-name')), '李明');
      await saveResumeSection(tester);
      await openResumeSection(tester, 6);
      expect(find.text('添加技能'), findsOneWidget);
      expect(find.byKey(const ValueKey('resume-name')), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('李明'), findsOneWidget);
      await openResumeSection(tester, 0);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('resume-name')))
            .controller!
            .text,
        '李明',
      );
    },
  );
}
