import 'dart:async';

import 'package:bojian_mobile/app_qr_login_page.dart';
import 'package:bojian_mobile/app_qr_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'app_qr_login_page_test.dart' show CameraPlatformFake;
import 'app_qr_login_test.dart' show QRGateway, qrContent;
import 'support/fake_gateway.dart';

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

  Future<void> mount(WidgetTester tester, {Widget? page}) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      MaterialApp(
        home: page ?? Scaffold(body: AppQRScanner(onCode: delivered.add)),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
  }

  Future<void> openGallery(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('app-qr-gallery')));
    await tester.pump();
    expect(gallery.requests, 1);
  }

  testWidgets(
    'Gallery works without camera permission and requires confirmation',
    (tester) async {
      camera.denied = true;
      final api = QRGateway();
      final store = await testStore(authenticated: true, api: api);
      addTearDown(store.dispose);
      await mount(tester, page: AppQRLoginPage(store: store));
      expect(find.textContaining('未获得相机权限'), findsOneWidget);
      await openGallery(tester);
      gallery.result.complete(XFile('/test/qr.png'));
      camera.result.complete(capture([qrContent]));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('app-qr-confirm')), findsOneWidget);
      expect(api.calls.where((s) => s.endsWith('SessionScan')), hasLength(1));
      expect(api.calls.where((s) => s.endsWith('SessionConfirm')), isEmpty);
      expect(camera.analyses, 1);
      expect(tester.takeException(), isNull);
    },
  );

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
