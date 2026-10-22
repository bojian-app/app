import 'dart:async';

import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:bojian_mobile/api/bojian_api.dart';
import 'package:bojian_mobile/app_qr_login_page.dart';
import 'package:bojian_mobile/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';
import 'app_qr_login_test.dart' show QRGateway, qrContent, qrResponse;

void main() {
  for (final expiry in [
    'scan response',
    'scan error',
    'confirm error',
    'timer',
  ]) {
    testWidgets('Expiry resumes camera without an expired page: $expiry', (
      tester,
    ) async {
      final previous = MobileScannerPlatform.instance;
      final camera = CameraPlatformFake();
      MobileScannerPlatform.instance = camera;
      addTearDown(() => MobileScannerPlatform.instance = previous);
      addTearDown(camera.captures.close);
      final api = QRGateway()
        ..failure = const ApiFailure('二维码已过期', code: 'APP_QR_EXPIRED');
      if (expiry == 'scan error' || expiry == 'confirm error') {
        api.failing = expiry == 'scan error'
            ? 'PostMeAppQRSessionsSessionScan'
            : 'PostMeAppQRSessionsSessionConfirm';
      } else {
        api.scanResult = Completer<ApiDocument>()
          ..complete(
            ApiDocument(
              qrResponse()
                ..['created_at'] = DateTime.now()
                    .subtract(const Duration(minutes: 3))
                    .toUtc()
                    .toIso8601String()
                ..['expires_at'] = DateTime.now()
                    .add(Duration(seconds: expiry == 'timer' ? 1 : -1))
                    .toUtc()
                    .toIso8601String(),
            ),
          );
      }
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(MaterialApp(home: AppQRLoginPage(store: store)));
      await tester.pumpAndSettle();
      void capture() => camera.captures.add(
        BarcodeCapture(
          barcodes: [
            Barcode(format: BarcodeFormat.qrCode, rawValue: qrContent),
          ],
        ),
      );
      capture();
      await tester.pumpAndSettle();
      if (expiry == 'confirm error') {
        await tester.tap(find.byKey(const ValueKey('app-qr-confirm')));
        await tester.pumpAndSettle();
      } else if (expiry == 'timer') {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 1100)),
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
      }
      expect(find.text('二维码已过期'), findsNothing);
      expect(find.text('请扫描新的登录二维码'), findsOneWidget);
      expect(find.byType(MobileScanner), findsOneWidget);
      expect(camera.starts, 2);
      expect(
        api.calls.where((s) => s.endsWith('SessionConfirm')),
        hasLength(expiry == 'confirm error' ? 1 : 0),
      );
      api.failing = null;
      api.scanResult = null;
      capture();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('app-qr-confirm')), findsOneWidget);
      expect(find.byType(MobileScanner), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  for (final scenario in [
    'already confirmed',
    'retry',
    'close confirmation',
    'leave before response',
  ]) {
    testWidgets('Success closes only the scanner: $scenario', (tester) async {
      final api = QRGateway();
      if (scenario == 'already confirmed' ||
          scenario == 'leave before response') {
        api.scanResult = Completer<ApiDocument>();
      } else if (scenario == 'retry') {
        api.failing = 'PostMeAppQRSessionsSessionConfirm';
      }
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => AppQRLoginPage(
                      store: store,
                      scannerBuilder: (context, onCode) => TextButton(
                        onPressed: () => onCode(qrContent),
                        child: const Text('测试扫描'),
                      ),
                    ),
                  ),
                ),
                child: const Text('来源页面'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('来源页面'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('测试扫描'));
      await tester.pump();
      if (scenario == 'retry') {
        await tester.pumpAndSettle();
        await tester.tap(find.text('同意'));
        await tester.pumpAndSettle();
        expect(find.byType(AppQRLoginPage), findsOneWidget);
        expect(find.text('网络不可用'), findsOneWidget);
        api.failing = null;
        await tester.tap(find.text('同意'));
      } else if (scenario == 'close confirmation') {
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('app-qr-close')));
      } else if (scenario == 'already confirmed') {
        api.scanResult!.complete(ApiDocument(qrResponse('CONFIRMED')));
      } else {
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        api.scanResult!.complete(ApiDocument(qrResponse()));
      }
      await tester.pumpAndSettle();
      expect(find.byType(AppQRLoginPage), findsNothing);
      expect(find.text('来源页面'), findsOneWidget);
      if (scenario == 'close confirmation') {
        expect(
          api.calls.where((s) => s.endsWith('SessionCancel')),
          hasLength(1),
        );
        expect(api.calls.where((s) => s.endsWith('SessionConfirm')), isEmpty);
      } else if (scenario != 'leave before response') {
        expect(api.calls.where((s) => s.endsWith('SessionCancel')), isEmpty);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Camera stops in background and when QR opens confirmation', (
    tester,
  ) async {
    final previous = MobileScannerPlatform.instance;
    final camera = CameraPlatformFake();
    MobileScannerPlatform.instance = camera;
    addTearDown(() => MobileScannerPlatform.instance = previous);
    addTearDown(camera.captures.close);
    final api = QRGateway();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    await tester.pumpWidget(MaterialApp(home: AppQRLoginPage(store: store)));
    await tester.pumpAndSettle();
    expect(camera.starts, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(camera.stops, greaterThanOrEqualTo(1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(camera.starts, 2);
    camera.captures.add(
      BarcodeCapture(
        barcodes: [Barcode(format: BarcodeFormat.qrCode, rawValue: qrContent)],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('使用你的博简账号\n登录官网'), findsOneWidget);
    expect(find.byType(MobileScanner), findsNothing);
    await tester.pumpAndSettle();
    expect(camera.stops, greaterThanOrEqualTo(2));
    expect(api.calls, isNot(contains('PostMeAppQRSessionsSessionConfirm')));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'Denied camera permission shows a retry without sending login requests',
    (tester) async {
      final previous = MobileScannerPlatform.instance;
      final camera = CameraPlatformFake()..denied = true;
      MobileScannerPlatform.instance = camera;
      addTearDown(() => MobileScannerPlatform.instance = previous);
      addTearDown(camera.captures.close);
      final api = QRGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await tester.pumpWidget(MaterialApp(home: AppQRLoginPage(store: store)));
      await tester.pumpAndSettle();
      expect(find.textContaining('未获得相机权限'), findsOneWidget);
      expect(find.text('重试相机'), findsOneWidget);
      expect(api.calls.where((s) => s.startsWith('PostMeAppQR')), isEmpty);
      camera.denied = false;
      await tester.tap(find.text('重试相机'));
      await tester.pumpAndSettle();
      expect(camera.starts, 2);
      expect(find.textContaining('未获得相机权限'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  for (final dark in [false, true]) {
    for (final scenario in [
      (1.0, const Size(390, 640)),
      (1.0, const Size(390, 844)),
      (2.0, const Size(320, 640)),
      (2.0, const Size(844, 360)),
    ]) {
      final (scale, size) = scenario;
      testWidgets(
        'Scan, confirm and cancel are explicit, dark=$dark text=$scale size=$size',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final api = QRGateway();
          final store = await testStore(authenticated: true, api: api);
          addTearDown(store.dispose);
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? appDarkTheme : appTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => AppQRLoginPage(
                          store: store,
                          scannerBuilder: (context, onCode) => Center(
                            child: FilledButton(
                              onPressed: () => onCode(qrContent),
                              child: const Text('测试扫描'),
                            ),
                          ),
                        ),
                      ),
                    ),
                    child: const Text('打开扫码'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('打开扫码'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('测试扫描'));
          await tester.pumpAndSettle();
          expect(find.text('使用你的博简账号\n登录官网'), findsOneWidget);
          expect(find.text('Windows · Chrome'), findsNothing);
          expect(find.text('https://bojian.kelance.cn'), findsNothing);
          expect(
            api.calls,
            isNot(contains('PostMeAppQRSessionsSessionConfirm')),
          );
          final confirm = find.byKey(const ValueKey('app-qr-confirm'));
          if (scale == 1 && size.height == 844) {
            final button = tester.getRect(confirm);
            expect(button.top, greaterThan(size.height - 180));
            expect(
              tester
                  .getRect(find.byKey(const ValueKey('app-qr-cancel')))
                  .bottom,
              lessThanOrEqualTo(size.height - 24),
            );
            expect(find.byKey(const ValueKey('app-qr-close')), findsOneWidget);
            expect(find.text('当前博简账号'), findsOneWidget);
          }
          await tester.ensureVisible(confirm);
          await tester.pumpAndSettle();
          await tester.tap(confirm);
          await tester.pumpAndSettle();
          expect(find.byType(AppQRLoginPage), findsNothing);
          expect(find.text('打开扫码'), findsOneWidget);
          expect(api.calls.where((s) => s.endsWith('SessionCancel')), isEmpty);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('打开扫码'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('测试扫描'));
          await tester.pumpAndSettle();
          final cancel = find.byKey(const ValueKey('app-qr-cancel'));
          await tester.ensureVisible(cancel);
          await tester.pumpAndSettle();
          await tester.tap(cancel);
          await tester.pumpAndSettle();
          expect(find.text('已取消登录'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}

class CameraPlatformFake extends MobileScannerPlatform {
  final captures = StreamController<BarcodeCapture>.broadcast();
  bool denied = false;
  int starts = 0, stops = 0, disposals = 0;
  @override
  Stream<BarcodeCapture?> get barcodesStream => captures.stream;
  @override
  Stream<TorchState> get torchStateStream =>
      Stream.value(TorchState.unavailable);
  @override
  Stream<double> get zoomScaleStateStream => Stream.value(1);
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async {
    starts++;
    if (denied) {
      throw const MobileScannerException(
        errorCode: MobileScannerErrorCode.permissionDenied,
      );
    }
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.unavailable,
      size: Size(200, 200),
      numberOfCameras: 1,
    );
  }

  @override
  Widget buildCameraView() => const ColoredBox(color: Colors.black);
  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }
}
