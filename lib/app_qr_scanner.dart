import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
        if (mounted && _foreground && !_delivered) {
          await camera.start();
          if (!mounted || !_foreground || _delivered) await camera.stop();
        } else {
          await camera.stop();
        }
      } on MobileScannerException {
        // Camera failures are presented by MobileScanner's errorBuilder.
      }
    });
    return _operations;
  }

  Future<void> _capture(BarcodeCapture capture) async {
    if (_delivered || !_foreground || !mounted) return;
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
        await camera.stop();
        await camera.dispose();
      }),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MobileScanner(
    controller: camera,
    onDetect: (capture) => unawaited(_capture(capture)),
    errorBuilder: (context, error) => ColoredBox(
      color: context.colors.surface,
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
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
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
