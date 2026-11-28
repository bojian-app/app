import 'dart:async';

import 'package:bojian_mobile/app_qr_scanner.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/discovery.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'support/fake_gateway.dart';

const qrContent = 'https://bojian.kelance.cn?invite_code=A2B3C4D5';

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

BarcodeCapture capture(List<String> codes) => BarcodeCapture(
  barcodes: [
    for (final code in codes)
      Barcode(format: BarcodeFormat.qrCode, rawValue: code),
  ],
);

class GalleryFake extends ImagePickerPlatform {
  late final result = Completer<XFile?>();
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

class ImageScannerFake extends CameraPlatformFake {
  late final result = Completer<BarcodeCapture?>();
  int analyses = 0;

  @override
  Future<BarcodeCapture?> analyzeImage(
    String path, {
    List<BarcodeFormat> formats = const [],
  }) {
    expect(path, '/test/qr.png');
    expect(formats, [BarcodeFormat.qrCode]);
    analyses++;
    return result.future;
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    // Keep flow tests deterministic while the production scan band animates.
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(binding.platformDispatcher.clearAccessibilityFeaturesTestValue);
  });
  late GalleryFake gallery;
  late ImageScannerFake camera;
  final delivered = <String>[];

  setUp(() {
    final oldGallery = ImagePickerPlatform.instance;
    final oldCamera = MobileScannerPlatform.instance;
    gallery = GalleryFake();
    camera = ImageScannerFake();
    ImagePickerPlatform.instance = gallery;
    MobileScannerPlatform.instance = camera;
    delivered.clear();
    addTearDown(() {
      ImagePickerPlatform.instance = oldGallery;
      MobileScannerPlatform.instance = oldCamera;
    });
    addTearDown(camera.captures.close);
  });

  Future<void> mount(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AppQRScanner(onCode: delivered.add)),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
  }

  testWidgets('Discovery scan binds an invitation once and shows the result', (
    tester,
  ) async {
    final api = FakeGateway();
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(body: DiscoveryPage(store: store)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('discovery-scan')));
    await tester.pumpAndSettle();
    expect(find.byType(AppQRScanner), findsOneWidget);
    camera.captures.add(capture([qrContent]));
    camera.captures.add(capture([qrContent]));
    await tester.pumpAndSettle();
    expect(api.calls.where((m) => m == 'PostInvitationsBind'), hasLength(1));
    expect(api.lastMutationBody, {'invite_code': 'A2B3C4D5'});
    expect(
      find.byKey(const ValueKey('invite-reward-animation')),
      findsOneWidget,
    );
  });

  Future<void> openGallery(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('app-qr-gallery')));
    await tester.pump();
    expect(gallery.requests, 1);
  }

  testWidgets('Gallery works without camera permission', (tester) async {
    camera.denied = true;
    await mount(tester);
    expect(find.textContaining('未获得相机权限'), findsOneWidget);
    await openGallery(tester);
    gallery.result.complete(XFile('/test/qr.png'));
    camera.result.complete(capture([qrContent]));
    await tester.pumpAndSettle();
    expect(delivered, [qrContent]);
    expect(camera.analyses, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Cancel restores camera and ignores live captures during picker',
    (tester) async {
      await mount(tester);
      await openGallery(tester);
      expect(camera.stops, greaterThan(0));
      camera.captures.add(capture([qrContent]));
      await tester.pump();
      expect(delivered, isEmpty);
      gallery.result.complete(null);
      await tester.pumpAndSettle();
      expect(camera.starts, 2);
      expect(camera.analyses, 0);
      camera.captures.add(capture([qrContent]));
      await tester.pumpAndSettle();
      expect(delivered, [qrContent]);
    },
  );

  for (final failure in ['empty', 'multiple', 'decode', 'permission']) {
    testWidgets('Gallery $failure failure leaves camera usable', (
      tester,
    ) async {
      await mount(tester);
      await openGallery(tester);
      if (failure == 'permission') {
        gallery.result.completeError(
          PlatformException(code: 'photo_access_denied'),
        );
      } else {
        gallery.result.complete(XFile('/test/qr.png'));
        await tester.pump();
        if (failure == 'decode') {
          camera.result.completeError(Exception('invalid image'));
        } else {
          camera.result.complete(
            capture(failure == 'empty' ? [] : [qrContent, 'other-code']),
          );
        }
      }
      await tester.pumpAndSettle();
      expect(delivered, isEmpty);
      expect(camera.starts, 2);
      expect(
        find.textContaining(switch (failure) {
          'empty' => '未在图片中识别到二维码',
          'multiple' => '图片中有多个二维码',
          'decode' => '无法识别这张图片',
          _ => '无法选择照片',
        }),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Photo result waits for foreground and is delivered only once', (
    tester,
  ) async {
    await mount(tester);
    await openGallery(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    gallery.result.complete(XFile('/test/qr.png'));
    camera.result.complete(capture([qrContent, qrContent]));
    await tester.pumpAndSettle();
    expect(delivered, isEmpty);
    expect(camera.starts, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(delivered, [qrContent]);
    expect(camera.starts, 1);
    camera.captures.add(capture([qrContent]));
    await tester.pumpAndSettle();
    expect(delivered, [qrContent]);
  });

  testWidgets(
    'Leaving during analysis ignores result and disposes afterwards',
    (tester) async {
      await mount(tester);
      await openGallery(tester);
      gallery.result.complete(XFile('/test/qr.png'));
      await tester.pump();
      expect(camera.analyses, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(camera.disposals, 0);
      camera.result.complete(capture([qrContent]));
      await tester.pumpAndSettle();
      expect(delivered, isEmpty);
      expect(camera.disposals, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
