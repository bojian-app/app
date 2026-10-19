import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/api/generated/auth.pb.dart' as auth;
import 'package:bojian_mobile/captcha_dialog.dart';
import 'package:bojian_mobile/app_store.dart';
import 'package:flutter/cupertino.dart';
import 'package:bojian_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

class _SmsGateway extends FakeGateway {
  _SmsGateway(
    this.master,
    this.piece, {
    this.deliveryStatus = '',
    this.failure,
  });

  final String master, piece, deliveryStatus;
  final ApiFailure? failure;
  Completer<ApiDocument>? pendingBind;
  Completer<ApiDocument>? pendingSMS;
  Completer<auth.CaptchaVerification>? pendingVerification;

  @override
  Future<auth.CaptchaVerification> verifyCaptcha(
    String id,
    int position,
    Map<String, String> headers,
  ) =>
      pendingVerification?.future ?? super.verifyCaptcha(id, position, headers);

  @override
  Future<CaptchaChallenge> createCaptcha(Map<String, String> headers) async {
    calls.add('CreateCaptcha');
    return CaptchaChallenge(
      id: 'sms-test',
      masterImageDataUrl: master,
      thumbImageDataUrl: piece,
      pieceY: 40,
      maxX: 276,
    );
  }

  @override
  Future<ApiDocument> call(
    String method, {
    Map<String, String> path = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    Map<String, String> headers = const {},
  }) async {
    if (method == 'PostMePhone' && pendingBind != null) {
      calls.add(method);
      return pendingBind!.future;
    }
    if (method == 'PostMePhoneSMSCodes') {
      calls.add(method);
      lastBody = body;
      lastHeaders = headers;
      if (pendingSMS != null) return pendingSMS!.future;
      if (failure != null) throw failure!;
      return ApiDocument({
        'retry_after_seconds': 60,
        'delivery_status': deliveryStatus,
      });
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

Future<String> _image(int width, int height) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return Uri.dataFromBytes(
    Uint8List.sublistView(bytes!),
    mimeType: 'image/png',
  ).toString();
}

Future<AppStore> _requestCode(
  WidgetTester tester,
  _SmsGateway gateway, {
  bool settleVerification = true,
}) async {
  gateway.documents['GetMe']!.remove('phone_masked');
  final store = await testStore(authenticated: true, api: gateway);
  await tester.pumpWidget(MyApp(nativeStartup: true, store: store));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('phone-binding-phone')),
    '13800138000',
  );
  await tester.ensureVisible(
    find.byKey(const ValueKey('phone-binding-request-code')),
  );
  await tester.tap(find.byKey(const ValueKey('phone-binding-request-code')));
  await tester.pump(const Duration(milliseconds: 350));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
  await tester.drag(
    find.byKey(const ValueKey('captcha-slider')),
    const Offset(60, 0),
  );
  if (settleVerification) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return store;
}

void main() {
  for (final state in ['', 'SUBMITTED', 'DELIVERED']) {
    testWidgets(
      'SMS $state result is a single inline message, without a toast',
      (tester) async {
        final images = await tester.runAsync(
          () async => (await _image(320, 180), await _image(44, 44)),
        );
        final gateway = _SmsGateway(
          images!.$1,
          images.$2,
          deliveryStatus: state,
        );
        await _requestCode(tester, gateway);
        final message = find.byKey(const ValueKey('phone-binding-status'));
        final expected = state == 'DELIVERED'
            ? '验证码已发送，请查看短信'
            : '发送请求已提交，请稍后查看短信';
        expect(find.text(expected), findsOneWidget);
        expect(
          tester.getTopLeft(message).dy,
          greaterThanOrEqualTo(
            tester
                .getBottomLeft(find.byKey(const ValueKey('phone-binding-code')))
                .dy,
          ),
        );
        expect(find.byType(SnackBar), findsNothing);
        expect(find.byType(CaptchaDialog), findsNothing);
        expect(
          gateway.calls.where((value) => value == 'PostMePhoneSMSCodes'),
          hasLength(1),
        );
        if (state != 'DELIVERED') {
          expect(find.text('验证码已发送，请查看短信'), findsNothing);
        }
        expect(gateway.lastBody?['purpose'], 'BIND_PHONE');
        expect(gateway.lastHeaders?['authorization'], 'Bearer test-access');
        expect(gateway.calls, isNot(contains('SendSMS')));
        await tester.enterText(
          find.byKey(const ValueKey('phone-binding-phone')),
          '13900139000',
        );
        await tester.pump();
        expect(message, findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'Known SMS delivery failure closes the puzzle and shows an inline error',
    (tester) async {
      final images = await tester.runAsync(
        () async => (await _image(320, 180), await _image(44, 44)),
      );
      final gateway = _SmsGateway(
        images!.$1,
        images.$2,
        failure: const ApiFailure('短信发送失败，请稍后重试', code: 'SMS_DELIVERY_FAILED'),
      );
      await _requestCode(tester, gateway);
      expect(find.byType(CaptchaDialog), findsNothing);
      final error = find.byKey(const ValueKey('phone-binding-error'));
      expect(find.text('短信发送失败，请稍后重试'), findsOneWidget);
      expect(
        tester.getTopLeft(error).dy,
        greaterThanOrEqualTo(
          tester
              .getBottomLeft(find.byKey(const ValueKey('phone-binding-code')))
              .dy,
        ),
      );
      expect(find.byKey(const ValueKey('phone-binding-status')), findsNothing);
      expect(find.text('验证码已发送，请查看短信'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('获取验证码'), findsOneWidget);
      expect(
        gateway.calls.where((value) => value == 'PostMePhoneSMSCodes'),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Binding failure preserves input and retry updates the same account',
    (tester) async {
      final images = await tester.runAsync(
        () async => (await _image(320, 180), await _image(44, 44)),
      );
      final api = _SmsGateway(images!.$1, images.$2);
      final store = await _requestCode(tester, api);
      final id = store.userID;
      final session = Map<String, dynamic>.of(store.session!);
      await tester.enterText(
        find.byKey(const ValueKey('phone-binding-code')),
        '123456',
      );
      api.failing = 'PostMePhone';
      await tester.tap(find.byKey(const ValueKey('phone-binding-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('服务器暂不可用'), findsOneWidget);
      expect(store.hasBoundPhone, isFalse);
      expect(
        tester
            .widget<CupertinoTextField>(
              find.byKey(const ValueKey('phone-binding-code')),
            )
            .controller!
            .text,
        '123456',
      );
      api.failing = null;
      await tester.tap(find.byKey(const ValueKey('phone-binding-confirm')));
      await tester.pumpAndSettle();
      expect(store.phoneMasked, '138****8000');
      expect(store.userID, id);
      expect(store.session, session);
      expect(find.byKey(const ValueKey('phone-binding-dialog')), findsNothing);
      expect(api.calls.where((m) => m == 'PostMePhone'), hasLength(2));
      await store.load('profile');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('phone-binding-dialog')), findsNothing);
    },
  );

  testWidgets(
    'Changing phone requires a fresh code and pending binding cannot repeat',
    (tester) async {
      final images = await tester.runAsync(
        () async => (await _image(320, 180), await _image(44, 44)),
      );
      final api = _SmsGateway(images!.$1, images.$2);
      final store = await _requestCode(tester, api);
      await tester.enterText(
        find.byKey(const ValueKey('phone-binding-phone')),
        '13900139000',
      );
      await tester.enterText(
        find.byKey(const ValueKey('phone-binding-code')),
        '123456',
      );
      await tester.tap(find.byKey(const ValueKey('phone-binding-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('请先获取当前手机号的验证码'), findsOneWidget);
      expect(api.calls, isNot(contains('PostMePhone')));
      await tester.enterText(
        find.byKey(const ValueKey('phone-binding-phone')),
        '13800138000',
      );
      api.pendingBind = Completer<ApiDocument>();
      await tester.tap(find.byKey(const ValueKey('phone-binding-confirm')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('phone-binding-confirm')));
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(api.calls.where((m) => m == 'PostMePhone'), hasLength(1));
      expect(
        find.byKey(const ValueKey('phone-binding-dialog')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<CupertinoDialogAction>(
              find.byKey(const ValueKey('phone-binding-skip')),
            )
            .onPressed,
        isNull,
      );
      api.pendingBind!.complete(ApiDocument({'phone_masked': '138****8000'}));
      await tester.pumpAndSettle();
      expect(store.hasBoundPhone, isTrue);
      expect(find.byKey(const ValueKey('phone-binding-dialog')), findsNothing);
    },
  );
  testWidgets(
    'Leaving the account during captcha verification cannot send binding SMS',
    (tester) async {
      final images = await tester.runAsync(
        () async => (await _image(320, 180), await _image(44, 44)),
      );
      final api = _SmsGateway(images!.$1, images.$2)
        ..pendingVerification = Completer<auth.CaptchaVerification>();
      final store = await _requestCode(tester, api, settleVerification: false);
      await store.endSession(remote: false);
      api.pendingVerification!.complete(
        auth.CaptchaVerification(captchaToken: 'late-proof'),
      );
      await tester.pumpAndSettle();
      expect(api.calls, isNot(contains('PostMePhoneSMSCodes')));
      expect(find.byKey(const ValueKey('auth-wechat')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Late SMS result cannot pop the signed out home route', (
    tester,
  ) async {
    final images = await tester.runAsync(
      () async => (await _image(320, 180), await _image(44, 44)),
    );
    final api = _SmsGateway(images!.$1, images.$2)
      ..pendingSMS = Completer<ApiDocument>();
    final store = await _requestCode(tester, api, settleVerification: false);
    expect(api.calls, contains('PostMePhoneSMSCodes'));
    await store.endSession(remote: false);
    api.pendingSMS!.complete(
      ApiDocument({'retry_after_seconds': 60, 'delivery_status': 'SUBMITTED'}),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('auth-wechat')), findsOneWidget);
    expect(store.phoneMasked, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
