import 'package:bojian_mobile/app_page_bar.dart';
import 'package:bojian_mobile/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Shared title reacts to edits, truncates and fits system text scaling',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final title = ValueNotifier('很长的简历名称用于检查标题省略及右侧操作可点击');
      addTearDown(title.dispose);
      var saved = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            appBar: AppPageBar(
              title: ValueListenableBuilder<String>(
                valueListenable: title,
                builder: (_, text, _) => Text(text),
              ),
              actions: [
                TextButton(
                  onPressed: () => saved = true,
                  child: const Text('保存'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final bar = tester.widget<AppBar>(find.byType(AppBar));
      expect(bar.titleTextStyle?.fontSize, 17);
      expect(bar.centerTitle, isFalse);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text(title.value),
      );
      expect(paragraph.maxLines, 1);
      expect(paragraph.overflow, TextOverflow.ellipsis);
      await tester.tap(find.text('保存'));
      expect(saved, isTrue);
      title.value = '新的简历名称';
      await tester.pumpAndSettle();
      expect(find.text('新的简历名称'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Automatic back respects PopScope and drawer navigation', (
    tester,
  ) async {
    var allowBack = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            appBar: const AppPageBar(title: Text('首页')),
            drawer: const Drawer(child: Text('侧边栏')),
            body: TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => StatefulBuilder(
                    builder: (context, update) => PopScope(
                      canPop: allowBack,
                      child: Scaffold(
                        appBar: const AppPageBar(title: Text('详情')),
                        body: TextButton(
                          onPressed: () => update(() => allowBack = true),
                          child: const Text('允许返回'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(DrawerButton));
    await tester.pumpAndSettle();
    expect(find.text('侧边栏'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(tester.widget<AppBar>(find.byType(AppBar)).titleSpacing, 0);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('详情'), findsOneWidget);
    await tester.tap(find.text('允许返回'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('首页'), findsOneWidget);
  });

  testWidgets(
    'Custom leading, inverted colors and bottom content are retained',
    (tester) async {
      var closed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: appDarkTheme,
          home: Scaffold(
            appBar: AppPageBar(
              title: const Text('照片'),
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              automaticallyImplyLeading: false,
              leading: IconButton(
                onPressed: () => closed = true,
                icon: const Icon(Icons.close),
              ),
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(36),
                child: SizedBox(height: 36, child: Text('页签')),
              ),
            ),
          ),
        ),
      );
      final header = tester.widget<AppPageBar>(find.byType(AppPageBar));
      expect(header.preferredSize.height, 92);
      final bar = tester.widget<AppBar>(find.byType(AppBar));
      expect(bar.foregroundColor, Colors.white);
      expect(bar.backgroundColor, Colors.black);
      expect(find.byType(BackButton), findsNothing);
      expect(find.text('页签'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      expect(closed, isTrue);
    },
  );
}
