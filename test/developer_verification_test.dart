import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/developer_verification_controller.dart';
import 'package:bojian_mobile/developer_verification_page.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

XFile photo() => XFile.fromData(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAEUlEQVR4nGNwmHAAjhiI4wAAglIZAaTN9MkAAAAASUVORK5CYII=',
  ),
  name: 'identity.png',
  mimeType: 'image/png',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Both photos and explicit consent are required, without API requests',
    () async {
      final api = FakeGateway();
      final store = await testStore(authenticated: true, api: api);
      final controller = DeveloperVerificationController(
        store: store,
        pickPhoto: () async => photo(),
      );
      addTearDown(store.dispose);
      addTearDown(controller.dispose);
      final calls = List<String>.of(api.calls);
      expect(controller.agreed, isFalse);
      expect(controller.canContinue, isFalse);
      controller.setAgreed(true);
      expect(controller.canContinue, isFalse);
      await controller.selectPhoto(VerificationPhotoSide.portrait);
      expect(controller.photo(VerificationPhotoSide.portrait), isNotNull);
      expect(controller.canContinue, isFalse);
      await controller.selectPhoto(VerificationPhotoSide.emblem);
      expect(controller.canContinue, isTrue);
      controller.setAgreed(false);
      expect(controller.canContinue, isFalse);
      expect(api.calls, calls);
    },
  );

  test(
    'Cancelling or invalid replacements preserves the selected photo',
    () async {
      final store = await testStore(authenticated: true);
      XFile? selected = photo();
      final controller = DeveloperVerificationController(
        store: store,
        pickPhoto: () async => selected,
      );
      addTearDown(store.dispose);
      addTearDown(controller.dispose);
      await controller.selectPhoto(VerificationPhotoSide.portrait);
      final original = controller.photo(VerificationPhotoSide.portrait);
      selected = null;
      await controller.selectPhoto(VerificationPhotoSide.portrait);
      expect(controller.photo(VerificationPhotoSide.portrait), same(original));
      expect(controller.error, isNull);
      selected = XFile.fromData(
        utf8.encode('not a photo'),
        name: 'invalid.png',
      );
      await controller.selectPhoto(VerificationPhotoSide.portrait);
      expect(controller.error, contains('无法读取照片'));
      expect(controller.photo(VerificationPhotoSide.portrait), same(original));
      selected = photo();
      await controller.selectPhoto(VerificationPhotoSide.portrait);
      expect(controller.error, isNull);
      expect(
        controller.photo(VerificationPhotoSide.portrait),
        isNot(same(original)),
      );
      expect(controller.busy, isFalse);
    },
  );

  test('Empty and oversized files cannot become identity previews', () async {
    final store = await testStore(authenticated: true);
    XFile file = XFile.fromData(Uint8List(0), name: 'empty.png');
    final controller = DeveloperVerificationController(
      store: store,
      pickPhoto: () async => file,
    );
    addTearDown(store.dispose);
    addTearDown(controller.dispose);
    for (final bytes in [Uint8List(0), Uint8List(8 * 1024 * 1024 + 1)]) {
      file = XFile.fromData(bytes, name: 'photo.png');
      await controller.selectPhoto(VerificationPhotoSide.emblem);
      expect(controller.error, contains('8 MB'));
      expect(controller.photo(VerificationPhotoSide.emblem), isNull);
      expect(controller.canContinue, isFalse);
    }
  });

  test(
    'Account changes clear previews and ignore pending picker results',
    () async {
      final store = await testStore(authenticated: true);
      final pending = Completer<XFile?>();
      var calls = 0;
      final controller = DeveloperVerificationController(
        store: store,
        pickPhoto: () async => ++calls == 1 ? photo() : pending.future,
      );
      addTearDown(store.dispose);
      addTearDown(controller.dispose);
      await controller.selectPhoto(VerificationPhotoSide.portrait);
      controller.setAgreed(true);
      final selection = controller.selectPhoto(VerificationPhotoSide.emblem);
      await controller.selectPhoto(VerificationPhotoSide.emblem);
      expect(calls, 2);
      expect(controller.busy, isTrue);
      store.epoch++;
      store.changed();
      expect(controller.photo(VerificationPhotoSide.portrait), isNull);
      expect(controller.agreed, isFalse);
      pending.complete(photo());
      await selection;
      expect(controller.photo(VerificationPhotoSide.emblem), isNull);
      expect(controller.canContinue, isFalse);
      expect(controller.busy, isFalse);
    },
  );

  test(
    'Leaving the page during photo selection discards the late result',
    () async {
      final store = await testStore(authenticated: true);
      final pending = Completer<XFile?>();
      final controller = DeveloperVerificationController(
        store: store,
        pickPhoto: () => pending.future,
      );
      addTearDown(store.dispose);
      final selection = controller.selectPhoto(VerificationPhotoSide.portrait);
      controller.dispose();
      pending.complete(photo());
      await selection;
      expect(controller.photo(VerificationPhotoSide.portrait), isNull);
    },
  );

  for (final config in [
    (size: const Size(390, 844), scale: 1.0, dark: false),
    (size: const Size(320, 640), scale: 2.0, dark: true),
    (size: const Size(844, 360), scale: 2.0, dark: false),
  ]) {
    testWidgets('Verification controls, notices and examples work at $config', (
      tester,
    ) async {
      tester.view.physicalSize = config.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = await testStore(authenticated: true);
      addTearDown(store.dispose);
      var picks = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: config.dark ? appDarkTheme : appTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(config.scale)),
            child: child!,
          ),
          home: DeveloperVerificationPage(
            store: store,
            pickPhoto: () async {
              picks++;
              return null;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('本人实名认证'), findsOneWidget);
      final scroll = find.descendant(
        of: find.byKey(const ValueKey('developer-verification-scroll')),
        matching: find.byType(Scrollable),
      );
      final portrait = find.byKey(const ValueKey('developer-photo-portrait'));
      await tester.scrollUntilVisible(portrait, 150, scrollable: scroll);
      await tester.tap(portrait);
      await tester.pumpAndSettle();
      expect(picks, 1);
      final consent = find.byKey(
        const ValueKey('developer-verification-consent'),
      );
      await tester.scrollUntilVisible(consent, 150, scrollable: scroll);
      await tester.ensureVisible(consent);
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(consent).value, isFalse);
      expect(
        tester.getCenter(consent).dy,
        closeTo(
          tester
              .getCenter(
                find.byKey(
                  const ValueKey('developer-verification-consent-label'),
                ),
              )
              .dy,
          .01,
        ),
      );
      expect(
        tester.widget<Checkbox>(consent).activeColor,
        Theme.of(tester.element(consent)).extension<AppColors>()!.accent,
      );
      await tester.tap(consent);
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(consent).value, isTrue);
      final next = find.byKey(const ValueKey('developer-verification-next'));
      await tester.scrollUntilVisible(next, 150, scrollable: scroll);
      expect(tester.widget<FilledButton>(next).onPressed, isNull);
      final usage = find.byKey(const ValueKey('developer-verification-usage'));
      await tester.ensureVisible(usage);
      await tester.pumpAndSettle();
      await tester.tap(usage);
      await tester.pumpAndSettle();
      expect(find.text('身份信息使用说明'), findsOneWidget);
      await tester.tap(find.text('知道了'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('更多帮助'),
        150,
        scrollable: scroll,
      );
      await tester.tap(find.text('更多帮助'));
      await tester.pumpAndSettle();
      expect(find.text('证件拍摄须知'), findsOneWidget);
      await tester.tap(find.text('知道了'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('闪光强烈'),
        150,
        scrollable: scroll,
      );
      expect(find.text('标准拍摄'), findsOneWidget);
      expect(find.text('边框缺失'), findsOneWidget);
      expect(find.text('照片模糊'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
