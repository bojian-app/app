import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'api/bojian_api.dart';
import 'app_icons.dart';
import 'app_photo_picker.dart';
import 'app_qr_scan_effect.dart';
import 'design.dart';

/// Owns camera operations and stops capture before handing a QR to login logic.
class AppQRScanner extends StatefulWidget {
  const AppQRScanner({super.key, required this.onCode});
  final ValueChanged<String> onCode;
  @override
  State<AppQRScanner> createState() => _AppQRScannerState();
}

class _AppQRScannerState extends State<AppQRScanner>
    with WidgetsBindingObserver {
  final camera = MobileScannerController(
    autoStart: false,
    formats: const [BarcodeFormat.qrCode],
  );
  Future<void> _operations = Future.value();
  bool _delivered = false;
  bool _foreground = true;
  bool _selectingImage = false;
  String? _imageError;
  String? _pendingImageCode;
  Future<BarcodeCapture?>? _imageAnalysis;

  bool get _canRunCamera =>
      mounted &&
      _foreground &&
      !_delivered &&
      !_selectingImage &&
      _pendingImageCode == null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_syncCamera());
    });
  }

  Future<void> _syncCamera() {
    // Serialize native start/stop to avoid a late stop closing a restarted camera.
    _operations = _operations.then((_) async {
      try {
        if (_canRunCamera) {
          await camera.start();
          if (!_canRunCamera) await camera.stop();
        } else {
          await camera.stop();
        }
      } on MobileScannerException {
        // Camera failures are presented by MobileScanner's errorBuilder.
      }
      // Photo picker completion can arrive before the app resumes. Deliver only
      // after returning to the foreground, with camera operations completed.
      if (mounted &&
          _foreground &&
          !_selectingImage &&
          !_delivered &&
          _pendingImageCode != null) {
        final code = _pendingImageCode!;
        _pendingImageCode = null;
        _delivered = true;
        widget.onCode(code);
      }
    });
    return _operations;
  }

  Future<void> _capture(BarcodeCapture capture) async {
    if (_delivered ||
        !_foreground ||
        !mounted ||
        _selectingImage ||
        _pendingImageCode != null) {
      return;
    }
    final code = capture.barcodes
        .where(
          (code) =>
              code.format == BarcodeFormat.qrCode && code.rawValue != null,
        )
        .firstOrNull;
    if (code == null) return;
    _delivered = true;
    await _syncCamera();
    if (mounted && _foreground) {
      widget.onCode(code.rawValue!);
    } else if (mounted) {
      // If backgrounded during stop, require a fresh foreground scan.
      _delivered = false;
    }
  }

  Future<void> _pickImage() async {
    if (_delivered || _selectingImage || _pendingImageCode != null) return;
    setState(() {
      _selectingImage = true;
      _imageError = null;
    });
    try {
      await _syncCamera();
      if (!mounted) return;
      final image = await pickAppGalleryPhoto();
      if (!mounted || image == null) return;
      final analysis = camera.analyzeImage(
        image.path,
        formats: const [BarcodeFormat.qrCode],
      );
      _imageAnalysis = analysis;
      final capture = await analysis;
      if (!mounted) return;
      final codes = {
        for (final barcode in capture?.barcodes ?? <Barcode>[])
          if (barcode.format == BarcodeFormat.qrCode &&
              barcode.rawValue?.isNotEmpty == true)
            barcode.rawValue!,
      };
      if (codes.isEmpty) {
        _imageError = '未在图片中识别到二维码，请换一张清晰图片';
      } else if (codes.length > 1) {
        _imageError = '图片中有多个二维码，请选择只包含一个二维码的图片';
      } else {
        _pendingImageCode = codes.single;
      }
    } on ApiFailure catch (error) {
      if (mounted) _imageError = error.message;
    } catch (_) {
      if (mounted) _imageError = '无法识别这张图片，请换一张图片重试';
    } finally {
      _imageAnalysis = null;
      if (mounted) {
        setState(() => _selectingImage = false);
        await _syncCamera();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    unawaited(_syncCamera());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(
      _operations.then((_) async {
        // Let an in-flight native image analysis finish before disposing it.
        try {
          await _imageAnalysis;
        } catch (_) {}
        await camera.stop();
        await camera.dispose();
      }),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      _cameraView(context),
      const IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x99000000), Color(0x10000000), Color(0xCC000000)],
              stops: [0, .4, 1],
            ),
          ),
        ),
      ),
      IgnorePointer(
        child: ValueListenableBuilder<MobileScannerState>(
          valueListenable: camera,
          builder: (context, state, _) => AppQRScanEffect(
            color: context.colors.accent,
            enabled: state.isRunning && _canRunCamera,
          ),
        ),
      ),
      SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 420;
            return Stack(
              fit: StackFit.expand,
              children: [
                Align(
                  alignment: Alignment(0, compact ? 0 : .55),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 88 : 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ValueListenableBuilder<MobileScannerState>(
                          valueListenable: camera,
                          builder: (context, state, _) => state.error != null
                              ? const SizedBox.shrink()
                              : const Text(
                                  '对准博简官网登录二维码，自动扫描',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    height: 1.5,
                                    shadows: [Shadow(blurRadius: 8)],
                                  ),
                                ),
                        ),
                        if (_imageError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              _imageError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.5,
                                shadows: [Shadow(blurRadius: 8)],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: TextButton(
                    key: const ValueKey('app-qr-gallery'),
                    onPressed:
                        _selectingImage ||
                            _delivered ||
                            _pendingImageCode != null
                        ? null
                        : _pickImage,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white70,
                      padding: const EdgeInsets.all(8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: context.colors.surface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: _selectingImage
                                ? SizedBox.square(
                                    dimension: 22,
                                    child: CircularProgressIndicator(
                                      color: context.colors.accent,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : AppIcon(
                                    AppIcons.imageCache,
                                    color: context.colors.accent,
                                    size: 25,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _selectingImage ? '识别中…' : '相册',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ],
  );

  Widget _cameraView(BuildContext context) => MobileScanner(
    controller: camera,
    onDetect: (capture) => unawaited(_capture(capture)),
    errorBuilder: (context, error) => ColoredBox(
      color: Colors.black,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error.errorCode == MobileScannerErrorCode.permissionDenied
                    ? '未获得相机权限，请在系统设置中允许博简使用相机后重试'
                    : '相机暂不可用，请检查相机后重试',
                style: const TextStyle(color: Colors.white, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.accent,
                  side: BorderSide(color: context.colors.accent),
                ),
                onPressed: () => unawaited(_syncCamera()),
                child: const Text('重试相机'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
