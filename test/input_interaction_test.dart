import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:bojian_mobile/discovery.dart';
import 'package:bojian_mobile/account_pages.dart';
import 'package:bojian_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';
import 'support/resume_editor_helpers.dart';

const articleTitle = '一页简历拿到 5 个面试，\n我删掉了这些内容';

Future<void> launch(WidgetTester tester, {bool guest = false}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MyApp(
      startupAdsEnabled: false,
      store: await testStore(authenticated: guest, seeded: guest),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> launchBinding(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final api = FakeGateway();
  api.documents['GetMe']!.remove('phone_masked');
  final store = await testStore(authenticated: true, api: api);
  await tester.pumpWidget(MyApp(startupAdsEnabled: false, store: store));
  await tester.pumpAndSettle();
}

EditableText editable(WidgetTester tester, Finder field) => tester.widget(
  find.descendant(of: field, matching: find.byType(EditableText)),
);

Future<void> keyboard(WidgetTester tester) async {
  tester.view.viewInsets = const FakeViewPadding(bottom: 300);
  addTearDown(tester.view.resetViewInsets);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Binding preserves input through rotation and keeps actions above keyboard',
    (tester) async {
      await launchBinding(tester);
      final phone = find.byKey(const ValueKey('phone-binding-phone'));
      final code = find.byKey(const ValueKey('phone-binding-code'));
      await tester.enterText(phone, '13812345678');
      await tester.enterText(code, '123456');
      await tester.tap(code);
      await tester.pumpAndSettle();
      final focus = editable(tester, code).focusNode;

      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(editable(tester, phone).controller.text, '13812345678');
      expect(editable(tester, code).controller.text, '123456');
      expect(editable(tester, code).focusNode, same(focus));
      expect(focus.hasFocus, isTrue);

      tester.view.viewInsets = const FakeViewPadding(bottom: 230);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final submit = find.byKey(const ValueKey('phone-binding-confirm'));
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      expect(tester.getRect(submit).bottom, lessThanOrEqualTo(160));
      expect(tester.takeException(), isNull);

      tester.view.resetViewInsets();
      tester.view.physicalSize = const Size(640, 320);
      await tester.pumpAndSettle();
      await tester.ensureVisible(submit);
      expect(tester.getRect(submit).bottom, lessThanOrEqualTo(320));
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(editable(tester, code).controller.text, '123456');
      expect(editable(tester, code).focusNode, same(focus));
      expect(focus.hasFocus, isTrue);
    },
  );

  testWidgets('Touching blank space dismisses focus and preserves text', (
    tester,
  ) async {
    await launchBinding(tester);
    final field = find.byKey(const ValueKey('phone-binding-phone'));
    await tester.enterText(field, '13812345678');
    await tester.pumpAndSettle();
    expect(editable(tester, field).focusNode.hasFocus, isTrue);
    await tester.tap(find.text('绑定手机号'));
    await tester.pumpAndSettle();
    expect(editable(tester, field).focusNode.hasFocus, isFalse);
    expect(editable(tester, field).controller.text, '13812345678');
  });

  testWidgets('Next moves to code and Done dismisses without submitting', (
    tester,
  ) async {
    await launchBinding(tester);
    await tester.enterText(
      find.byKey(const ValueKey('phone-binding-phone')),
      '13812345678',
    );
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('phone-binding-code'));
    expect(editable(tester, field).focusNode.hasFocus, isTrue);
    await tester.enterText(field, '123456');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(editable(tester, field).focusNode.hasFocus, isFalse);
    expect(find.byKey(const ValueKey('phone-binding-error')), findsNothing);
    expect(find.text('绑定手机号'), findsOneWidget);
  });

  testWidgets('Dragging resume form dismisses focus without losing edits', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await launch(tester, guest: true);
    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-tab-resumes')));
    await tester.pumpAndSettle();
    final card = find
        .ancestor(of: find.text('产品经理 · 社招简历'), matching: find.byType(InkWell))
        .last;
    await tester.tapAt(tester.getTopLeft(card) + const Offset(8, 30));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    await openResumeSection(tester, 0);
    final field = find.byKey(const ValueKey('resume-name'));
    await tester.enterText(field, '小简');
    final focus = editable(tester, field).focusNode;
    await tester.drag(find.byType(ListView).first, const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isFalse);
    await saveResumeSection(tester);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(RegExp('简历第.*小简', dotAll: true)),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('Comments remain above keyboard and send on first tap', (
    tester,
  ) async {
    await launch(tester, guest: true);
    await tester.tap(find.text(articleTitle));
    await tester.pumpAndSettle();
    final field = find.byType(TextField);
    await tester.enterText(field, '收起键盘也不能丢失这段话');
    await keyboard(tester);
    expect(tester.getRect(field).bottom, lessThanOrEqualTo(544));
    await tester.tap(find.byKey(const ValueKey('article-comment-send')));
    await tester.pumpAndSettle();
    expect(editable(tester, field).focusNode.hasFocus, isFalse);
    expect(editable(tester, field).controller.text, isEmpty);
    final page = tester.widget<StoryDetail>(find.byType(StoryDetail));
    expect(page.story.comments.last.content, contains('收起键盘也不能丢失这段话'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Rich editor has an explicit keyboard dismissal action', (
    tester,
  ) async {
    await launch(tester, guest: true);
    await tester.tap(find.byKey(const ValueKey('discovery-create')));
    await tester.pumpAndSettle();
    final editor = tester.widget<quill.QuillEditor>(
      find.byKey(const ValueKey('composer-body')),
    );
    editor.controller.replaceText(
      0,
      0,
      '第一段\n第二段',
      const TextSelection.collapsed(offset: 7),
    );
    editor.focusNode.requestFocus();
    await tester.pumpAndSettle();
    await keyboard(tester);
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == '收起键盘',
      ),
    );
    await tester.pumpAndSettle();
    expect(editor.focusNode.hasFocus, isFalse);
    expect(editor.controller.document.toPlainText(), '第一段\n第二段\n');
  });

  testWidgets('Search can be cleared without dismissing keyboard', (
    tester,
  ) async {
    await launch(tester, guest: true);
    await tester.tap(find.byKey(const ValueKey('discovery-search')));
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('discovery-search'));
    await tester.enterText(field, '不存在的关键词');
    await tester.pumpAndSettle();
    expect(find.text('没有找到相关内容'), findsOneWidget);
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == '清空搜索',
      ),
    );
    await tester.pumpAndSettle();
    expect(editable(tester, field).focusNode.hasFocus, isTrue);
    expect(editable(tester, field).controller.text, isEmpty);
    expect(find.text(articleTitle), findsOneWidget);
  });

  testWidgets('Input dismissal also works inside a modal sheet', (
    tester,
  ) async {
    await launch(tester, guest: true);
    final store = await testStore(authenticated: true);
    addTearDown(store.dispose);
    showModalBottomSheet<void>(
      context: tester.element(find.byType(Scaffold).first),
      isScrollControlled: true,
      builder: (_) => AddFriendSheet(store: store),
    );
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: find.byType(AddFriendSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, '周予安');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await keyboard(tester);
    await tester.tap(find.text('找到一起进步的人'));
    await tester.pumpAndSettle();
    expect(editable(tester, field).focusNode.hasFocus, isFalse);
    expect(find.text('周予安'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
