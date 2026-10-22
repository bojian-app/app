import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/developer_verification_controller.dart';
import 'package:bojian_mobile/identity_verification_pages.dart';
import 'package:bojian_mobile/identity_face_sdk.dart';
import 'package:bojian_mobile/identity_verification_service.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

const ocrToken = 'ooooooooooooooooooooooooooooooooooooooooooo';
const faceID = 'fffffffffffffffffffffffffffffffffffffffffff';
Map<String, dynamic> recognized() => {
  'ocr_token': ocrToken,
  'name': '测试姓名',
  'holder_id_masked': '110***********002X',
  'valid_from': '2020-01-01',
  'valid_until': '2099-12-31',
  'long_term': false,
  'expires_at': DateTime.now()
      .add(const Duration(minutes: 15))
      .toIso8601String(),
};
Map<String, dynamic> face([String status = 'PENDING']) => {
  'session_id': faceID,
  'status': status,
  'expires_at': DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
  if (status == 'PENDING') ...{
    'native_token': 'provider-token',
    'plan_id': '27030',
    'match_source': 0,
    'flow': 'APP',
  },
  if (status == 'VERIFIED') 'verification_id': 123,
};
FakeGateway gateway() => FakeGateway()
  ..documents['GetMeIdentityVerificationCapabilities'] = {
    'available': true,
    'provider': 'BAIDU',
    'flow': 'APP',
    'consent_version': identityConsentVersion,
  }
  ..documents['PostMeIdentityVerificationOCR'] = recognized()
  ..documents['PostMeIdentityVerificationFaceSessions'] = face()
  ..documents['PostMeIdentityVerificationFaceSessionsSessionRefresh'] = face();

Future<DeveloperVerificationController> prepared(
  FakeGateway api, {
  IdentityFaceSdk? sdk,
}) async {
  final store = await testStore(authenticated: true, api: api);
  final controller = DeveloperVerificationController(
    store: store,
    sdk: sdk ?? FakeNativeSdk(),
    pickPhoto: () async => XFile.fromData(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAEUlEQVR4nGNwmHAAjhiI4wAAglIZAaTN9MkAAAAASUVORK5CYII=',
      ),
      name: 'id.png',
    ),
  );
  addTearDown(store.dispose);
  addTearDown(controller.dispose);
  await controller.selectPhoto(VerificationPhotoSide.portrait);
  await controller.selectPhoto(VerificationPhotoSide.emblem);
  controller.setAgreed(true);
  return controller;
}

class FakeNativeSdk extends IdentityFaceSdk {
  int calls = 0;
  @override
  Future<void> checkAvailable() async {}
  @override
  Future<bool> verify(
    IdentityFaceSession session, {
    required int accentColor,
    required bool dark,
  }) async {
    calls++;
    return true;
  }
}

class DelayedOCRGateway extends FakeGateway {
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    final response = await super.call(
      method,
      path: path,
      query: query,
      body: body,
      headers: headers,
    );
    if (method == 'PostMeIdentityVerificationOCR') {
      started.complete();
      await release.future;
    }
    return response;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Unavailable backend prevents sending document photos', () async {
    final api = gateway()
      ..documents['GetMeIdentityVerificationCapabilities'] = {
        'available': false,
      };
    final controller = await prepared(api);
    expect(await controller.recognize(), false);
    expect(controller.error, contains('暂不可用'));
    expect(api.calls, isNot(contains('PostMeIdentityVerificationOCR')));
    expect(controller.identity, isNull);
  });

  test(
    'Recognition precedes face creation and only opaque OCR proof is submitted',
    () async {
      final api = gateway();
      final controller = await prepared(api);
      expect(await controller.startFace(), false);
      expect(await controller.recognize(), true);
      expect(controller.identity!.name, '测试姓名');
      expect(api.lastBody!['consent_version'], identityConsentVersion);
      expect(api.lastBody!['front_image'], isA<String>());
      expect(
        api.calls,
        isNot(contains('PostMeIdentityVerificationFaceSessions')),
      );
      expect(await controller.startFace(), true);
      expect(api.lastBody, {
        'ocr_token': ocrToken,
        'identity_confirmed': true,
        'consent_version': identityConsentVersion,
      });
      await controller.refreshFace();
      expect(controller.faceSession!.status, IdentityFaceStatus.pending);
      api.documents['PostMeIdentityVerificationFaceSessionsSessionRefresh'] =
          face('VERIFIED');
      await controller.refreshFace();
      expect(controller.faceSession!.status, IdentityFaceStatus.verified);
      expect(controller.faceSession!.verificationID, 123);
      controller.setAgreed(false);
      expect(controller.identity, isNull);
      expect(controller.faceSession, isNull);
    },
  );

  test('Signing out during OCR discards private recognition data', () async {
    final api = DelayedOCRGateway()..documents.addAll(gateway().documents);
    final controller = await prepared(api);
    final result = controller.recognize();
    await api.started.future;
    expect(controller.busy, true);
    await controller.store.endSession(remote: false);
    api.release.complete();
    expect(await result, false);
    expect(controller.identity, isNull);
    expect(controller.photo(VerificationPhotoSide.portrait), isNull);
    expect(controller.faceSession, isNull);
  });

  test('Expired proofs and invalid native parameters are rejected', () async {
    final api = gateway();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    final expired = RecognizedIdentity.fromMap({
      ...recognized(),
      'expires_at': '2000-01-01T00:00:00Z',
    });
    await expectLater(
      IdentityVerificationService(store).start(expired),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      api.calls,
      isNot(contains('PostMeIdentityVerificationFaceSessions')),
    );
    for (final invalid in <Map<String, dynamic>>[
      {'flow': 'H5'},
      {'match_source': 2},
      {'native_token': ''},
      {'plan_id': 'other'},
      {'native_token': null},
    ]) {
      expect(
        () => IdentityFaceSession.fromMap({...face(), ...invalid}),
        throwsA(isA<ApiFailure>()),
      );
    }
    expect(
      () => IdentityFaceSession.fromMap({
        ...face('VERIFIED'),
        'verification_id': 0,
      }),
      throwsA(isA<ApiFailure>()),
    );
  });

  for (final config in [
    (false, 1.0),
    (false, 1.6),
    (false, 2.0),
    (true, 1.0),
    (true, 1.6),
    (true, 2.0),
  ]) {
    final (dark, scale) = config;
    testWidgets(
      'Separate native consent and server-confirmed result, dark=$dark, text=$scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = gateway();
        final native = FakeNativeSdk();
        final controller = await tester.runAsync(() async {
          final c = await prepared(api, sdk: native);
          expect(await c.recognize(), true);
          return c;
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? appDarkTheme : appTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: IdentityConfirmationPage(controller: controller!),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('测试姓名'), findsOneWidget);
        final start = find.byKey(const ValueKey('identity-start-face'));
        await tester.scrollUntilVisible(start, 150);
        expect(tester.widget<FilledButton>(start).onPressed, isNull);
        final consent = find.byKey(const ValueKey('identity-face-consent'));
        await tester.scrollUntilVisible(consent, -100);
        final checkbox = find.descendant(
          of: consent,
          matching: find.byType(Checkbox),
        );
        await tester.ensureVisible(checkbox);
        await tester.pumpAndSettle();
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.byKey(const ValueKey('identity-face-consent-text')),
            matching: find.byType(RichText),
          ),
        );
        final firstCharacter = paragraph
            .getBoxesForSelection(
              const TextSelection(baseOffset: 0, extentOffset: 1),
              boxHeightStyle: ui.BoxHeightStyle.tight,
            )
            .first
            .toRect();
        final firstLineCenter = paragraph
            .localToGlobal(firstCharacter.center)
            .dy;
        expect(tester.getCenter(checkbox).dy, closeTo(firstLineCenter, 1));
        await tester.tap(checkbox);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(start, 150);
        await tester.ensureVisible(start);
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
        await tester.tap(start);
        await tester.runAsync(() async {});
        await tester.pumpAndSettle();
        expect(controller.error, isNull);
        expect(controller.faceSession, isNotNull, reason: api.calls.join(','));
        expect(find.byType(IdentityFacePage), findsOneWidget);
        await tester.pump();
        expect(native.calls, 1);
        expect(find.text('完成本人活体核验'), findsOneWidget);
        expect(find.text('实名认证已通过'), findsNothing);
        final refresh = find.byKey(const ValueKey('identity-refresh-face'));
        await tester.ensureVisible(refresh);
        await tester.tap(refresh);
        await tester.runAsync(() async {});
        await tester.pumpAndSettle();
        expect(find.text('实名认证已通过'), findsNothing);
        api.documents['PostMeIdentityVerificationFaceSessionsSessionRefresh'] =
            face('VERIFIED');
        await tester.tap(refresh);
        await tester.runAsync(() async {});
        await tester.pumpAndSettle();
        expect(find.text('实名认证已通过'), findsOneWidget);
        expect(controller.store.identityVerified, true);
        expect(controller.store.canApplyDeveloperVerification, false);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
