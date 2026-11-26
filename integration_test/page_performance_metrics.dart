import 'dart:math' as math;
import 'dart:ui' show FrameTiming;

Map<String, Object> summarizePageFrames(List<FrameTiming> frames, double hz) {
  final budgetUs = 1e6 / hz;
  int build(FrameTiming f) => f.buildDuration.inMicroseconds;
  int raster(FrameTiming f) => f.rasterDuration.inMicroseconds;
  double rank(List<int> sorted, double p) =>
      sorted.isEmpty ? 0 : sorted[((sorted.length - 1) * p).round()] / 1000;
  final builds = frames.map(build).toList()..sort();
  final rasters = frames.map(raster).toList()..sort();
  var streak = 0, longest = 0;
  for (final frame in frames) {
    if (math.max(build(frame), raster(frame)) > budgetUs) {
      longest = math.max(longest, ++streak);
    } else {
      streak = 0;
    }
  }
  return {
    'frames': frames.length,
    'build_p95_ms': rank(builds, .95),
    'raster_p95_ms': rank(rasters, .95),
    'build_max_ms': rank(builds, 1),
    'raster_max_ms': rank(rasters, 1),
    'build_over': builds.where((us) => us > budgetUs).length,
    'raster_over': rasters.where((us) => us > budgetUs).length,
    'either_over': frames
        .where((f) => math.max(build(f), raster(f)) > budgetUs)
        .length,
    'either_over_double': frames
        .where((f) => math.max(build(f), raster(f)) > 2 * budgetUs)
        .length,
    'longest_consecutive_over': longest,
  };
}
