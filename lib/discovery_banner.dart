import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_store.dart';
import 'banner_ads.dart';

/// The platform view stays laid out while loading, but takes no feed space
/// until the SDK has rendered a creative. Guests never initialize the SDK.
class DiscoveryBanner extends StatelessWidget {
  const DiscoveryBanner({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final platform = defaultTargetPlatform;
    if (kIsWeb ||
        (platform != TargetPlatform.android &&
            platform != TargetPlatform.iOS)) {
      return const SizedBox.shrink();
    }
    if (platform == TargetPlatform.iOS &&
        (BannerAds.iosAppId.isEmpty || BannerAds.iosBannerId.isEmpty)) {
      return const SizedBox.shrink();
    }
    final active =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    return ListenableBuilder(
      listenable: Listenable.merge([store, BannerAds.ready]),
      builder: (context, _) {
        if (!store.isAuthenticated || !BannerAds.ready.value) {
          return const SizedBox.shrink();
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final fits = constraints.maxWidth >= 324;
            return _PlatformBanner(
              key: ValueKey(store.epoch),
              platform: platform,
              active: active && fits,
              fits: fits,
            );
          },
        );
      },
    );
  }
}

class _PlatformBanner extends StatefulWidget {
  const _PlatformBanner({
    super.key,
    required this.platform,
    required this.active,
    required this.fits,
  });
  final TargetPlatform platform;
  final bool active, fits;
  @override
  State<_PlatformBanner> createState() => _PlatformBannerState();
}

class _PlatformBannerState extends State<_PlatformBanner>
    with WidgetsBindingObserver {
  MethodChannel? channel;
  bool ready = false;
  bool finished = false;
  bool started = false;
  bool foreground = true;
  bool? lastVisibility;
  double height = 150; // Offstage bootstrap size; never reserves feed space.

  bool get visible => widget.active && foreground;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    started = visible;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(_PlatformBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (visible) started = true;
    if (oldWidget.active != widget.active) unawaited(syncVisibility());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    setState(() {
      foreground = state == AppLifecycleState.resumed;
      if (visible) started = true;
    });
    unawaited(syncVisibility());
  }

  Future<void> syncVisibility() async {
    final bridge = channel;
    if (!mounted || finished || !ready || bridge == null) return;
    final show = visible;
    if (lastVisibility == show) return;
    lastVisibility = show;
    try {
      await bridge
          .invokeMethod<void>(show ? 'show' : 'hide')
          .timeout(const Duration(seconds: 2));
    } on PlatformException {
      if (mounted) setState(() => finished = true);
    } on MissingPluginException {
      if (mounted) setState(() => finished = true);
    } on TimeoutException {
      if (mounted) setState(() => finished = true);
    }
  }

  Future<void> created(int id) async {
    final bridge = MethodChannel('cn.kelance.bojian/banner/$id');
    if (!mounted) return;
    channel = bridge;
    bridge.setMethodCallHandler((call) async {
      if (!mounted || finished) return;
      if (call.method == 'loaded') {
        if (ready) return;
        final size = (call.arguments as Map?)?['height'];
        if (size is! num || !size.isFinite || size <= 0) {
          setState(() => finished = true);
          return;
        }
        setState(() {
          height = size.toDouble();
          ready = true;
        });
        // Allocate the measured height before revealing the native content.
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted || finished) return;
        await syncVisibility();
      } else if (call.method == 'closed' || call.method == 'failed') {
        debugPrint('DiscoveryBanner: ${call.method} ${call.arguments}');
        setState(() => finished = true);
      }
    });
    try {
      await bridge
          .invokeMethod<void>('load', {
            'appId': widget.platform == TargetPlatform.iOS
                ? BannerAds.iosAppId
                : const String.fromEnvironment(
                    'PANGLE_ANDROID_APP_ID',
                    defaultValue: '5898107',
                  ),
            'slotId': widget.platform == TargetPlatform.iOS
                ? BannerAds.iosBannerId
                : const String.fromEnvironment(
                    'PANGLE_ANDROID_BANNER_ID',
                    defaultValue: '104712824',
                  ),
            'consent': true,
            if (widget.platform == TargetPlatform.iOS)
              'useMediation': BannerAds.iosUseMediation,
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
    WidgetsBinding.instance.removeObserver(this);
    channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (finished || !started) return const SizedBox.shrink();
    return Offstage(
      offstage: !ready || !widget.fits,
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
        child: Center(
          child: SizedBox(
            width: 300,
            height: height,
            child: widget.platform == TargetPlatform.iOS
                ? UiKitView(
                    viewType: 'cn.kelance.bojian/banner',
                    onPlatformViewCreated: created,
                    layoutDirection: TextDirection.ltr,
                  )
                : AndroidView(
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
