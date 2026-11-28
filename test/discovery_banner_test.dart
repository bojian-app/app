import 'dart:async';

import 'package:bojian_mobile/app_store.dart';
import 'package:bojian_mobile/discovery_banner.dart';
import 'package:bojian_mobile/banner_ads.dart';
import 'package:bojian_mobile/membership_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final created = <int>[];
  final disposed = <int>[];
  final calls = <int, List<String>>{};
  late AppStore store;
  late ValueNotifier<bool> active;
  const houseAd = ValueKey('discovery-house-ad');

  setUp(() async {
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    BannerAds.ready.value = true;
    created.clear();
    disposed.clear();
    calls.clear();
    store = await testStore(authenticated: true);
    MembershipStatus.instance.apply(store.userID, null);
    active = ValueNotifier(true);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      final args = call.arguments is Map ? call.arguments as Map : null;
      final id = args == null ? call.arguments as int : args['id'] as int;
      if (call.method == 'create') {
        created.add(id);
        calls[id] = [];
        messenger.setMockMethodCallHandler(
          MethodChannel('cn.kelance.bojian/banner/$id'),
          (call) async {
            calls[id]!.add(call.method);
            return null;
          },
        );
        return id + 100;
      }
      if (call.method == 'dispose') disposed.add(id);
      if (call.method == 'resize') {
        return {'width': args!['width'], 'height': args['height']};
      }
      return null;
    });
  });

  tearDown(() {
    for (final id in created) {
      messenger.setMockMethodCallHandler(
        MethodChannel('cn.kelance.bojian/banner/$id'),
        null,
      );
    }
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    BannerAds.ready.value = false;
    MembershipStatus.instance.reset();
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    active.dispose();
    store.dispose();
  });

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: active,
                  builder: (_, enabled, _) => Offstage(
                    offstage: !enabled,
                    child: TickerMode(
                      enabled: enabled,
                      child: DiscoveryBanner(store: store),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const Scaffold(body: Text('详情页')),
                    ),
                  ),
                  child: const Text('详情'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> notify(
    WidgetTester tester,
    int id,
    String method, [
    Object? args,
  ]) async {
    final complete = Completer<void>();
    messenger.handlePlatformMessage(
      'cn.kelance.bojian/banner/$id',
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
      (_) => complete.complete(),
    );
    await tester.pumpAndSettle();
    await complete.future;
    await tester.pumpAndSettle();
  }

  Finder getBanner() => find.byType(DiscoveryBanner, skipOffstage: false);

  testWidgets(
    'Returning to a retained tab keeps the same native ad and measured height',
    (tester) async {
      await mount(tester);
      final id = created.single;
      expect(tester.getSize(getBanner()).height, 0);
      await notify(tester, id, 'loaded', {'height': 103.0});
      expect(tester.getSize(getBanner()).height, 125);
      final view = tester.element(find.byType(AndroidView));
      for (var i = 0; i < 3; i++) {
        active.value = false;
        await tester.pumpAndSettle();
        expect(tester.getSize(getBanner()).height, 125);
        expect(calls[id]!.last, 'hide');
        expect(disposed, isEmpty);
        store.changed();
        active.value = true;
        await tester.pumpAndSettle();
        expect(tester.element(find.byType(AndroidView)), same(view));
        expect(tester.getSize(getBanner()).height, 125);
        expect(calls[id]!.last, 'show');
      }
      expect(created, [id]);
      expect(calls[id]!.where((method) => method == 'load'), hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  for (final terminal in ['closed', 'failed']) {
    testWidgets(
      '$terminal keeps the house ad after tab switches and rebuilds',
      (tester) async {
        await mount(tester);
        final id = created.single;
        await notify(tester, id, 'loaded', {'height': 88.0});
        await notify(tester, id, terminal);
        expect(tester.getSize(getBanner()).height, 172);
        expect(find.byKey(houseAd), findsOneWidget);
        expect(disposed, [id]);
        active.value = false;
        await tester.pumpAndSettle();
        store.changed();
        active.value = true;
        await tester.pumpAndSettle();
        expect(tester.getSize(getBanner()).height, 172);
        expect(created, [id]);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets(
    'The house ad replaces the creative after 5 visible seconds for good',
    (tester) async {
      await mount(tester);
      final id = created.single;
      await tester.pump(const Duration(seconds: 10));
      expect(find.byKey(houseAd), findsNothing);
      await notify(tester, id, 'loaded', {'height': 150.0});
      await tester.pump(const Duration(seconds: 3));
      active.value = false;
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 10));
      expect(disposed, isEmpty);
      active.value = true;
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      expect(disposed, isEmpty);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(disposed, [id]);
      expect(find.byKey(houseAd), findsOneWidget);
      expect(tester.getSize(getBanner()).height, 172);
      // Same left and right edges as the article content: 24 on each side.
      expect(tester.getRect(find.byKey(houseAd)).left, 24);
      expect(tester.getSize(find.byKey(houseAd)), const Size(312, 150));
      await tester.pumpWidget(const SizedBox.shrink());
      await mount(tester);
      expect(find.byKey(houseAd), findsOneWidget);
      expect(created, [id]);
      MembershipStatus.instance.apply(
        store.userID,
        DateTime.now().add(const Duration(days: 30)),
      );
      await tester.pump();
      expect(find.byKey(houseAd), findsOneWidget);
      MembershipStatus.instance.reset(); // Cancels the expiry timer.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'Hidden tabs defer initial loading and late creatives remain hidden until return',
    (tester) async {
      active.value = false;
      await mount(tester);
      expect(created, isEmpty);
      active.value = true;
      await tester.pumpAndSettle();
      final id = created.single;
      active.value = false;
      await tester.pumpAndSettle();
      await notify(tester, id, 'loaded', {'height': 92.0});
      expect(calls[id], ['load', 'hide']);
      expect(tester.getSize(getBanner()).height, 114);
      active.value = true;
      await tester.pumpAndSettle();
      expect(created, [id]);
      expect(calls[id], ['load', 'hide', 'show']);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'Routes and backgrounding hide without reloading; session changes release the ad',
    (tester) async {
      await mount(tester);
      final id = created.single;
      await notify(tester, id, 'loaded', {'height': 100.0});
      await tester.tap(find.text('详情'));
      await tester.pumpAndSettle();
      expect(calls[id]!.last, 'hide');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(calls[id]!.last, 'show');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect(calls[id]!.last, 'hide');
      expect(tester.getSize(getBanner()).height, 122);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(calls[id]!.last, 'show');
      expect(created, [id]);
      active.value = false;
      await tester.pumpAndSettle();
      store.epoch++;
      store.changed();
      await tester.pumpAndSettle();
      expect(disposed, [id]);
      expect(created, [id]);
      active.value = true;
      await tester.pumpAndSettle();
      expect(created, hasLength(2));
      store.session = null;
      store.changed();
      await tester.pumpAndSettle();
      expect(disposed, hasLength(2));
      expect(tester.getSize(getBanner()).height, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'iOS mounts a UIKit banner and retains it across visibility changes',
    (tester) async {
      await mount(tester);
      final id = created.single;
      expect(find.byType(UiKitView, skipOffstage: false), findsOneWidget);
      expect(find.byType(AndroidView, skipOffstage: false), findsNothing);
      expect(tester.getSize(getBanner()).height, 0);
      await notify(tester, id, 'loaded', {'height': 150.0});
      expect(tester.getSize(getBanner()).height, 172);
      active.value = false;
      await tester.pumpAndSettle();
      expect(calls[id]!.last, 'hide');
      active.value = true;
      await tester.pumpAndSettle();
      expect(calls[id]!.last, 'show');
      expect(created, [id]);
      expect(calls[id]!.where((method) => method == 'load'), hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant({TargetPlatform.iOS}),
  );

  testWidgets('members see only the house ad; unknown membership waits', (
    tester,
  ) async {
    MembershipStatus.instance.reset();
    await mount(tester);
    expect(created, isEmpty);
    expect(find.byKey(houseAd), findsNothing);
    MembershipStatus.instance.apply(
      store.userID,
      DateTime.now().add(const Duration(days: 30)),
    );
    await tester.pump();
    expect(created, isEmpty);
    expect(find.byKey(houseAd), findsOneWidget);
    expect(tester.getSize(getBanner()).height, 172);
    MembershipStatus.instance.apply(store.userID, null);
    await tester.pump();
    expect(created, isNotEmpty);
  });

  testWidgets('iOS guests do not create or initialize an ad view', (
    tester,
  ) async {
    store.session = null;
    await mount(tester);
    expect(created, isEmpty);
    expect(find.byType(UiKitView, skipOffstage: false), findsNothing);
    expect(tester.getSize(getBanner()).height, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }, variant: TargetPlatformVariant({TargetPlatform.iOS}));
}
