import 'dart:ui' as ui;

import 'package:bojian_mobile/startup_screen.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app({
  bool reduceMotion = false,
  TextScaler textScaler = TextScaler.noScaling,
  Widget child = const Scaffold(body: Text('首页')),
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      disableAnimations: reduceMotion,
      textScaler: textScaler,
    ),
    child: StartupScreen(child: child),
  ),
);

class _HomeProbe extends StatefulWidget {
  const _HomeProbe({required this.onInit, required this.onTap});

  final VoidCallback onInit;
  final VoidCallback onTap;

  @override
  State<_HomeProbe> createState() => _HomeProbeState();
}

class _HomeProbeState extends State<_HomeProbe> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Semantics(
        label: '首页操作',
        button: true,
        child: GestureDetector(
          key: const ValueKey('home-action'),
          onTap: widget.onTap,
          child: Container(
            color: Colors.blue,
            width: 240,
            height: 72,
            child: const Center(child: Text('首页')),
          ),
        ),
      ),
    ),
  );
}

Future<List<int>> _captureScene(
  WidgetTester tester,
) async => (await tester.runAsync(() async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('welcome-capture')),
  );
  final frame = await boundary.toImage(pixelRatio: 1);
  try {
    final bytes = await frame.toByteData(format: ui.ImageByteFormat.rawRgba);
    return bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
  } finally {
    frame.dispose();
  }
}))!;

void main() {
  testWidgets('Welcome finishes within 2300 ms without using an image', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    // Establish the first ticker timestamp without consuming animation time.
    await tester.pump();
    expect(find.text('跳过'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    for (var frame = 0; frame < 23; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('跳过'), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Welcome keeps a light background while its scene animates', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(key: const ValueKey('welcome-capture'), child: app()),
    );
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(StartupScreen),
        matching: find.byType(CustomPaint),
      ),
      findsWidgets,
    );
    final firstFrame = await _captureScene(tester);
    await tester.pump(const Duration(milliseconds: 300));
    final entrance = await _captureScene(tester);
    await tester.pump(const Duration(milliseconds: 600));
    final flight = await _captureScene(tester);
    await tester.pump(const Duration(milliseconds: 800));
    final arrival = await _captureScene(tester);
    for (final frame in [firstFrame, entrance, flight, arrival]) {
      expect(frame.length, 320 * 568 * 4);
      for (final (x, y) in [(4, 4), (315, 4), (4, 563), (315, 563)]) {
        final pixel = (y * 320 + x) * 4;
        expect(frame.sublist(pixel, pixel + 4), [
          0xF7,
          0xF8,
          0xFA,
          0xFF,
        ], reason: 'The scene background stays light at ($x, $y).');
      }
    }
    expect(entrance.length, flight.length);
    expect(flight.length, arrival.length);
    expect(listEquals(entrance, flight), isFalse);
    expect(listEquals(flight, arrival), isFalse);
    expect(find.text('跳过'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.text('跳过'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Welcome does not replay on rebuild', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('跳过'), findsNothing);
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('跳过'), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('Home initializes once and is isolated until welcome ends', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      var initializations = 0;
      var taps = 0;
      final home = _HomeProbe(
        onInit: () => initializations++,
        onTap: () => taps++,
      );
      await tester.pumpWidget(app(child: home));
      expect(find.semantics.byLabel(RegExp('博简')), findsOneWidget);
      await tester.pump();
      expect(initializations, 1);
      expect(find.text('首页'), findsOneWidget);
      expect(find.semantics.byLabel(RegExp('首页操作')), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('home-action')),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(taps, 0);
      expect(find.semantics.byLabel(RegExp('首页操作')), findsNothing);
      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pump(const Duration(milliseconds: 90));
      await tester.tap(
        find.byKey(const ValueKey('home-action')),
        warnIfMissed: false,
      );
      expect(taps, 0);
      expect(find.semantics.byLabel(RegExp('首页操作')), findsNothing);
      await tester.pumpAndSettle();
      expect(initializations, 1);
      expect(find.semantics.byLabel(RegExp('首页操作')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('home-action')));
      expect(taps, 1);
      await tester.pumpWidget(app(child: home));
      expect(initializations, 1);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('Skip opens the home on the next frame', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.tap(find.text('跳过'));
    await tester.pump();
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('跳过'), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reduced motion bypasses the welcome', (tester) async {
    await tester.pumpWidget(app(reduceMotion: true));
    await tester.pump();
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('跳过'), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets(
    'Enabling reduced motion during welcome immediately finishes it',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('跳过'), findsOneWidget);
      await tester.pumpWidget(app(reduceMotion: true));
      await tester.pump();
      expect(find.text('跳过'), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(app());
      await tester.pump();
      expect(find.text('跳过'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Leaving and resuming the app does not replay welcome', (
    tester,
  ) async {
    addTearDown(() {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('跳过'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('跳过'), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Disposing during welcome leaves no active ticker', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Small screens and enlarged text do not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(textScaler: const TextScaler.linear(2)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 1190));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.text('首页'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Landscape and enlarged text fit throughout welcome', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(740, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(textScaler: const TextScaler.linear(2)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 1190));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('跳过'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
