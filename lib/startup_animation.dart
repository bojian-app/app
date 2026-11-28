import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'design.dart';
import 'startup_run.dart';
import 'startup_scene.dart';

export 'startup_run.dart';

/// The cold-start welcome, entirely local: a girl rushes to the office with her
/// resume and the man at the desk takes it. How fast she runs follows
/// [loading]; she cannot hand it over before startup has finished.
class StartupAnimation extends StatefulWidget {
  const StartupAnimation({
    super.key,
    required this.loading,
    this.animate = true,
  });
  final StartupLoading loading;
  final bool animate;

  @override
  State<StartupAnimation> createState() => _StartupAnimationState();
}

class _StartupAnimationState extends State<StartupAnimation>
    with SingleTickerProviderStateMixin {
  late final Ticker ticker;
  final frame = ValueNotifier(0);
  var run = StartupRun();
  Duration last = Duration.zero;

  /// Reduced motion: one picture, and startup never waits for it.
  bool still = false;
  bool artworkFailed = false;

  final streams = <ImageStream, ImageStreamListener>{};
  final decoded = <String, ImageInfo>{};
  Map<String, ui.Image> images = const {};

  @override
  void initState() {
    super.initState();
    ticker = createTicker(tick);
    widget.loading.addListener(update);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    still = !widget.animate || MediaQuery.disableAnimationsOf(context);
    if (streams.isEmpty) loadArtwork();
    update();
  }

  void loadArtwork() {
    final configuration = createLocalImageConfiguration(context);
    for (final asset in startupSceneAssets) {
      final stream = AssetImage(asset).resolve(configuration);
      final listener = ImageStreamListener(
        (info, _) {
          if (!mounted) {
            info.dispose();
            return;
          }
          decoded.remove(asset)?.dispose();
          decoded[asset] = info;
          if (decoded.length < startupSceneAssets.length) return;
          setState(() {
            images = {
              for (final entry in decoded.entries) entry.key: entry.value.image,
            };
          });
          update();
        },
        onError: (_, _) {
          if (!mounted) return;
          artworkFailed = true;
          update();
        },
      );
      streams[stream] = listener;
      stream.addListener(listener);
    }
  }

  void update() {
    if (still) run = StartupRun.arrived();
    if (still || artworkFailed) {
      ticker.stop();
      if (widget.loading.loaded) widget.loading.deliver();
      return;
    }
    if (!ticker.isActive && !run.finished) {
      last = Duration.zero;
      ticker.start();
    }
  }

  void tick(Duration elapsed) {
    // A slow first frame must not make her jump ahead.
    final seconds = math.min((elapsed - last).inMicroseconds / 1e6, .05);
    last = elapsed;
    // Nobody should miss the start of the run while the drawings decode.
    if (images.isEmpty) return;
    run.advance(
      seconds,
      loaded: widget.loading.loaded,
      completedSteps: widget.loading.completedSteps,
    );
    frame.value++;
    if (run.finished) {
      ticker.stop();
      widget.loading.deliver();
    }
  }

  @override
  void dispose() {
    widget.loading.removeListener(update);
    for (final entry in streams.entries) {
      entry.key.removeListener(entry.value);
    }
    for (final info in decoded.values) {
      info.dispose();
    }
    ticker.dispose();
    frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: context.colors.canvas,
      body: SafeArea(
        // Short landscape windows with large text cannot fit the scene, so it
        // scales down as a whole instead of overflowing; it never scales up.
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: constraints.maxWidth,
                child: Semantics(
                  label: 'Z优简，正在准备应用',
                  child: ExcludeSemantics(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: AspectRatio(
                              aspectRatio: startupSceneSize.aspectRatio,
                              // The office wall is white; the rim keeps the
                              // picture's edge on a white page.
                              child: DecoratedBox(
                                position: DecorationPosition.foreground,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: const Color(0xFF7094D0)
                                        .withValues(alpha: .28),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: RepaintBoundary(
                                    child: CustomPaint(
                                      painter: StartupScenePainter(
                                        run: run,
                                        images: images,
                                        dark: dark,
                                        repaint: frame,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Z优简',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 6,
                            color: context.colors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
