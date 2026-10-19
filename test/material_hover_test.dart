import 'dart:ui' as ui;

import 'package:bojian_mobile/app_theme.dart';
import 'package:bojian_mobile/app_shell.dart';

import 'support/fake_gateway.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<int>> pixels(WidgetTester tester, GlobalKey key) async =>
    (await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!.buffer.asUint8List().toList();
    }))!;

void main() {
  for (final theme in [appTheme, appDarkTheme]) {
    testWidgets(
      'Real discovery and profile tabs stay unchanged on hover (${theme.brightness})',
      (tester) async {
        tester.view.physicalSize = const Size(390, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = await testStore(authenticated: true, seeded: true);
        addTearDown(store.dispose);
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            builder: (_, child) => RepaintBoundary(key: key, child: child!),
            home: AppShell(store: store),
          ),
        );
        await tester.pumpAndSettle();
        for (final nav in [0, 3]) {
          await tester.tap(find.byKey(ValueKey('nav-$nav')));
          await tester.pumpAndSettle();
          final before = await pixels(tester, key);
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: Offset.zero);
          final tabs = find.descendant(
            of: find.byType(TabBar),
            matching: find.byType(Tab),
          );
          for (var i = 0; i < tabs.evaluate().length; i++) {
            await mouse.moveTo(tester.getCenter(tabs.at(i)));
            await tester.pumpAndSettle();
            expect(
              await pixels(tester, key),
              before,
              reason: 'navigation $nav tab $i',
            );
          }
          await mouse.removePointer();
        }
        await tester.tap(find.byKey(const ValueKey('profile-tab-resumes')));
        await tester.pumpAndSettle();
        expect(
          DefaultTabController.of(tester.element(find.byType(TabBar))).index,
          2,
        );
        expect(tester.takeException(), isNull);
      },
    );
    final cases = <String, Widget>{
      'tabs': const DefaultTabController(
        length: 3,
        child: TabBar(
          tabs: [
            Tab(text: '动态'),
            Tab(text: '收藏'),
            Tab(text: '简历'),
          ],
        ),
      ),
      'filled': FilledButton(onPressed: () {}, child: const Text('按钮')),
      'outlined': OutlinedButton(onPressed: () {}, child: const Text('按钮')),
      'icon-filled': IconButton.filled(
        onPressed: () {},
        icon: const Icon(Icons.add),
      ),
      'floating': FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
      'list': ListTile(title: const Text('列表'), onTap: () {}),
      'checkbox-list': CheckboxListTile(
        title: const Text('复选'),
        value: false,
        onChanged: (_) {},
      ),
      'selected-chip': ChoiceChip(
        label: const Text('筛选'),
        selected: true,
        onSelected: (_) {},
      ),
      'filter-chip': FilterChip(
        label: const Text('筛选'),
        selected: false,
        onSelected: (_) {},
      ),
      'input': const TextField(),
      'dropdown': DropdownButtonFormField<String>(
        initialValue: 'a',
        items: const [DropdownMenuItem(value: 'a', child: Text('选项'))],
        onChanged: (_) {},
      ),
      'slider': Slider(value: .5, onChanged: (_) {}),
      'menu': MenuItemButton(onPressed: () {}, child: const Text('菜单项')),
    };
    for (final entry in cases.entries) {
      testWidgets(
        '${entry.key} has no hover background (${theme.brightness})',
        (tester) async {
          final key = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              builder: (_, child) => RepaintBoundary(key: key, child: child!),
              home: Scaffold(
                body: Center(child: SizedBox(width: 300, child: entry.value)),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final before = await pixels(tester, key);
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: Offset.zero);
          final target = entry.key == 'tabs'
              ? find.text('简历')
              : find.byWidget(entry.value);
          await mouse.moveTo(tester.getCenter(target));
          await tester.pumpAndSettle();
          expect(
            await pixels(tester, key),
            before,
            reason: '${entry.key} changed after hover',
          );
          await mouse.removePointer();
        },
      );
    }
  }
}
