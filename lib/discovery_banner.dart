import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_store.dart';
import 'startup_ads.dart';

/// The platform view stays laid out while loading, but takes no feed space
/// until the SDK has rendered a creative. Guests never initialize the SDK.
class DiscoveryBanner extends StatelessWidget {
  const DiscoveryBanner({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) return const SizedBox.shrink();
    final active = TickerMode.valuesOf(context).enabled;
    return ListenableBuilder(
      listenable: Listenable.merge([store, StartupAds.readyForBanner]),
      builder: (context, _) {
        if (!active ||
            !store.isAuthenticated ||
            !StartupAds.readyForBanner.value) {
          return const SizedBox.shrink();
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 324) return const SizedBox.shrink();
            return _AndroidBanner(key: ValueKey(store.epoch));
          },
        );
      },
    );
  }
}

class _AndroidBanner extends StatefulWidget {
  const _AndroidBanner({super.key});
  @override
  State<_AndroidBanner> createState() => _AndroidBannerState();
}

class _AndroidBannerState extends State<_AndroidBanner> {
  MethodChannel? channel;
  bool ready = false;
  bool finished = false;
  Future<void> created(int id) async {
    final bridge = MethodChannel('cn.kelance.bojian/banner/$id');
    if (!mounted) return;
    channel = bridge;
    bridge.setMethodCallHandler((call) async {
      if (!mounted || finished) return;
      if (call.method == 'loaded') {
        setState(() => ready = true);
        // Reveal native content only after Flutter allocates its visible space.
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted || finished) return;
        try {
          await bridge
              .invokeMethod<void>('show')
              .timeout(const Duration(seconds: 2));
        } on PlatformException {
          if (mounted) setState(() => finished = true);
        } on MissingPluginException {
          if (mounted) setState(() => finished = true);
        } on TimeoutException {
          if (mounted) setState(() => finished = true);
        }
      } else if (call.method == 'closed' || call.method == 'failed') {
        debugPrint('DiscoveryBanner: ${call.method} ${call.arguments}');
        setState(() => finished = true);
      }
    });
    try {
      await bridge
          .invokeMethod<void>('load', {
            'appId': const String.fromEnvironment(
              'PANGLE_ANDROID_APP_ID',
              defaultValue: '5898107',
            ),
            'slotId': const String.fromEnvironment(
              'PANGLE_ANDROID_BANNER_ID',
              defaultValue: '104712824',
            ),
            'consent': true,
          })
          .timeout(const Duration(seconds: 2));
    } on PlatformException {
      if (mounted) setState(() => finished = true);
    } on MissingPluginException {
      if (mounted) setState(() => finished = true);
    } on TimeoutException {
      if (mounted) setState(() => finished = true);
    }
  }

  @override
  void dispose() {
    channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (finished) return const SizedBox.shrink();
    return Offstage(
      offstage: !ready,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 300,
            height: 150,
            child: AndroidView(
              viewType: 'cn.kelance.bojian/banner',
              onPlatformViewCreated: created,
              layoutDirection: TextDirection.ltr,
            ),
          ),
        ),
      ),
    );
  }
}
