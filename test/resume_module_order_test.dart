import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/resume_document.dart';
import 'package:bojian_mobile/resume_module_order.dart';
import 'package:bojian_mobile/resume_editor_sections.dart';
import 'package:bojian_mobile/resume_module_drag.dart';
import 'package:bojian_mobile/resume_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Stored order ignores unknowns and duplicates, appends missing modules',
    () {
      expect(
        resumeModuleOrder({
          resumeModuleOrderKey: ['skills', 'unknown', 'skills', 3],
        }),
        [
          'skills',
          'job_expectation',
          'self_evaluation',
          'work_experiences',
          'projects',
          'educations',
          'certifications',
        ],
      );
    },
  );

  test(
    'Default document follows editor order and separates self evaluation',
    () {
      final draft = decodeResume({
        'content': {
          'job_expectation': {'position': '工程师', 'preference': '个人优势'},
          'work_experiences': [
            {'company': '公司'},
          ],
          'educations': [
            {'institution': '学校'},
          ],
          'projects': [
            {'name': '项目'},
          ],
        },
      });
      final document = ResumeDocument(draft);
      addTearDown(document.dispose);
      expect(document.sectionTitles, ['求职期望', '自我评价', '工作经历', '项目经历', '教育经历']);
      draft.source[resumeModuleOrderKey] = [
        'educations',
        'projects',
        'self_evaluation',
      ];
      final reordered = ResumeDocument(draft);
      addTearDown(reordered.dispose);
      expect(reordered.sectionTitles, ['教育经历', '项目经历', '自我评价', '求职期望', '工作经历']);
    },
  );

  Future<AppStore> open(
    WidgetTester tester,
    FakeGateway api, {
    ResumeDraft? draft,
  }) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: ResumeEditor(
          key: UniqueKey(),
          store: store,
          draft:
              draft ??
              decodeResume({
                'id': 1,
                'revision': 1,
                'title': '顺序测试',
                'content': {
                  'job_expectation': {
                    'position': '工程师',
                    'preference': '从正文长按拖动',
                  },
                },
              }),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return store;
  }

  Future<void> dragSummary(WidgetTester tester) async {
    final target = find.byKey(const ValueKey('resume-overview-section-1'));
    // Start on body text, rather than the handle or heading.
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('从正文长按拖动')),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Long press anywhere reorders, persists and restores on reopening',
    (tester) async {
      final api = FakeGateway();
      final store = await open(tester, api);
      await dragSummary(tester);
      expect(api.calls.where((c) => c == 'PatchResumesId'), hasLength(1));
      final content = api.lastMutationBody!['content'] as Map;
      expect((content[resumeModuleOrderKey] as List).first, 'self_evaluation');
      expect(content['job_expectation']['preference'], '从正文长按拖动');
      final saved = store.resumes.single;
      await open(tester, api, draft: saved);
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('resume-overview-section-2')))
            .dy,
        lessThan(
          tester
              .getTopLeft(
                find.byKey(const ValueKey('resume-overview-section-1')),
              )
              .dy,
        ),
      );
      final document = ResumeDocument(saved);
      addTearDown(document.dispose);
      expect(document.sectionTitles.take(2), ['自我评价', '求职期望']);
      final summary = find.text('从正文长按拖动');
      final gesture = await tester.startGesture(tester.getCenter(summary));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      final distance = tester
          .getSize(find.byKey(const ValueKey('resume-overview-section-1')))
          .height;
      for (var step = 0; step < 10; step++) {
        await gesture.moveBy(Offset(0, distance / 10));
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pump(const Duration(milliseconds: 400));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(api.calls.where((c) => c == 'PatchResumesId'), hasLength(2));
      expect(
        (api.lastMutationBody!['content'][resumeModuleOrderKey] as List).first,
        'job_expectation',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Failed reorder restores the original order without losing content',
    (tester) async {
      final api = FakeGateway()..failing = 'PatchResumesId';
      await open(tester, api);
      await dragSummary(tester);
      expect(find.text('服务器暂不可用'), findsOneWidget);
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('resume-overview-section-1')))
            .dy,
        lessThan(
          tester
              .getTopLeft(
                find.byKey(const ValueKey('resume-overview-section-2')),
              )
              .dy,
        ),
      );
      expect(find.text('从正文长按拖动'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Pickup collapses all long content and the proxy; cancel and release restore it',
    (tester) async {
      final api = FakeGateway();
      final longText = List.filled(30, '这一段是很长的工作内容与成果。').join('\n');
      final draft = decodeResume({
        'id': 1,
        'revision': 1,
        'content': {
          'job_expectation': {'position': '工程师', 'preference': longText},
          'work_experiences': [
            {'company': '测试公司', 'description': longText},
          ],
          'projects': [
            {'name': '测试项目', 'description': longText},
          ],
          'educations': [
            {'institution': '测试大学', 'campus_experience': longText},
          ],
          'skills': [
            {'name': '专业技能', 'description': longText},
          ],
          'certifications': [
            {'name': '证书'},
          ],
        },
      });
      await open(tester, api, draft: draft);
      for (final cancel in [true, false]) {
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('自我评价')),
        );
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pumpAndSettle();
        expect(find.text(longText), findsNothing);
        final cards = tester
            .widgetList<ResumeOverviewCard>(find.byType(ResumeOverviewCard))
            .where((card) => card.title != null)
            .toList();
        expect(cards, hasLength(7));
        expect(cards.every((card) => card.compact), isTrue);
        expect(
          tester.getSize(find.byType(ResumeModuleDragProxy)).height,
          lessThan(80),
        );
        if (cancel) {
          await gesture.cancel();
        } else {
          await gesture.up();
        }
        await tester.pumpAndSettle();
        expect(find.text(longText), findsWidgets);
        expect(
          tester
              .widgetList<ResumeOverviewCard>(find.byType(ResumeOverviewCard))
              .every((card) => !card.compact),
          isTrue,
        );
        expect(api.calls, isNot(contains('PatchResumesId')));
        expect(tester.takeException(), isNull);
      }
      // Releasing while compact layout is still being prepared must also restore.
      final quick = await tester.startGesture(
        tester.getCenter(find.text('自我评价')),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await quick.up();
      await tester.pumpAndSettle();
      expect(find.text(longText), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Dragging below a long module uses compact gaps and preserves every description',
    (tester) async {
      final api = FakeGateway();
      final longText = List.filled(50, '完整内容不能因为拖拽而丢失。').join('\n');
      await open(
        tester,
        api,
        draft: decodeResume({
          'id': 1,
          'revision': 1,
          'content': {
            'job_expectation': {'position': '工程师', 'preference': longText},
            'work_experiences': [
              {'company': '公司', 'description': longText},
            ],
            'projects': [
              {'name': '项目', 'description': longText},
            ],
          },
        }),
      );
      final work = find.byKey(const ValueKey('resume-overview-section-3'));
      await tester.scrollUntilVisible(
        work,
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('工作经历')),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text(longText), findsNothing);
      expect(
        tester.getSize(find.byType(ResumeModuleDragProxy)).height,
        lessThan(80),
      );
      final target = tester.getCenter(
        find.byKey(const ValueKey('resume-overview-section-1')),
      );
      await gesture.moveTo(target);
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pumpAndSettle();
      final content = api.lastMutationBody!['content'];
      expect(content[resumeModuleOrderKey].first, 'work_experiences');
      expect(content['job_expectation']['preference'], longText);
      expect(content['work_experiences'][0]['description'], longText);
      expect(content['projects'][0]['description'], longText);
      expect(
        tester
            .widgetList<ResumeOverviewCard>(find.byType(ResumeOverviewCard))
            .every((card) => !card.compact),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
