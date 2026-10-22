import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/photo_source_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

Future<void> mount(
  WidgetTester tester, {
  required VoidCallback onOpen,
  Size size = const Size(390, 844),
  double scale = 1,
  bool dark = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? appDarkTheme : appTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: TextButton(onPressed: onOpen, child: const Text('上传照片')),
        ),
      ),
    ),
  );
  await tester.tap(find.text('上传照片'));
  await tester.pumpAndSettle();
}

void main() {
  for (final source in ImageSource.values) {
    testWidgets('Photo action sheet sends $source only after selection', (
      tester,
    ) async {
      ImageSource? chosen;
      XFile? result;
      final file = XFile.fromData(Uint8List(0), name: 'chosen.jpg');
      await mount(
        tester,
        onOpen: () async {
          result = await pickAppPhoto(
            tester.element(find.text('上传照片')),
            capture: (source) async {
              chosen = source;
              return file;
            },
          );
        },
      );
      expect(find.text('拍照'), findsOneWidget);
      expect(find.text('从相册选择'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(chosen, isNull);
      await tester.tap(find.byKey(ValueKey('photo-source-${source.name}')));
      await tester.pumpAndSettle();
      expect(chosen, source);
      expect(result, same(file));
      expect(find.byKey(const ValueKey('photo-source-sheet')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final back in [false, true]) {
    testWidgets(
      'Cancelling the source sheet does not invoke native picker ($back)',
      (tester) async {
        var calls = 0;
        var completed = false;
        XFile? result;
        await mount(
          tester,
          onOpen: () async {
            result = await pickAppPhoto(
              tester.element(find.text('上传照片')),
              capture: (_) async {
                calls++;
                return null;
              },
            );
            completed = true;
          },
        );
        if (back) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.text('取消'));
        }
        await tester.pumpAndSettle();
        expect(calls, 0);
        expect(completed, isTrue);
        expect(result, isNull);
      },
    );
  }

  testWidgets('Stale account cannot open the camera after choosing a source', (
    tester,
  ) async {
    var current = true;
    var calls = 0;
    await mount(
      tester,
      onOpen: () async {
        await pickAppPhoto(
          tester.element(find.text('上传照片')),
          isCurrent: () => current,
          capture: (_) async {
            calls++;
            return null;
          },
        );
      },
    );
    current = false;
    await tester.tap(find.text('拍照'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Camera denial reports a useful message', (tester) async {
    ApiFailure? failure;
    await mount(
      tester,
      onOpen: () async {
        try {
          await pickAppPhoto(
            tester.element(find.text('上传照片')),
            capture: (_) async =>
                throw PlatformException(code: 'camera_access_denied'),
          );
        } on ApiFailure catch (error) {
          failure = error;
        }
      },
    );
    await tester.tap(find.text('拍照'));
    await tester.pumpAndSettle();
    expect(failure?.message, '无法使用相机，请在系统设置中允许相机访问');
    expect(tester.takeException(), isNull);
  });

  for (final config in [
    (size: const Size(320, 640), dark: true),
    (size: const Size(844, 360), dark: false),
  ]) {
    testWidgets('Photo source sheet supports large text at $config', (
      tester,
    ) async {
      await mount(
        tester,
        size: config.size,
        scale: 2,
        dark: config.dark,
        onOpen: () async => pickAppPhoto(tester.element(find.text('上传照片'))),
      );
      expect(find.text('拍照').hitTestable(), findsOneWidget);
      expect(find.text('从相册选择').hitTestable(), findsOneWidget);
      expect(find.text('取消').hitTestable(), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
