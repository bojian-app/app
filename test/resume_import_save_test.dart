import 'dart:async';

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/resume_importer.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:bojian_mobile/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'resume_import_test.dart' show ImportGateway, selectedFile;
import 'support/fake_gateway.dart';

class PendingConfirmGateway extends ImportGateway {
  late final gate = Completer<void>();
  int confirms = 0;
  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    if (method == 'PostResumeImportsIdConfirm') {
      confirms++;
      await gate.future;
    }
    return super.call(
      method,
      path: path,
      query: query,
      body: body,
      headers: headers,
    );
  }
}

void main() {
  testWidgets(
    'Parsed WeChat file saves from overview without opening a section',
    (tester) async {
      final api = ImportGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      var saved = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ImportResume(
            store: store,
            initialFile: selectedFile(),
            onSaved: () => saved++,
            importer: ResumeImporter(
              store: store,
              upload: (_, _, _) async {},
              delay: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('保存简历'), findsOneWidget);
      expect(api.calls, isNot(contains('PostResumeImportsIdConfirm')));
      await tester.tap(find.byKey(const ValueKey('resume-import-save')));
      await tester.pumpAndSettle();
      expect(saved, 1);
      expect(find.byKey(const ValueKey('resume-import-save')), findsNothing);
      final confirm = api.records.singleWhere(
        (r) => r['method'] == 'PostResumeImportsIdConfirm',
      );
      final content = confirm['body']['content'] as Map;
      expect(content['personal_info']['full_name'], '文件中的姓名');
      expect(content['work_experiences'], hasLength(2));
      expect(api.calls, isNot(contains('PostResumes')));
    },
  );

  testWidgets(
    'Unsaved overview back warns, continue retains data, leave preserves server task',
    (tester) async {
      final api = ImportGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      final draft = await ResumeImporter(store: store).resumeImport(3);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ResumeEditor(store: store, draft: draft),
                  ),
                ),
                child: const Text('打开校对'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开校对'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('导入的简历尚未保存'), findsOneWidget);
      await tester.tap(find.text('继续校对'));
      await tester.pumpAndSettle();
      expect(find.text('文件中的姓名'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('暂不保存，返回'));
      await tester.pumpAndSettle();
      expect(find.text('打开校对'), findsOneWidget);
      expect(api.calls, isNot(contains('PostResumeImportsIdConfirm')));
      expect(api.calls, isNot(contains('PostResumeImportsIdCancel')));
    },
  );

  testWidgets(
    'Recovery reuses parsed record and failed save retains review for retry',
    (tester) async {
      final api = ImportGateway()
        ..documents['GetResumeImportsPending'] = {
          'items': [
            {'id': 3, 'name': '微信中上次的简历'},
          ],
        };
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ImportResume(
            store: store,
            initialSource: ResumeImportSource.wechat,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('待保存的导入简历'), findsOneWidget);
      expect(find.text('前往微信'), findsNothing);
      await tester.tap(find.text('微信中上次的简历'));
      await tester.pumpAndSettle();
      expect(find.text('文件中的姓名'), findsOneWidget);
      expect(api.calls, isNot(contains('PostFilesUploads')));
      expect(api.calls, isNot(contains('PostResumeImports')));
      api.failing = 'PostResumeImportsIdConfirm';
      await tester.tap(find.byKey(const ValueKey('resume-import-save')));
      await tester.pumpAndSettle();
      expect(find.text('文件中的姓名'), findsOneWidget);
      expect(find.text('保存简历'), findsOneWidget);
      api.failing = null;
      await tester.tap(find.byKey(const ValueKey('resume-import-save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('resume-import-save')), findsNothing);
    },
  );

  testWidgets('Saving import blocks duplicate taps and system back', (
    tester,
  ) async {
    final api = PendingConfirmGateway();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    final draft = await ResumeImporter(store: store).resumeImport(3);
    var saved = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: ResumeEditor(store: store, draft: draft, onSaved: () => saved++),
      ),
    );
    final button = find.byKey(const ValueKey('resume-import-save'));
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(api.confirms, 1);
    expect(find.text('保存中…'), findsOneWidget);
    expect(find.text('导入的简历尚未保存'), findsNothing);
    api.gate.complete();
    await tester.pumpAndSettle();
    expect(saved, 1);
  });

  testWidgets('Account change before first save prevents import confirmation', (
    tester,
  ) async {
    final api = ImportGateway();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    final draft = await ResumeImporter(store: store).resumeImport(3);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: ResumeEditor(store: store, draft: draft),
      ),
    );
    await store.endSession(remote: false);
    await tester.tap(find.byKey(const ValueKey('resume-import-save')));
    await tester.pumpAndSettle();
    expect(api.calls, isNot(contains('PostResumeImportsIdConfirm')));
  });
}
