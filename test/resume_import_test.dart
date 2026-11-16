import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/resume_importer.dart';
import 'package:bojian_mobile/resume_files.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:bojian_mobile/design.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fake_gateway.dart';
import 'support/resume_editor_helpers.dart';

class ImportGateway extends FakeGateway {
  ImportGateway() {
    documents['PostResumeImportsUpload'] = {'id': 3, 'status': 'QUEUED'};
    documents['GetResumeImportsId'] = {
      'status': 'WAITING_CONFIRMATION',
      'parsed_content': {
        'personal_info': {'full_name': '文件中的姓名', 'phone': '13812345678'},
        'job_expectation': {'position': '软件工程师'},
        'work_experiences': [
          {'company': '第一段经历', 'description': '贡献一'},
          {'company': '第二段经历', 'description': '贡献二'},
        ],
      },
    };
    documents['PostResumeImportsIdConfirm'] = {'resume_id': 12};
    documents['GetResumesId'] = {'id': 12, 'revision': 2};
  }
  final records = <Map<String, dynamic>>[];
  Future<void> Function()? beforeUpload;
  @override
  Future<ApiDocument> upload(
    String method, {
    Map<String, String> path = const {},
    required Map<String, String> fields,
    required ApiUploadFile file,
    Map<String, String> headers = const {},
  }) async {
    await beforeUpload?.call();
    return super.upload(
      method,
      path: path,
      fields: fields,
      file: file,
      headers: headers,
    );
  }

  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) {
    records.add({
      'method': method,
      'path': path,
      'body': body,
      'headers': headers,
    });
    return super.call(
      method,
      path: path,
      query: query,
      body: body,
      headers: headers,
    );
  }
}

XFile selectedFile({String name = '我的简历.PDF', int size = 20}) =>
    XFile.fromData(Uint8List(size), path: '/test/$name');

void main() {
  test(
    'Zero completeness does not replace extracted fields with raw import text',
    () async {
      final api = ImportGateway();
      api.documents['GetResumeImportsId'] = {
        'status': 'WAITING_CONFIRMATION',
        'parsed_content': {
          'personal_info': {'full_name': '已解析姓名'},
          'job_expectation': {'position': '人事专员', 'preference': '已解析自我评价'},
          'raw_text': '原始文件全文',
        },
      };
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      final draft = await ResumeImporter(store: store, delay: (_) async {})
          .importFile(
            selectedFile(),
            onProgress: (_) {},
            isCancelled: () => false,
          );
      expect(draft.progress, 0);
      expect(draft.position, '人事专员');
      expect(draft.summary, '已解析自我评价');
    },
  );

  testWidgets('Shared file starts automatically and opens review once', (
    tester,
  ) async {
    final api = ImportGateway();
    final store = await testStore(authenticated: true, api: api);
    var returnedToLibrary = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: ImportResume(
          store: store,
          initialFile: selectedFile(),
          onSaved: () => returnedToLibrary = true,
          importer: ResumeImporter(store: store, delay: (_) async {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ResumeEditor), findsOneWidget);
    expect(
      api.calls.where((c) => c == 'PostResumeImportsUpload'),
      hasLength(1),
    );
    expect(api.calls, isNot(contains('PostResumeImportsIdConfirm')));
    expect(returnedToLibrary, isFalse);
    await openResumeSection(tester, 0);
    await saveResumeSection(tester);
    expect(api.calls, contains('PostResumeImportsIdConfirm'));
    expect(returnedToLibrary, isTrue);
  });

  testWidgets(
    'Incoming file shows progress, ignores duplicate, and supports cancellation and retry',
    (tester) async {
      final api = ImportGateway();
      final store = await testStore(authenticated: true, api: api);
      final gate = Completer<void>();
      final directory = await tester.runAsync(
        () => Directory.systemTemp.createTemp('bojian-share-'),
      );
      addTearDown(() => directory!.delete(recursive: true));
      final shared = await tester.runAsync(
        () => File('${directory!.path}/简历.pdf').writeAsString('%PDF-test'),
      );
      var uploads = 0;
      api.beforeUpload = () async {
        uploads++;
        await gate.future;
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ImportResume(
            store: store,
            importer: ResumeImporter(store: store, delay: (_) async {}),
          ),
        ),
      );
      final files = ResumeFiles.instance;
      files.receive({'path': shared!.path, 'name': '简历.pdf'});
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(uploads, 1);
      expect(
        find.byKey(const ValueKey('resume-import-progress')),
        findsOneWidget,
      );
      expect(find.text('AI 识别与整理'), findsOneWidget);
      expect(find.text('正在上传文件…'), findsNWidgets(2));
      files.receive({'path': shared.path, 'name': '简历.pdf'});
      await tester.pump();
      expect(uploads, 1);
      await tester.scrollUntilVisible(find.text('取消导入'), 200);
      await tester.tap(find.text('取消导入'));
      gate.complete();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('resume-import-progress')),
        findsNothing,
      );
      // The upload already created the job, so cancelling must stop it.
      expect(api.calls, contains('PostResumeImportsIdCancel'));
      expect(api.calls, isNot(contains('GetResumeImportsId')));
      await tester.ensureVisible(find.byKey(const ValueKey('resume-upload')));
      await tester.tap(find.byKey(const ValueKey('resume-upload')));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pumpAndSettle();
      expect(find.byType(ResumeEditor), findsOneWidget);
      expect(uploads, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('Shared files preserve their display name and cached file path', () {
    final files = ResumeFiles.instance;
    files.receive({'path': '/cache/random.pdf', 'name': '我的微信简历.pdf'});
    expect(files.incoming.value!.name, '我的微信简历.pdf');
    expect(files.incoming.value!.path, '/cache/random.pdf');
    files.incoming.value = null;
  });

  test(
    'Upload, parse and review precede confirmation; structured entries survive',
    () async {
      final api = ImportGateway();
      final store = await testStore(authenticated: true, api: api);
      final importer = ResumeImporter(store: store, delay: (_) async {});
      final phases = <ResumeImportPhase>[];
      final draft = await importer.importFile(
        selectedFile(),
        onProgress: (_) {},
        isCancelled: () => false,
        onPhase: phases.add,
      );
      expect(phases, ResumeImportPhase.values);
      expect(draft.name, '文件中的姓名');
      expect(draft.importID, 3);
      expect(draft.id, 0);
      expect(
        api.calls,
        containsAllInOrder(['PostResumeImportsUpload', 'GetResumeImportsId']),
      );
      expect(api.calls, isNot(contains('PostFilesUploads')));
      expect(api.calls, isNot(contains('PostResumeImportsIdConfirm')));
      expect(api.calls, isNot(contains('PostResumes')));
      final upload = api.uploads.single;
      expect(upload.fields, {'name': '我的简历'});
      expect(upload.file.path, '/test/我的简历.PDF');
      expect(upload.file.filename, '我的简历.PDF');
      expect(upload.file.contentType, 'application/pdf');
      draft.title = '校对后的简历';
      await store.updateResume(draft.copy());
      final confirm = api.records.firstWhere(
        (r) => r['method'] == 'PostResumeImportsIdConfirm',
      );
      expect(confirm['path'], {'id': '3'});
      expect(confirm['body']['content']['work_experiences'], hasLength(2));
      final patch = api.records.firstWhere(
        (r) => r['method'] == 'PatchResumesId',
      );
      expect(patch['path'], {'id': '12'});
      expect(patch['headers']['if-match'], '"revision-2"');
      expect(patch['body']['title'], '校对后的简历');
      expect(api.calls, isNot(contains('PostResumes')));
    },
  );

  test('Imported portrait survives review and draft copies', () async {
    final api = ImportGateway();
    api.documents['GetResumeImportsId']!['photo_file_id'] = 51;
    api.documents['GetResumeImportsId']!['photo_url'] =
        'https://cdn.example.test/imported-portrait.png';
    final store = await testStore(authenticated: true, api: api);
    final draft = await ResumeImporter(store: store, delay: (_) async {})
        .importFile(
          selectedFile(name: '简历.docx'),
          onProgress: (_) {},
          isCancelled: () => false,
        );
    expect(draft.photoFileID, 51);
    expect(draft.photoURL, 'https://cdn.example.test/imported-portrait.png');
    expect(draft.copy().photoFileID, 51);
    expect(draft.copy().photoURL, draft.photoURL);
  });

  test('Invalid and oversized files fail before uploading', () async {
    final api = ImportGateway();
    final store = await testStore(authenticated: true, api: api);
    final importer = ResumeImporter(store: store);
    for (final file in [
      selectedFile(name: '简历.txt'),
      selectedFile(name: 'pdf'),
      selectedFile(size: 0),
      selectedFile(size: maximumResumeFileBytes + 1),
    ]) {
      await expectLater(
        importer.importFile(file, onProgress: (_) {}, isCancelled: () => false),
        throwsA(isA<ApiFailure>()),
      );
    }
    expect(api.calls, isNot(contains('PostResumeImportsUpload')));
  });

  test(
    'Cancelling during upload stops the created job; failed uploads stop early',
    () async {
      final api = ImportGateway();
      final store = await testStore(authenticated: true, api: api);
      var cancel = false;
      api.beforeUpload = () async => cancel = true;
      final importer = ResumeImporter(store: store);
      await expectLater(
        importer.importFile(
          selectedFile(),
          onProgress: (_) {},
          isCancelled: () => cancel,
        ),
        throwsA(isA<ImportCancelled>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(api.calls, contains('PostResumeImportsIdCancel'));
      expect(api.calls, isNot(contains('GetResumeImportsId')));
      api.calls.clear();
      api.beforeUpload = null;
      api.failing = 'PostResumeImportsUpload';
      await expectLater(
        importer.importFile(
          selectedFile(),
          onProgress: (_) {},
          isCancelled: () => false,
        ),
        throwsA(isA<ApiFailure>()),
      );
      expect(api.calls, isNot(contains('GetResumeImportsId')));
      expect(api.calls, isNot(contains('PostResumeImportsIdCancel')));
    },
  );

  test('Multipart upload contains file and limited token, without account authorization', () async {
    final directory = await Directory.systemTemp.createTemp(
      'bojian-upload-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = await File('${directory.path}/sample.pdf')
        .writeAsString('%PDF-test-content');
    final client = MockClient((request) async {
      expect(request.url.scheme, 'https');
      expect(request.headers['authorization'], isNull);
      expect(
        request.headers['content-type'],
        startsWith('multipart/form-data;'),
      );
      expect(request.body, contains('%PDF-test-content'));
      expect(request.body, contains('limited-upload-token'));
      expect(request.body, contains('application/pdf'));
      return http.Response('{}', 200);
    });
    addTearDown(client.close);
    await uploadResumeDocument(
      {
        'upload_url': 'https://uploads.example.test',
        'method': 'POST',
        'fields': {'token': 'limited-upload-token', 'key': 'resume/10'},
      },
      XFile(file.path),
      'application/pdf',
      client: client,
    );
    await expectLater(
      uploadResumeDocument(
        {
          'upload_url': 'http://uploads.example.test',
          'method': 'POST',
          'fields': {'token': 'token', 'key': 'key'},
        },
        XFile(file.path),
        'application/pdf',
        client: client,
      ),
      throwsA(isA<ApiFailure>()),
    );
  });

  test(
    'Storage account freeze is explained for object storage uploads',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'bojian-419-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = await File('${directory.path}/photo.png')
          .writeAsString('png');
      final client = MockClient(
        (_) async => http.Response('{"error":"user is frozen"}', 419),
      );
      addTearDown(client.close);
      await expectLater(
        uploadResumeDocument(
          {
            'upload_url': 'https://upload-z2.qiniup.com',
            'method': 'POST',
            'fields': {'token': 'limited-upload-token', 'key': 'photo/10'},
          },
          XFile(file.path),
          'image/png',
          client: client,
        ),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.message,
            'message',
            '文件存储服务暂不可用，请联系管理员恢复服务（419）',
          ),
        ),
      );
    },
  );

  test('Import task errors never expose signed download URLs', () async {
    final api = ImportGateway();
    final store = await testStore(authenticated: true, api: api);
    final importer = ResumeImporter(store: store, delay: (_) async {});
    for (final code in ['OBJECT_STORAGE_READ_FAILED', 'UNKNOWN_ERROR']) {
      api.documents['GetResumeImportsId'] = {
        'status': 'FAILED',
        'error_code': code,
        'error_message': 'Get https://cdn.example.test/private.pdf?token=secret: connection refused',
      };
      await expectLater(
        importer.importFile(
          selectedFile(),
          onProgress: (_) {},
          isCancelled: () => false,
        ),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.message,
            'message',
            code == 'OBJECT_STORAGE_READ_FAILED'
                ? '服务器暂时无法读取已上传的文件，请稍后重试'
                : '简历解析失败，请稍后重试',
          ),
        ),
      );
    }
  });

  test('Import task errors explain user-actionable failure causes', () async {
    final api = ImportGateway();
    final store = await testStore(authenticated: true, api: api);
    final importer = ResumeImporter(store: store, delay: (_) async {});
    for (final entry in {
      'IMPORT_DOCUMENT_CONVERT_FAILED':
          'Word 文件无法打开，请确认文件完整且未加密，或另存为 PDF 后重新导入',
      'IMPORT_NO_TEXT_DETECTED': '没有识别到简历文字，请确认文件不是空白页或过于模糊的图片',
      'IMPORT_CONTENT_TOO_LONG': '简历内容过长，请精简后重新导入，或拆分为多份导入',
      'IMPORT_AI_UNAVAILABLE': 'AI 解析服务繁忙，请稍后点击重试',
    }.entries) {
      api.documents['GetResumeImportsId'] = {
        'status': 'FAILED',
        'error_code': entry.key,
        'error_message': 'Post https://ai.example.test/v1: connection reset',
      };
      await expectLater(
        importer.importFile(
          selectedFile(),
          onProgress: (_) {},
          isCancelled: () => false,
        ),
        throwsA(
          isA<ApiFailure>().having((e) => e.message, 'message', entry.value),
        ),
      );
    }
  });

  testWidgets(
    'Import offers two file sources, keeps cancellation harmless, and opens review',
    (tester) async {
      final api = ImportGateway();
      final store = await testStore(authenticated: true, api: api);
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ImportResume(
            store: store,
            pickFile: () async => ++attempts == 1 ? null : selectedFile(),
            importer: ResumeImporter(store: store, delay: (_) async {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('从微信文件上传'), findsOneWidget);
      await tester.tap(find.text('从本机文件上传'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('resume-upload')), findsNothing);
      expect(api.calls, isNot(contains('PostResumeImportsUpload')));
      await tester.tap(find.text('从本机文件上传'));
      await tester.pumpAndSettle();
      expect(find.text('我的简历.PDF'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('resume-upload')));
      await tester.pumpAndSettle();
      expect(find.byType(ResumeEditor), findsOneWidget);
      expect(api.calls, isNot(contains('PostResumeImportsIdConfirm')));
    },
  );
}
