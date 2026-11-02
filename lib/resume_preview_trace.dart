import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

const traceResumePreview = bool.fromEnvironment(
  'BOJIAN_TRACE_TEMPLATE_PREVIEW',
);

/// Opt-in device diagnostics. Never logs resume content or authenticated URLs.
class ResumePreviewTrace {
  ResumePreviewTrace(this.id) {
    if (!traceResumePreview) return;
    started = DateTime.now().microsecondsSinceEpoch;
    debugPrint('BOJIAN_RESUME id=$id stage=route-start');
    SchedulerBinding.instance.addTimingsCallback(record);
    timer = Timer(const Duration(seconds: 2), dispose);
  }
  final int id;
  int started = 0, frames = 0, maxBuild = 0, maxRaster = 0;
  Timer? timer;
  bool stopped = false;
  void record(List<FrameTiming> timings) {
    for (final frame in timings) {
      if (frame.timestampInMicroseconds(FramePhase.rasterFinishWallTime) <
          started) {
        continue;
      }
      frames++;
      final build = frame.buildDuration.inMicroseconds;
      final raster = frame.rasterDuration.inMicroseconds;
      if (build > maxBuild) maxBuild = build;
      if (raster > maxRaster) maxRaster = raster;
      if (build > 16000 || raster > 16000) {
        debugPrint(
          'BOJIAN_RESUME id=$id stage=slow-frame build_us=$build raster_us=$raster',
        );
      }
    }
  }

  void dispose() {
    if (!traceResumePreview || stopped) return;
    stopped = true;
    timer?.cancel();
    SchedulerBinding.instance.removeTimingsCallback(record);
    debugPrint(
      'BOJIAN_RESUME id=$id stage=frames frames=$frames max_build_us=$maxBuild max_raster_us=$maxRaster',
    );
  }
}
