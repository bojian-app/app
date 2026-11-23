import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/story_composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class ComposerGateway extends FakeGateway {
  Map<String, dynamic>? article;
  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    if (method == 'PostArticles') {
      article = body;
      if (failing == method) throw const ApiFailure('提交失败');
      return ApiDocument({'id': 99});
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
    'Formatting applies to selected text and failed submissions preserve content',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = ComposerGateway()..failing = 'PostArticles';
      final store = await testStore(authenticated: true, api: api);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: StoryComposer(store: store),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('composer-title')),
        '我的面试复盘',
      );
      final editor = tester.widget<quill.QuillEditor>(
        find.byKey(const ValueKey('composer-body')),
      );
      editor.controller.replaceText(
        0,
        0,
        '第一段\n第二段',
        const TextSelection(baseOffset: 0, extentOffset: 3),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('粗体'));
      await tester.pumpAndSettle();
      expect(
        editor.controller.document.toDelta().toJson().first['attributes'],
        {'bold': true},
      );
      expect(editor.focusNode.hasFocus, true);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byTooltip('粗体')).bottom,
        lessThanOrEqualTo(480),
      );
      await tester.tap(find.widgetWithText(TextButton, '发布'));
      await tester.pumpAndSettle();
      expect(api.article!['title'], '我的面试复盘');
      final blocks = (api.article!['content'] as Map)['blocks'] as List;
      expect(blocks.first['spans'], [
        {'text': '第一段', 'bold': true},
      ]);
      expect(editor.controller.document.toPlainText(), '第一段\n第二段\n');
      expect(editor.controller.readOnly, false);
      expect(find.text('我的面试复盘'), findsOneWidget);
      tester.view.viewInsets = FakeViewPadding.zero;
      tester.view.physicalSize = const Size(780, 360);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.text('放弃这篇文章？'), findsOneWidget);
      await tester.tap(find.text('继续编辑'));
      await tester.pumpAndSettle();
      expect(editor.controller.document.toPlainText(), '第一段\n第二段\n');
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets(
    'Selections survive outside touches and the format bar keeps the keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = await testStore(authenticated: true);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          ),
          home: StoryComposer(store: store),
        ),
      );
      await tester.pumpAndSettle();
      final editor = tester.widget<quill.QuillEditor>(
        find.byKey(const ValueKey('composer-body')),
      );
      final focus = editor.focusNode;
      focus.requestFocus();
      editor.controller.replaceText(
        0,
        0,
        '第一段文字',
        const TextSelection(baseOffset: 0, extentOffset: 3),
      );
      await tester.pumpAndSettle();
      // A touch outside the editor, e.g. on a selection handle.
      await tester.tapAt(const Offset(180, 60));
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isTrue);
      expect(editor.controller.selection.extentOffset, 3);
      final bar = tester.widget<SingleChildScrollView>(
        find.byKey(const ValueKey('composer-format-bar')),
      );
      expect(
        bar.keyboardDismissBehavior,
        ScrollViewKeyboardDismissBehavior.manual,
      );
      editor.controller.updateSelection(
        const TextSelection.collapsed(offset: 2),
        quill.ChangeSource.local,
      );
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(180, 60));
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isFalse);
    },
  );
}
