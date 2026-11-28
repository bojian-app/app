import 'package:bojian_mobile/startup_animation.dart';
import 'package:bojian_mobile/startup_scene.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs a cold start that finishes loading after [load] seconds and returns how
/// long the animation took.
double play(double load) {
  final run = StartupRun();
  var time = 0.0;
  while (!run.finished) {
    final loaded = time >= load;
    run.advance(1 / 60, loaded: loaded, completedSteps: loaded ? 2 : 0);
    time += 1 / 60;
    if (!loaded) {
      expect(run.stage, StartupStage.running);
      expect(run.officeX, isNull);
    }
    expect(time, lessThan(load + 2.5));
  }
  expect(run.stage, StartupStage.delivered);
  return time;
}

void main() {
  test('The resume changes hands only after loading, quickly or slowly', () {
    expect(play(0), inInclusiveRange(2.0, 2.4));
    for (final load in [1.0, 3.0, 20.0]) {
      expect(play(load), greaterThan(load + 1.5));
    }
  });

  test('She tires while loading drags on and bursts as steps complete', () {
    final run = StartupRun();
    for (var i = 0; i < 240; i++) {
      run.advance(1 / 60, loaded: false, completedSteps: 0);
    }
    final tired = run.speed;
    expect(tired, inInclusiveRange(StartupRun.jogSpeed, 900));
    for (var i = 0; i < 20; i++) {
      run.advance(1 / 60, loaded: false, completedSteps: 1);
    }
    expect(run.speed, greaterThan(tired + 400));
  });

  testWidgets('Decoded artwork plays through to the handover', (tester) async {
    final loading = StartupLoading();
    var delivered = false;
    loading.delivered.then((_) => delivered = true);
    await tester.pumpWidget(
      MaterialApp(home: StartupAnimation(loading: loading)),
    );
    await tester.runAsync(() async {
      for (final asset in startupSceneAssets) {
        await precacheImage(
          AssetImage(asset),
          tester.element(find.byType(StartupAnimation)),
        );
      }
    });
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(delivered, isFalse, reason: 'startup has not loaded yet');
    loading.finish();
    for (var i = 0; i < 50 && !delivered; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(delivered, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    loading.dispose();
  });

  testWidgets('Reduced motion shows a still and never waits', (tester) async {
    final loading = StartupLoading();
    var delivered = false;
    loading.delivered.then((_) => delivered = true);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: StartupAnimation(loading: loading),
        ),
      ),
    );
    expect(tester.hasRunningAnimations, isFalse);
    loading.finish();
    await tester.pump();
    expect(delivered, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    loading.dispose();
  });
}
