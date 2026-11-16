import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// What the device's default font can render. Theme fonts on Android often
/// ship a single Regular file registered for every weight, so bold text is
/// synthesized and its weight jumps mid-line. Such bold text falls back to the
/// bundled resume font while regular text keeps following the phone.
class ResumeSystemFonts {
  static const _channel = MethodChannel('cn.kelance.bojian/system_fonts');

  /// Whether bold Chinese text in the system font uses a designed bold face.
  static bool hasRealBold = true;

  static Future<void> refresh() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      hasRealBold =
          await _channel
              .invokeMethod<bool>('hasRealCjkBold')
              .timeout(const Duration(seconds: 2)) ??
          true;
    } catch (_) {
      hasRealBold = true;
    }
  }

  /// Whether text of [weight] drawn in the system font must use the bundled
  /// bold face instead.
  static bool needsBundledBold(int weight) => !hasRealBold && weight >= 600;
}

/// Invalidates self-painted previews when device fonts change. Some Android
/// themes omit fontsChange, so returning from the background also invalidates.
class ResumeSystemFontObserver with WidgetsBindingObserver {
  ResumeSystemFontObserver(this.onChanged) {
    PaintingBinding.instance.systemFonts.addListener(_schedule);
    WidgetsBinding.instance.addObserver(this);
  }

  final VoidCallback onChanged;
  bool _disposed = false, _scheduled = false, _backgrounded = false;
  static Future<void>? _refreshing;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _backgrounded = true;
    } else if (state == AppLifecycleState.resumed && _backgrounded) {
      _backgrounded = false;
      _schedule();
    }
  }

  void _schedule() {
    if (_disposed || _scheduled) return;
    _scheduled = true;
    // A font can finish loading during layout. Coalesce notifications and
    // rebuild after the frame, never dispose a painter while it is being used.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kIsWeb || !Platform.isAndroid) {
        _scheduled = false;
        if (!_disposed) onChanged();
        return;
      }
      // The new font may differ in whether it has a real bold face. All
      // observers share one detection per change.
      (_refreshing ??= ResumeSystemFonts.refresh().whenComplete(
        () => _refreshing = null,
      )).whenComplete(() {
        _scheduled = false;
        if (!_disposed) onChanged();
      });
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void dispose() {
    _disposed = true;
    PaintingBinding.instance.systemFonts.removeListener(_schedule);
    WidgetsBinding.instance.removeObserver(this);
  }
}
