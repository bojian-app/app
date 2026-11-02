import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/app_theme.dart';
import 'package:bojian_mobile/resume_document.dart';
import 'package:bojian_mobile/resume_export.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:bojian_mobile/resume_template_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  late AppStore store;
  setUp(() async {
    store = AppStore(api: FakeGateway(), storage: MemoryStorage());
    await store.initialize();
    store.session = {'access_token': 'test'};
    store.resumes.add(ResumeDraft(id: 1, title: '工程师简历', name: '张三'));
  });
  tearDown(() => store.dispose());

  Future<void> mount(WidgetTester tester, {double scale = 1}) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: ResumePreview(store: store, resumeId: 1),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Updated content exports every page through the download menu', (
    tester,
  ) async {
    await mount(tester);
    final initialState = tester.state<ResumeDocumentViewState>(
      find.byType(ResumeDocumentView),
    );
    expect(initialState.document!.fontFamily, isNull);
    expect(
      initialState.document!.painters.first.text!.style!.fontFamily,
      isNull,
    );
    store.resumes[0] = ResumeDraft(
      id: 1,
      revision: 1,
      title: '修改后的简历',
      name: '李四',
      source: {
        'work_experiences': [
          {
            'company': '新公司',
            'description': List.generate(
              90,
              (i) => '项目 $i：研发和交付工作内容。',
            ).join('\n'),
          },
        ],
      },
    );
    store.changed();
    await tester.pumpAndSettle();
    final document = ResumeDocument(store.resumes.first);
    addTearDown(document.dispose);
    expect(document.pages.length, greaterThan(1));
    await tester.tap(find.byKey(const ValueKey('resume-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('resume-action-download')));
    await tester.pumpAndSettle();
    final sheet = tester.widget<ResumeExportSheet>(
      find.byType(ResumeExportSheet),
    );
    expect(sheet.resume.name, '李四');
    final layout = await tester.runAsync(
      () => sheet.captureLayout!(isCancelled: () => false, onProgress: (_) {}),
    );
    expect(layout!.pages.length, document.pages.length);
    expect(initialState.widget.resume.name, '李四');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Template panel keeps paper visible and controls fit large system text',
    (tester) async {
      await mount(tester, scale: 1.6);
      await tester.runAsync(() async {
        await tester.tap(find.text('模板'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pumpAndSettle();
      final panel = find.byType(ResumeTemplatePicker);
      expect(tester.getTopLeft(panel).dy, greaterThan(200));
      expect(find.byType(ResumeDocumentView), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      expect(find.byType(ResumeEditor), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
