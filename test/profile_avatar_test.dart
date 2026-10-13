import 'dart:ui' as ui;

import 'package:bojian_mobile/account_pages.dart';
import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/profile_avatar.dart';
import 'package:bojian_mobile/resume_photo_crop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'System avatar assignment is stable and generated images are square',
    () async {
      expect(assignedAvatar('account-42'), assignedAvatar('account-42'));
      for (var i = 0; i < systemAvatarNames.length; i++) {
        final file = await createSystemAvatarFile(i);
        try {
          expect(
            storedSystemAvatar(
              'https://cdn.example.com/${file.name}?token=test',
            ),
            i,
          );
          final codec = await ui.instantiateImageCodec(
            await file.readAsBytes(),
          );
          final image = (await codec.getNextFrame()).image;
          expect(image.width, 512);
          expect(image.height, 512);
          image.dispose();
          codec.dispose();
        } finally {
          await discardSystemAvatarFile(file);
        }
      }
      expect(storedSystemAvatar('https://cdn.example.com/upload.png'), isNull);
    },
  );

  test(
    'Avatar uploads are completed before committing and update the real URL',
    () async {
      final api = FakeGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      api.documents['PostMeAvatarUploads'] = {'id': 19};
      api.documents['PostMeAvatarCommit'] = {
        'avatar_url': 'https://example.com/avatar.png',
      };
      final file = await createSystemAvatarFile(4);
      addTearDown(() => discardSystemAvatarFile(file));
      await uploadProfileAvatar(
        store,
        file,
        upload: (authorization, source, mime) async {
          expect(authorization['id'], 19);
          expect(mime, 'image/png');
          expect(await source.length(), greaterThan(0));
        },
      );
      expect(api.calls.where((method) => method.startsWith('Post')), [
        'PostMeAvatarUploads',
        'PostFilesUploadsIdComplete',
        'PostMeAvatarCommit',
      ]);
      expect(api.lastBody?['file_id'], 19);
      expect(store.avatarURL, 'https://example.com/avatar.png');
      await store.endSession(remote: false);
      expect(store.avatarURL, isEmpty);
    },
  );

  test(
    'Failed completion and session changes cannot replace the current avatar',
    () async {
      final api = FakeGateway()..failing = 'PostFilesUploadsIdComplete';
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      store.avatarURL = 'https://example.com/original.png';
      api.documents['PostMeAvatarUploads'] = {'id': 19};
      final file = await createSystemAvatarFile(0);
      addTearDown(() => discardSystemAvatarFile(file));
      await expectLater(
        uploadProfileAvatar(store, file, upload: (_, _, _) async {}),
        throwsA(isA<ApiFailure>()),
      );
      expect(store.avatarURL, 'https://example.com/original.png');
      expect(api.calls, isNot(contains('PostMeAvatarCommit')));
      api.calls.clear();
      api.failing = null;
      await expectLater(
        uploadProfileAvatar(
          store,
          file,
          upload: (_, _, _) async {
            store.epoch++;
          },
        ),
        throwsA(isA<ApiFailure>()),
      );
      expect(api.calls.where((method) => method.startsWith('Post')), [
        'PostMeAvatarUploads',
      ]);
    },
  );

  test('Avatar square crop does not change resume portrait proportions', () {
    const size = Size(800, 1200);
    final avatar = initialResumePhotoCrop(size, aspectRatio: 1);
    expect(avatar.width, avatar.height);
    final moved = constrainResumePhotoCrop(
      avatar.shift(const Offset(900, 900)),
      size,
      aspectRatio: 1,
    );
    expect(moved.right, lessThanOrEqualTo(size.width));
    expect(moved.bottom, lessThanOrEqualTo(size.height));
    final resume = initialResumePhotoCrop(size);
    expect(resume.width / resume.height, closeTo(5 / 6, .001));
  });

  testWidgets(
    'System choice previews locally, cancellation preserves the stored avatar',
    (tester) async {
      final api = FakeGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: ProfileEditor(store: store),
        ),
      );
      await tester.tap(find.text('更换头像'));
      await tester.pumpAndSettle();
      expect(find.text('上传自己的头像'), findsOneWidget);
      expect(find.byKey(const ValueKey('system-avatar-7')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('system-avatar-4')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).variant,
        4,
      );
      expect(api.calls.where((method) => method.startsWith('Post')), isEmpty);
      await tester.tap(find.text('更换头像'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).variant,
        4,
      );
      expect(store.avatarURL, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Avatar picker scrolls in landscape without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(844, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = await testStore(authenticated: true);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: ProfileEditor(store: store),
      ),
    );
    await tester.tap(find.text('更换头像'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('上传自己的头像'));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Editor keeps save above keyboard and saves profile before returning',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final api = FakeGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ProfileEditor(store: store),
                  ),
                ),
                child: const Text('打开编辑'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开编辑'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('profile-name')));
      await tester.enterText(
        find.byKey(const ValueKey('profile-name')),
        '新的昵称',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      final save = find.byKey(const ValueKey('profile-save'));
      expect(tester.getBottomRight(save).dy, lessThanOrEqualTo(844 - 260));
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(api.calls, contains('PatchMe'));
      expect(store.name, '新的昵称');
      expect(find.text('打开编辑'), findsOneWidget);
      expect(find.byType(ProfileEditor), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
