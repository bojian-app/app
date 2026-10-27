import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bojian_mobile/account_pages.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/profile_avatar.dart';
import 'package:bojian_mobile/profile_edit_actions.dart';
import 'package:bojian_mobile/profile_editor_views.dart';
import 'package:bojian_mobile/resume_native_export.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'support/fake_gateway.dart';

class _GalleryPicker extends ImagePickerPlatform {
  final result = Completer<XFile?>();
  int requests = 0;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) {
    expect(source, ImageSource.gallery);
    expect(options.requestFullMetadata, isFalse);
    requests++;
    return result.future;
  }
}

Future<AppStore> mount(
  WidgetTester tester,
  FakeGateway api, {
  Size size = const Size(390, 844),
  bool dark = false,
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetPadding);
  final store = await testStore(authenticated: true, api: api);
  addTearDown(store.dispose);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('profile-edit-preview'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: (dark ? appDarkTheme : appTheme).copyWith(
          textTheme: (dark ? appDarkTheme : appTheme).textTheme.apply(
            fontFamily: 'ProfileEditPreview',
          ),
          appBarTheme: (dark ? appDarkTheme : appTheme).appBarTheme.copyWith(
            titleTextStyle: (dark ? appDarkTheme : appTheme)
                .appBarTheme
                .titleTextStyle!
                .copyWith(fontFamily: 'ProfileEditPreview'),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: (dark ? appDarkTheme : appTheme).filledButtonTheme.style!
                .copyWith(
                  textStyle: const WidgetStatePropertyAll(
                    TextStyle(
                      fontFamily: 'ProfileEditPreview',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(body: ProfilePage(store: store)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  api.calls.clear();
  return store;
}

Future<void> openMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('编辑个人资料'));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('profile-edit-actions')), findsOneWidget);
}

Future<void> capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('profile-edit-preview')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build/previews').create(recursive: true);
    await File('build/previews/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> openEditor(WidgetTester tester, ProfileEditAction action) async {
  await openMenu(tester);
  await tester.tap(find.byKey(ValueKey('profile-edit-${action.name}')));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'ProfileEditPreview',
    )..addFont(rootBundle.load(resumeFontRegularAsset))).load();
  });

  for (final entry in ['avatar', 'camera', 'compact', 'details']) {
    testWidgets('Own $entry avatar opens the avatar editor directly', (
      tester,
    ) async {
      final api = FakeGateway();
      final store = await mount(tester, api);
      final before = store.avatarURL;
      Finder target;
      if (entry == 'compact') {
        final nested = tester.state<NestedScrollViewState>(
          find.byKey(const ValueKey('profile-scroll')),
        );
        nested.outerController.jumpTo(
          nested.outerController.position.maxScrollExtent,
        );
        await tester.pumpAndSettle();
        target = find.byKey(const ValueKey('profile-identity-avatar'));
      } else if (entry == 'details') {
        await tester.tap(find.byKey(const ValueKey('profile-about-summary')));
        await tester.pumpAndSettle();
        target = find.byKey(const ValueKey('profile-details-avatar'));
      } else {
        target = find.byKey(
          ValueKey(
            entry == 'camera'
                ? 'profile-avatar-camera'
                : 'profile-identity-avatar',
          ),
        );
      }
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(find.byType(ProfileEditor), findsOneWidget);
      expect(
        tester.widget<ProfileEditor>(find.byType(ProfileEditor)).action,
        ProfileEditAction.avatar,
      );
      expect(find.byKey(const ValueKey('profile-edit-actions')), findsNothing);
      expect(
        find.byKey(const ValueKey('profile-avatar-gallery')),
        findsOneWidget,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ProfileEditor), findsNothing);
      expect(store.avatarURL, before);
      expect(
        api.calls.where(
          (call) => call.startsWith('Post') || call.startsWith('Patch'),
        ),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final close in ['cancel', 'barrier', 'back']) {
    testWidgets('Edit menu dismisses without saving ($close)', (tester) async {
      final api = FakeGateway();
      await mount(tester, api);
      await tester.tap(find.byTooltip('编辑个人资料'));
      await tester.tap(find.byTooltip('编辑个人资料'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('profile-edit-actions')),
        findsOneWidget,
      );
      expect(find.byType(ProfileEditor), findsNothing);
      if (close == 'cancel') {
        await tester.tap(find.byKey(const ValueKey('profile-edit-cancel')));
      } else if (close == 'barrier') {
        await tester.tapAt(const Offset(10, 70));
      } else {
        await tester.binding.handlePopRoute();
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile-edit-actions')), findsNothing);
      expect(find.byType(ProfileEditor), findsNothing);
      expect(api.calls, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  for (final action in ProfileEditAction.values) {
    testWidgets(
      'Menu routes to the corresponding existing form (${action.name})',
      (tester) async {
        final api = FakeGateway();
        await mount(tester, api);
        await openMenu(tester);
        await tester.tap(find.byKey(ValueKey('profile-edit-${action.name}')));
        await tester.pumpAndSettle();
        expect(
          tester.widget<ProfileEditor>(find.byType(ProfileEditor)).action,
          action,
        );
        expect(
          find.byKey(const ValueKey('profile-edit-actions')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('profile-name')),
          action == ProfileEditAction.settings ? findsOneWidget : findsNothing,
        );
        expect(
          find.byKey(const ValueKey('profile-bio')),
          action == ProfileEditAction.avatar ? findsNothing : findsOneWidget,
        );
        expect(
          find.text('更换头像'),
          action == ProfileEditAction.settings ? findsOneWidget : findsNothing,
        );
        if (action == ProfileEditAction.avatar) {
          expect(find.byKey(const ValueKey('profile-save')), findsNothing);
          await tester.tap(find.byKey(const ValueKey('profile-avatar-system')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('system-avatar-3')));
          await tester.pumpAndSettle();
          expect(
            tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).variant,
            3,
          );
        }
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(ProfileEditor), findsNothing);
        expect(api.calls, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Biography saves only the edited field and preserves concurrent nickname changes',
    (tester) async {
      final api = FakeGateway();
      final store = await mount(tester, api);
      await openMenu(tester);
      await tester.tap(find.byKey(const ValueKey('profile-edit-bio')));
      await tester.pumpAndSettle();
      store.name = '更新后的昵称';
      api.documents['GetMe']!['nickname'] = store.name;
      store.changed();
      await tester.enterText(
        find.byKey(const ValueKey('profile-bio')),
        '保持好奇，认真生活。',
      );
      await tester.tap(find.byKey(const ValueKey('profile-save')));
      await tester.pumpAndSettle();
      expect(api.lastMutationBody, {'bio': '保持好奇，认真生活。'});
      expect(api.calls.where((call) => call == 'PatchMe'), hasLength(1));
      expect(store.name, '更新后的昵称');
      expect(store.bio, '保持好奇，认真生活。');
      expect(find.byType(ProfileEditor), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'A session change while the menu is open cannot enter an editor',
    (tester) async {
      final api = FakeGateway();
      final store = await mount(tester, api);
      await openMenu(tester);
      await store.endSession(remote: false);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-edit-settings')));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileEditor), findsNothing);
      expect(api.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Biography keeps drafts on failure and saves only on retry', (
    tester,
  ) async {
    final api = FakeGateway()..documents['GetMe']!['bio'] = '原来的简介';
    final store = await mount(tester, api);
    await openEditor(tester, ProfileEditAction.bio);
    await tester.enterText(find.byKey(const ValueKey('profile-bio')), '编辑后的简介');
    api.failing = 'PatchMe';
    await tester.tap(find.byKey(const ValueKey('profile-save')));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileBiographyEditorView), findsOneWidget);
    expect(store.bio, '原来的简介');
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('profile-bio')))
          .controller!
          .text,
      '编辑后的简介',
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('profile-save')))
          .onPressed,
      isNotNull,
    );
    api.failing = null;
    await tester.tap(find.byKey(const ValueKey('profile-save')));
    await tester.pumpAndSettle();
    expect(store.bio, '编辑后的简介');
    expect(find.byType(ProfileEditor), findsNothing);
    expect(api.calls.where((call) => call == 'PatchMe'), hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Biography enforces its existing limit and can be cleared', (
    tester,
  ) async {
    final api = FakeGateway()..documents['GetMe']!['bio'] = '已有简介';
    final store = await mount(tester, api);
    await openEditor(tester, ProfileEditAction.bio);
    final field = find.byKey(const ValueKey('profile-bio'));
    await tester.enterText(field, List.filled(130, '简').join());
    expect(tester.widget<TextField>(field).controller!.text.length, 120);
    await tester.enterText(field, '');
    await tester.tap(find.byKey(const ValueKey('profile-save')));
    await tester.pumpAndSettle();
    expect(store.bio, isEmpty);
    expect(api.lastMutationBody, {'bio': ''});
    expect(tester.takeException(), isNull);
  });

  for (final expired in [false, true]) {
    testWidgets('Gallery cancel or stale result never writes ($expired)', (
      tester,
    ) async {
      final previousPicker = ImagePickerPlatform.instance;
      final picker = _GalleryPicker();
      ImagePickerPlatform.instance = picker;
      addTearDown(() => ImagePickerPlatform.instance = previousPicker);
      final api = FakeGateway();
      final store = await mount(tester, api);
      await openEditor(tester, ProfileEditAction.avatar);
      final gallery = find.byKey(const ValueKey('profile-avatar-gallery'));
      await tester.tap(gallery);
      await tester.tap(gallery);
      await tester.pump();
      expect(picker.requests, 1);
      expect(tester.widget<FilledButton>(gallery).onPressed, isNull);
      if (expired) store.epoch++;
      picker.result.complete(expired ? XFile('/not-read/stale.png') : null);
      await tester.pumpAndSettle();
      expect(find.byType(ProfileAvatarEditorView), findsOneWidget);
      expect(tester.widget<FilledButton>(gallery).onPressed, isNotNull);
      expect(find.byKey(const ValueKey('profile-save')), findsNothing);
      expect(api.calls, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  for (final config in [
    (name: 'light', size: const Size(390, 844), dark: false, scale: 1.0),
    (name: 'dark', size: const Size(390, 844), dark: true, scale: 1.0),
    (name: 'small', size: const Size(320, 600), dark: false, scale: 2.0),
    (name: 'landscape', size: const Size(844, 360), dark: true, scale: 2.0),
  ]) {
    testWidgets(
      'Sheet fits the safe area and keeps cancel visible (${config.name})',
      (tester) async {
        await mount(
          tester,
          FakeGateway(),
          size: config.size,
          dark: config.dark,
          scale: config.scale,
        );
        await openMenu(tester);
        expect(find.text('更改封面图'), findsNothing);
        final cancel = find.byKey(const ValueKey('profile-edit-cancel'));
        expect(cancel.hitTestable(), findsOneWidget);
        expect(
          tester.getBottomRight(cancel).dy,
          lessThanOrEqualTo(config.size.height - 24),
        );
        await capture(tester, 'profile-edit-menu-${config.name}');
        await tester.tap(cancel);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('profile-edit-actions')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
    for (final action in [ProfileEditAction.avatar, ProfileEditAction.bio]) {
      testWidgets('Dedicated ${action.name} editor fits ${config.name}', (
        tester,
      ) async {
        final api = FakeGateway()..documents['GetMe']!['bio'] = '保持好奇，认真生活。';
        final store = await mount(
          tester,
          api,
          size: config.size,
          dark: config.dark,
          scale: config.scale,
        );
        await openEditor(tester, action);
        expect(find.text('保存资料'), findsNothing);
        expect(find.byKey(const ValueKey('profile-name')), findsNothing);
        if (action == ProfileEditAction.avatar) {
          final preview = tester.getSize(find.byType(ProfileAvatar));
          expect(preview.width, preview.height);
          expect(preview.width, greaterThan(0));
          for (final key in [
            'profile-avatar-gallery',
            'profile-avatar-system',
          ]) {
            final button = find.byKey(ValueKey(key));
            expect(button.hitTestable(), findsOneWidget);
            expect(
              tester.getBottomRight(button).dy,
              lessThanOrEqualTo(config.size.height - 24),
            );
          }
        } else {
          final field = find.byKey(const ValueKey('profile-bio'));
          expect(tester.widget<TextField>(field).controller!.text, store.bio);
          expect(tester.widget<TextField>(field).expands, isTrue);
          await tester.enterText(field, '只编辑草稿，返回不保存。');
        }
        await capture(tester, 'profile-editor-${action.name}-${config.name}');
        if (action == ProfileEditAction.bio) {
          addTearDown(tester.view.resetViewInsets);
          tester.view.viewInsets = FakeViewPadding(
            bottom: config.size.height < 400 ? 120 : 260,
          );
          await tester.pumpAndSettle();
          final save = find.byKey(const ValueKey('profile-save'));
          expect(save.hitTestable(), findsOneWidget);
          expect(
            tester.getBottomRight(save).dy,
            lessThanOrEqualTo(
              config.size.height - (config.size.height < 400 ? 120 : 260),
            ),
          );
          expect(
            find.byKey(const ValueKey('profile-bio')).hitTestable(),
            findsOneWidget,
          );
        }
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(ProfileEditor), findsNothing);
        expect(store.bio, '保持好奇，认真生活。');
        expect(api.calls, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
