import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/resume_document.dart';
import 'package:bojian_mobile/resume_template_picker.dart';
import 'package:bojian_mobile/resume_templates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class TemplateGateway extends FakeGateway {
  Map<String, String>? patchHeaders;
  Map<String, dynamic>? patchBody;
  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) {
    if (method == 'PatchResumesId') {
      patchHeaders = headers;
      patchBody = body;
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
  TestWidgetsFlutterBinding.ensureInitialized();
  late TemplateGateway api;
  late AppStore store;
  setUp(() async {
    api = TemplateGateway();
    store = AppStore(api: api, storage: MemoryStorage());
    await store.initialize();
    store.session = {'access_token': 'test'};
    api.documents['GetResumesId'] = {
      'id': 1,
      'revision': 9,
      'title': '我的简历',
      'content': {
        'personal_info': {'full_name': '测试姓名'},
        'projects': [
          {'name': '保留项目'},
        ],
      },
    };
    store.resumes.add(
      decodeResume({...api.documents['GetResumesId']!, 'revision': 2}),
    );
  });
  tearDown(() => store.dispose());

  test(
    'Template switch uses latest revision and preserves all resume data',
    () async {
      await store.changeResumeLayout(1, ResumeLayout.standard);
      expect(api.patchHeaders!['if-match'], '"revision-9"');
      expect(api.patchBody!.keys, ['content']);
      expect(api.patchBody!['content']['projects'][0]['name'], '保留项目');
      expect(store.resumes.first.template, ResumeLayout.standard.id);
      expect(store.resumes.first.copy().template, ResumeLayout.standard.id);
    },
  );
  test('Failed template save preserves the current layout', () async {
    api.failing = 'PatchResumesId';
    await expectLater(
      store.changeResumeLayout(1, ResumeLayout.standard),
      throwsA(isA<ApiFailure>()),
    );
    expect(store.resumes.first.template, ResumeLayout.standard.id);
  });
  test(
    'Acquired templates are deduplicated and authored designs excluded',
    () async {
      api.documents['GetMeTemplates'] = {
        'items': [
          {'id': 7, 'name': '购买模板', 'source': 'ACQUIRED'},
          {'id': 7, 'name': '重复记录', 'source': 'ACQUIRED'},
          {'id': 8, 'name': '发布模板', 'source': 'PUBLISHED_BY_ME'},
          {'id': 0, 'source': 'ACQUIRED'},
        ],
      };
      expect((await store.purchasedResumeTemplates()).map((v) => v['id']), [7]);
    },
  );
  test(
    'Market switch binds real ID with latest revision and all resume fields',
    () async {
      api.documents['GetMeTemplates'] = {
        'items': [
          {'id': 7, 'name': '购买模板', 'source': 'ACQUIRED'},
        ],
      };
      api.documents['GetTemplatesIdDom'] = {
        'template_id': 7,
        'html': '<p>{{name}}</p>',
        'css': '',
      };
      await store.changeResumeMarketTemplate(1, 7);
      expect(api.patchHeaders!['if-match'], '"revision-9"');
      expect(api.patchBody!['template_id'], 7);
      expect(api.patchBody!['content']['projects'][0]['name'], '保留项目');
      expect(store.resumes.first.marketTemplateID, 7);
      expect(store.resumes.first.copy().templateTitle, '购买模板');
    },
  );
  test(
    'Unowned template cannot be applied or acquired by selecting it',
    () async {
      api.documents['GetMeTemplates'] = {'items': []};
      await expectLater(
        store.changeResumeMarketTemplate(1, 7),
        throwsA(isA<ApiFailure>()),
      );
      expect(api.calls, isNot(contains('PatchResumesId')));
      expect(api.calls, isNot(contains('PostTemplatesIdAcquisitions')));
    },
  );
  test('Only blue standard remains and legacy layouts preserve content', () {
    expect(ResumeLayout.values, [ResumeLayout.standard]);
    final reference = ResumeDocument(store.resumes.first.copy());
    addTearDown(reference.dispose);
    expect(
      reference.painters.first.text!.style!.color,
      ResumeLayout.standard.accent,
    );
    for (final oldID in [
      'standard',
      'compact',
      'business_blue',
      '',
      'unknown',
    ]) {
      final draft = store.resumes.first.copy();
      draft.source['app_layout'] = oldID;
      final document = ResumeDocument(draft);
      addTearDown(document.dispose);
      expect(document.layout, ResumeLayout.standard);
      expect(
        document.painters.first.text!.style!.color,
        const Color(0xFF245EA8),
      );
      expect(
        document.painters.map((p) => p.text!.toPlainText()).toList(),
        reference.painters.map((p) => p.text!.toPlainText()).toList(),
      );
      expect(document.painters.first.height, reference.painters.first.height);
      expect(
        decodeResume({'id': 1, 'content': draft.source}).template,
        'standard',
      );
    }
  });
  testWidgets(
    'Picker lists standard and purchased templates without unowned or authored designs',
    (tester) async {
      api.documents['GetMeTemplates'] = {
        'items': [
          {'id': 7, 'name': '已购买设计', 'source': 'ACQUIRED'},
          {'id': 8, 'name': '自己发布的设计', 'source': 'PUBLISHED_BY_ME'},
        ],
      };
      api.documents['GetTemplates'] = {
        'items': [
          {'id': 9, 'name': '未购买设计'},
        ],
      };
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ResumeTemplatePicker(
                store: store,
                resume: store.resumes.first,
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pumpAndSettle();
      expect(find.text('已购买设计'), findsOneWidget);
      expect(find.text('自己发布的设计'), findsNothing);
      expect(find.text('未购买设计'), findsNothing);
      expect(find.text('模板市场'), findsNothing);
      expect(find.text('商务蓝'), findsNothing);
      expect(find.text('简约'), findsNothing);
      await tester.tap(find.text('标准模板'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('GetMeTemplates'));
      expect(api.calls, isNot(contains('GetTemplates')));
      expect(api.calls, isNot(contains('PatchResumesId')));
      expect(find.text('当前使用'), findsOneWidget);
      expect(find.text('使用选中模板'), findsOneWidget);
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.text('使用选中模板')).bottom, lessThan(390));
      await tester.tap(find.text('已购买设计'));
      await tester.pumpAndSettle();
      expect(api.calls, isNot(contains('PatchResumesId')));
      final selection = tester.widgetList<Semantics>(find.byType(Semantics)).where((widget) => widget.properties.label == '已购买设计');
      expect(selection.single.properties.selected, isTrue);
    },
  );
}
