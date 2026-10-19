import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:bojian_mobile/account_pages.dart';
import 'package:bojian_mobile/design.dart';
import 'package:bojian_mobile/profile_identity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/fake_gateway.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('Profile details repeated expansion and collapse frame timing', (
    tester,
  ) async {
    // Serve a fixed bundled bitmap locally: no personal data or remote requests.
    final bytes = (await rootBundle.load('assets/points/rewards.png')).buffer
        .asUint8List();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType('image', 'png');
      request.response.add(bytes);
      await request.response.close();
    });
    final api = FakeGateway();
    api.documents['GetMe']!.addAll({
      'nickname': '动画性能测试',
      'public_id': '100000',
      'city': '广东省',
      'created_at': '2025-01-02T08:00:00Z',
      'bio': '我有四年前端开发经验，负责移动端界面、交互和性能优化。希望通过清晰的经历介绍，找到适合自己的工作。' * 3,
      'avatar_url': 'http://127.0.0.1:${server.port}/avatar.png',
    });
    final store = await testStore(authenticated: true, api: api);
    addTearDown(store.dispose);
    addTearDown(() => server.close(force: true));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: appTheme,
        home: Scaffold(body: ProfilePage(store: store)),
      ),
    );
    await tester.pumpAndSettle();
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(store.ipLocation, '广东省');
    expect(find.text('ID：100000 / IP：广东'), findsOneWidget);
    final refreshRate = tester.view.display.refreshRate;
    final records = <({String label, int start, int end})>[];
    final frames = <FrameTiming>[];
    void onTimings(List<FrameTiming> values) => frames.addAll(values);
    SchedulerBinding.instance.addTimingsCallback(onTimings);
    addTearDown(
      () => SchedulerBinding.instance.removeTimingsCallback(onTimings),
    );

    Future<void> measure(String label, Future<void> Function() action) async {
      final start = developer.Timeline.now;
      await action();
      await Future<void>.delayed(const Duration(milliseconds: 650));
      await tester.pumpAndSettle(const Duration(milliseconds: 16));
      records.add((label: label, start: start, end: developer.Timeline.now));
    }

    await binding.watchPerformance(() async {
      for (var i = 0; i < 8; i++) {
        await measure(i == 0 ? 'cold-expand' : 'warm-expand', () async {
          await tester.tap(find.byKey(const ValueKey('profile-about-summary')));
        });
        expect(find.byType(ProfileDetailsPage), findsOneWidget);
        expect(find.text('IP属地：广东省'), findsOneWidget);
        await measure(i == 0 ? 'cold-collapse' : 'warm-collapse', () async {
          await tester.tap(find.byKey(const ValueKey('profile-details-close')));
        });
        expect(find.byType(ProfileDetailsPage), findsNothing);
        // Also cover expansion reached through the pull interaction.
        if (i == 7) {
          await measure('pull-expand', () async {
            final scroll = find.byKey(const ValueKey('profile-scroll'));
            await tester.timedDragFrom(
              tester.getTopLeft(scroll) + const Offset(100, 150),
              const Offset(0, 220),
              const Duration(milliseconds: 300),
            );
          });
          expect(find.byType(ProfileDetailsPage), findsOneWidget);
          await tester.drag(
            find.byKey(const ValueKey('profile-details-bio')),
            const Offset(0, -160),
          );
          await tester.pumpAndSettle();
          await measure('scrolled-collapse', () async {
            await tester.tap(
              find.byKey(const ValueKey('profile-details-close')),
            );
          });
        }
      }
    }, reportKey: 'profile-details');

    Map<String, dynamic> summary(List<FrameTiming> values) {
      double ms(Duration d) => d.inMicroseconds / 1000;
      final build = values.map((v) => ms(v.buildDuration)).toList()..sort();
      final raster = values.map((v) => ms(v.rasterDuration)).toList()..sort();
      double percentile(List<double> v, double p) =>
          v.isEmpty ? 0 : v[(p * (v.length - 1)).round()];
      return {
        'frames': values.length,
        'build_p95_ms': percentile(build, .95),
        'build_max_ms': build.isEmpty ? 0 : build.last,
        'raster_p95_ms': percentile(raster, .95),
        'raster_max_ms': raster.isEmpty ? 0 : raster.last,
        'over_16_67ms': values
            .where(
              (v) =>
                  math.max(ms(v.buildDuration), ms(v.rasterDuration)) > 16.67,
            )
            .length,
        'over_refresh_budget': values
            .where(
              (v) =>
                  math.max(ms(v.buildDuration), ms(v.rasterDuration)) >
                  1000 / refreshRate,
            )
            .length,
      };
    }

    final report = <String, dynamic>{
      'refresh_rate': refreshRate,
      'run': const String.fromEnvironment('PERF_RUN', defaultValue: 'manual'),
    };
    for (final label in records.map((r) => r.label).toSet()) {
      final windows = records.where((r) => r.label == label);
      final selected = frames
          .where(
            (f) => windows.any((r) {
              final timestamp = f.timestampInMicroseconds(
                FramePhase.buildStart,
              );
              return timestamp >= r.start && timestamp <= r.end;
            }),
          )
          .toList();
      report[label] = summary(selected);
    }
    binding.reportData!['directions'] = report;
    await File('${Directory.systemTemp.path}/profile-details-perf.json')
        .writeAsString(jsonEncode(report));
    // Machine-readable numbers are retained by the integration driver.
    debugPrint('PROFILE_DETAILS_TIMINGS ${jsonEncode(report)}');
    expect(tester.takeException(), isNull);
  });
}
