import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_store.dart';
import 'banner_ads.dart';
import 'design.dart';
import 'invitation_dialog.dart';
import 'membership_status.dart';

/// The feed's separator between rows, shared so the ad row matches the cards.
const discoveryGapHeight = 6.0;
Color discoveryGapColor(BuildContext context) =>
    context.isDark ? context.colors.canvas : context.colors.inset;

/// How long the third-party creative stays visible before the house ad takes
/// its place.
const discoveryAdDuration = Duration(seconds: 5);
const _countdownTick = Duration(milliseconds: 250);
// Transparent artwork; the dark variant keeps the headline readable.
AssetImage _houseAd(BuildContext context) => AssetImage(
  context.isDark
      ? 'assets/discovery/invite_ad_dark.webp'
      : 'assets/discovery/invite_ad.webp',
);
// 1248 x 600: 150 tall when the feed's content column is 312 wide.
const _houseAdAspectRatio = 312 / 150;

/// The platform view stays laid out while loading, but takes no feed space
/// until the SDK has rendered a creative. Once that creative has been visible
/// for [discoveryAdDuration], is closed, or fails, the house ad replaces it.
/// Members skip the third-party ad and see the house ad straight away. Guests
/// see neither, and neither guests nor members initialize the SDK.
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
      listenable: Listenable.merge([
        store,
        BannerAds.ready,
        MembershipStatus.instance,
      ]),
      builder: (context, _) {
        if (!store.isAuthenticated || !BannerAds.ready.value) {
          return const SizedBox.shrink();
        }
        // 会员状态读到之前不加载第三方广告，避免会员看到一闪而过的广告。
        final status = MembershipStatus.instance;
        if (!status.knownFor(store.userID)) return const SizedBox.shrink();
        // 会员只免第三方广告，邀请好友照常展示。
        if (status.isMemberOf(store.userID)) return _HouseAdRow(store: store);
        return LayoutBuilder(
          builder: (context, constraints) {
            final fits = constraints.maxWidth >= 324;
            return _PlatformBanner(
              key: ValueKey(store.epoch),
              store: store,
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
    required this.store,
    required this.platform,
    required this.active,
    required this.fits,
  });
  final AppStore store;
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
  late final int epoch;
  Duration remaining = discoveryAdDuration;
  Timer? countdown;

  bool get visible => widget.active && foreground;

  @override
  void initState() {
    super.initState();
    epoch = widget.store.epoch;
    finished = BannerAds.replacedEpoch[widget.store] == epoch;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    started = visible;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Decode ahead of time so the swap never shows an empty row.
    unawaited(precacheImage(_houseAd(context), context));
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
    if (!show) stopCountdown();
    try {
      await bridge
          .invokeMethod<void>(show ? 'show' : 'hide')
          .timeout(const Duration(seconds: 2));
      if (show) startCountdown();
    } on PlatformException {
      finish();
    } on MissingPluginException {
      finish();
    } on TimeoutException {
      finish();
    }
  }

  /// Counts only the time the creative is on screen; hiding it pauses.
  void startCountdown() {
    if (!mounted || finished || !visible) return;
    countdown ??= Timer.periodic(_countdownTick, (_) {
      remaining -= _countdownTick;
      if (remaining <= Duration.zero) finish();
    });
  }

  void stopCountdown() {
    countdown?.cancel();
    countdown = null;
  }

  /// Drops the third-party view (releasing the native ad) for the house ad.
  void finish() {
    stopCountdown();
    if (!mounted || finished) return;
    BannerAds.replacedEpoch[widget.store] = epoch;
    setState(() => finished = true);
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
          finish();
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
        finish();
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
      finish();
    } on MissingPluginException {
      finish();
    } on TimeoutException {
      finish();
    }
  }

  @override
  void dispose() {
    stopCountdown();
    WidgetsBinding.instance.removeObserver(this);
    channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (finished) {
      if (!widget.fits) return const SizedBox.shrink();
      return _HouseAdRow(store: widget.store);
    }
    if (!started) return const SizedBox.shrink();
    return Offstage(
      offstage: !ready || !widget.fits,
      child: _AdRow(
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
    );
  }
}

/// A row of its own, separated from the cards by the feed's gap.
class _AdRow extends StatelessWidget {
  const _AdRow({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: discoveryGapColor(context),
    child: Container(
      color: context.colors.surface,
      margin: const EdgeInsets.only(bottom: discoveryGapHeight),
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Center(child: child),
    ),
  );
}

/// The house ad in its row, as wide as the article content below it, with the
/// same gutters as FeedRow.
class _HouseAdRow extends StatelessWidget {
  const _HouseAdRow({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) => _AdRow(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: feedOuterPadding),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: feedContentPadding),
          child: AspectRatio(
            aspectRatio: _houseAdAspectRatio,
            child: _HouseAd(store: store),
          ),
        ),
      ),
    ),
  );
}

/// The in-house "invite friends" creative, opening the invitation poster.
class _HouseAd extends StatelessWidget {
  const _HouseAd({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '邀请好友领 3 天会员',
    excludeSemantics: true,
    child: GestureDetector(
      key: const ValueKey('discovery-house-ad'),
      behavior: HitTestBehavior.opaque,
      onTap: () => showInvitationDialog(context, store),
      child: Image(
        image: _houseAd(context),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    ),
  );
}
