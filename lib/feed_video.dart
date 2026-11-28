import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'app_store.dart';
import 'article_video_player.dart';
import 'feed_media.dart' show FeedMoreCount, articleMediaURL, loneMediaSize;

/// A post's video on its feed card, alone or as a cell of the post's grid.
///
/// The card shows a placeholder with the clip's length. Once scrolling settles,
/// the topmost video that is mostly in view (the first of a row) starts playing
/// muted, in a loop. Pressing play on a lone video's placeholder plays it with
/// sound; a grid cell opens full screen instead. Only one feed video holds a
/// decoder at a time, and playback pauses when the card scrolls mostly out of
/// view, the tab or page is covered, or the app goes to the background.
class FeedVideo extends StatefulWidget {
  const FeedVideo({
    super.key,
    required this.store,
    required this.video,
    this.articleID = 0,
    this.onOpen,
    this.more = 0,
  });

  final AppStore store;

  /// The block's `video` map: `file_id`, and optionally `duration_ms`,
  /// `width` and `height`.
  final Map<String, dynamic> video;
  final int articleID;

  /// Makes this a grid cell that fills its box and opens on a tap.
  final VoidCallback? onOpen;

  /// How much the grid leaves out, counted over its last cell.
  final int more;

  /// How feed videos, on the card and full screen, get their decoder; tests
  /// replace it.
  static VideoPlayerController Function(Uri url) createController =
      VideoPlayerController.networkUrl;

  @override
  State<FeedVideo> createState() => _FeedVideoState();
}

class _FeedVideoState extends State<FeedVideo> with WidgetsBindingObserver {
  static _FeedVideoState? _active;
  static final _all = <_FeedVideoState>{};
  static Timer? _pick;

  VideoPlayerController? player;
  bool loading = false, failed = false;
  bool covered = false, resumed = true;

  /// Playing without sound, as autoplay does until the reader turns it on.
  bool muted = false;

  /// The reader paused this video; autoplay leaves it until it leaves view.
  bool userPaused = false;
  ScrollPosition? position;
  int attempt = 0;

  int get fileID => integer(widget.video['file_id']);

  double? get declaredRatio {
    final width = integer(widget.video['width']);
    final height = integer(widget.video['height']);
    return width > 0 && height > 0 ? width / height : null;
  }

  Duration? get declaredDuration {
    final ms = integer(widget.video['duration_ms']);
    return ms > 0 ? Duration(milliseconds: ms) : null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _all.add(this);
    resumed =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    schedulePick();
  }

  bool get canAutoplay =>
      mounted && !covered && resumed && !failed && !userPaused && fileID > 0;

  /// Looks for a video to autoplay once scrolling has been still for a moment,
  /// so a fling past many cards loads none of them.
  static void schedulePick() {
    _pick?.cancel();
    _pick = Timer(const Duration(milliseconds: 300), pickAutoplay);
  }

  static void pickAutoplay() {
    _pick = null;
    final active = _active;
    if (active != null && active.mounted) {
      final shown = active.visibleFraction();
      if (active.userPaused && shown >= 0.3) return;
      if (active.canAutoplay && shown >= 0.6) {
        active.resume();
        return;
      }
    }
    _FeedVideoState? best;
    var top = double.infinity;
    for (final state in _all) {
      if (!state.canAutoplay || state.visibleFraction() < 0.6) continue;
      final y = state.top();
      if (y < top) {
        top = y;
        best = state;
      }
    }
    if (best == null) return;
    if (identical(best, active)) {
      best.resume();
    } else {
      best.start(auto: true);
    }
  }

  double top() {
    final box = context.findRenderObject();
    return box is RenderBox && box.attached && box.hasSize
        ? box.localToGlobal(Offset.zero).dy
        : double.infinity;
  }

  /// Continues autoplay of the video that already holds the decoder.
  void resume() {
    final controller = player;
    if (controller == null) {
      if (!loading) start(auto: true);
    } else if (controller.value.isInitialized && !controller.value.isPlaying) {
      controller.play();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Scrollable.maybeOf(context)?.position;
    if (next != position) {
      position?.removeListener(onScroll);
      position = next?..addListener(onScroll);
    }
    covered =
        !TickerMode.valuesOf(context).enabled ||
        ModalRoute.isCurrentOf(context) == false;
    // Pausing notifies the controls, so it waits until this build is over.
    if (covered && player != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) pause();
      });
    }
    if (!covered) schedulePick();
  }

  @override
  void didUpdateWidget(FeedVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (integer(oldWidget.video['file_id']) != fileID ||
        oldWidget.articleID != widget.articleID) {
      release();
      failed = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    resumed = state == AppLifecycleState.resumed;
    if (resumed) {
      schedulePick();
    } else {
      pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    position?.removeListener(onScroll);
    _all.remove(this);
    if (_all.isEmpty) {
      _pick?.cancel();
      _pick = null;
    }
    attempt++;
    player?.dispose();
    player = null;
    if (identical(_active, this)) _active = null;
    super.dispose();
  }

  void pause() {
    final controller = player;
    if (controller != null && controller.value.isPlaying) controller.pause();
  }

  /// Frees the decoder, back to the placeholder.
  void release() {
    attempt++;
    final controller = player;
    player = null;
    loading = false;
    controller?.dispose();
    if (identical(_active, this)) _active = null;
    if (mounted) setState(() {});
  }

  void onScroll() {
    schedulePick();
    if (visibleFraction() >= 0.3) return;
    userPaused = false;
    final controller = player;
    if (controller != null && controller.value.isPlaying) controller.pause();
  }

  double visibleFraction() {
    if (!mounted) return 0;
    final box = context.findRenderObject();
    final viewport = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (box is! RenderBox ||
        viewport is! RenderBox ||
        !box.attached ||
        !viewport.attached ||
        !box.hasSize ||
        box.size.height <= 0) {
      return 1;
    }
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final view = viewport.localToGlobal(Offset.zero) & viewport.size;
    final overlap = rect.intersect(view);
    if (overlap.width <= 0 || overlap.height <= 0) return 0;
    return overlap.height / rect.height;
  }

  Future<void> start({bool auto = false}) async {
    final previous = _active;
    if (previous != null && !identical(previous, this)) previous.release();
    _active = this;
    final token = ++attempt;
    setState(() {
      loading = true;
      failed = false;
      userPaused = false;
      muted = auto;
    });
    VideoPlayerController? controller;
    try {
      final uri = Uri.parse(
        await articleMediaURL(
          widget.store,
          fileID,
          articleID: widget.articleID,
        ),
      );
      if (!mounted || token != attempt) return;
      controller = FeedVideo.createController(uri);
      setState(() => player = controller);
      await controller.initialize();
      if (!mounted || token != attempt) return;
      await controller.setLooping(true);
      await controller.setVolume(auto ? 0 : 1);
      if (!mounted || token != attempt) return;
      // Covered or scrolled away while loading: stay ready but still.
      if (auto && (!canAutoplay || visibleFraction() < 0.3)) {
        setState(() => loading = false);
        return;
      }
      await controller.play();
      if (mounted && token == attempt) setState(() => loading = false);
    } catch (_) {
      if (!mounted || token != attempt) return;
      if (identical(player, controller)) player = null;
      controller?.dispose();
      if (identical(_active, this)) _active = null;
      setState(() {
        loading = false;
        failed = true;
      });
    }
  }

  Future<void> setMuted(VideoPlayerController controller, bool value) async {
    setState(() => muted = value);
    await controller.setVolume(value ? 0 : 1);
  }

  /// A tap on a muted autoplaying video turns the sound on; otherwise it
  /// pauses or plays.
  Future<void> toggle(VideoPlayerController controller) async {
    final value = controller.value;
    if (value.isPlaying && muted) {
      await setMuted(controller, false);
      return;
    }
    if (value.isPlaying) {
      userPaused = true;
      await controller.pause();
      return;
    }
    userPaused = false;
    if (value.isCompleted) await controller.seekTo(Duration.zero);
    if (mounted && identical(controller, player)) await controller.play();
  }

  @override
  Widget build(BuildContext context) => switch (widget.onOpen) {
    final open? => cell(open),
    null => lone(),
  };

  Widget lone() => LayoutBuilder(
    builder: (context, constraints) {
      final controller = player;
      final ready = controller != null && controller.value.isInitialized;
      final ratio = ready && controller.value.aspectRatio > 0
          ? controller.value.aspectRatio
          : declaredRatio ?? 16 / 9;
      final size = loneMediaSize(
        constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0,
        ratio,
      );
      return Align(
        alignment: Alignment.centerLeft,
        child: ClipRRect(
          key: ValueKey('feed-video-$fileID'),
          borderRadius: BorderRadius.circular(10),
          child: SizedBox.fromSize(
            size: size,
            child: ColoredBox(
              color: Colors.black,
              child: ready
                  ? ArticleVideoControls(
                      controller: controller,
                      onToggle: () => toggle(controller),
                      // A narrow box has no room for the clock.
                      showTime: size.width >= 220,
                      cover: true,
                      muted: muted,
                      onToggleMute: () => setMuted(controller, !muted),
                    )
                  : placeholder(),
            ),
          ),
        ),
      );
    },
  );

  /// A square of the post's grid: the muted picture while it autoplays,
  /// otherwise a play mark, and the clip's length either way.
  Widget cell(VoidCallback open) {
    final controller = player;
    final ready = controller != null && controller.value.isInitialized;
    final duration = declaredDuration;
    const mark = Icon(Icons.play_circle_outline, size: 34, color: Colors.white);
    return Semantics(
      button: true,
      label: '播放视频',
      child: GestureDetector(
        key: ValueKey('feed-video-play-$fileID'),
        behavior: HitTestBehavior.opaque,
        onTap: open,
        child: ClipRRect(
          key: ValueKey('feed-video-$fileID'),
          borderRadius: BorderRadius.circular(6),
          child: ColoredBox(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (ready) ...[
                  videoPicture(controller, cover: true),
                  ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: controller,
                    builder: (context, value, _) => value.isPlaying
                        ? const SizedBox.shrink()
                        : const Center(child: mark),
                  ),
                ] else ...[
                  const _Backdrop(),
                  Center(
                    child: loading
                        ? const SizedBox.square(
                            dimension: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : mark,
                  ),
                ],
                if (duration != null && widget.more == 0)
                  Positioned(right: 6, bottom: 6, child: _LengthTag(duration)),
                if (widget.more > 0) FeedMoreCount(widget.more),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget placeholder() {
    final duration = declaredDuration;
    // The whole frame is the play button, so a tap on the video never falls
    // through to the card and opens the post instead.
    return Semantics(
      button: !loading && !failed,
      label: loading ? '视频加载中' : '播放视频',
      child: GestureDetector(
        key: ValueKey('feed-video-play-$fileID'),
        behavior: HitTestBehavior.opaque,
        onTap: loading || failed ? () {} : start,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _Backdrop(),
            Center(
              child: failed
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      child: TextButton.icon(
                        key: const ValueKey('feed-video-retry'),
                        onPressed: start,
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        label: const Text(
                          '视频加载失败，重试',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                  : loading
                  ? const SizedBox.square(
                      dimension: 36,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.85),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
            ),
            if (duration != null)
              Positioned(right: 8, bottom: 8, child: _LengthTag(duration)),
          ],
        ),
      ),
    );
  }
}

/// What stands in for a video's picture before it has one.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2A2F36), Color(0xFF0E1013)],
      ),
    ),
  );
}

class _LengthTag extends StatelessWidget {
  const _LengthTag(this.length);
  final Duration length;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      videoClock(length),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    ),
  );
}
