import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Creates a decoder only after the user presses play.
class ArticleVideoPlayer extends StatefulWidget {
  const ArticleVideoPlayer({
    super.key,
    required this.source,
    this.local = false,
    this.onRetry,
  });

  final String source;
  final bool local;
  final VoidCallback? onRetry;

  @override
  State<ArticleVideoPlayer> createState() => _ArticleVideoPlayerState();
}

class _ArticleVideoPlayerState extends State<ArticleVideoPlayer> {
  VideoPlayerController? player;
  bool failed = false;

  @override
  void didUpdateWidget(ArticleVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source || oldWidget.local != widget.local) {
      player?.dispose();
      player = null;
      failed = false;
    }
  }

  Future<void> play() async {
    final controller = widget.local
        ? VideoPlayerController.file(File(widget.source))
        : VideoPlayerController.networkUrl(Uri.parse(widget.source));
    setState(() {
      player = controller;
      failed = false;
    });
    try {
      await controller.initialize();
      if (mounted && controller == player) await controller.play();
    } catch (_) {
      if (mounted && controller == player) setState(() => failed = true);
    }
  }

  Future<void> toggle(VideoPlayerController controller) async {
    final value = controller.value;
    if (value.isPlaying) {
      await controller.pause();
      return;
    }
    if (value.isCompleted) await controller.seekTo(Duration.zero);
    if (mounted && controller == player) await controller.play();
  }

  @override
  void dispose() {
    player?.dispose();
    super.dispose();
  }

  Widget retry() => TextButton.icon(
    onPressed: () {
      player?.dispose();
      setState(() {
        player = null;
        failed = false;
      });
      if (widget.onRetry != null) {
        widget.onRetry!();
      } else {
        play();
      }
    },
    icon: const Icon(Icons.refresh, color: Colors.white),
    label: const Text('视频加载失败，重试', style: TextStyle(color: Colors.white)),
  );

  @override
  Widget build(BuildContext context) {
    final controller = player;
    final start = IconButton(
      tooltip: '播放视频',
      onPressed: play,
      icon: const Icon(
        Icons.play_circle_outline,
        color: Colors.white,
        size: 48,
      ),
    );
    return ColoredBox(
      color: Colors.black,
      child: controller == null
          ? AspectRatio(
              aspectRatio: 16 / 9,
              child: Center(child: start),
            )
          : ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller,
              builder: (context, value, _) => AspectRatio(
                aspectRatio: value.isInitialized ? value.aspectRatio : 16 / 9,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (failed || value.hasError)
                      retry()
                    else if (!value.isInitialized)
                      const CircularProgressIndicator(color: Colors.white)
                    else
                      Positioned.fill(
                        child: ArticleVideoControls(
                          controller: controller,
                          onToggle: () => toggle(controller),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

String videoClock(Duration value) {
  final seconds = value.inSeconds;
  String two(int n) => n.toString().padLeft(2, '0');
  final hours = seconds ~/ 3600;
  final clock = '${two(seconds ~/ 60 % 60)}:${two(seconds % 60)}';
  return hours > 0 ? '$hours:$clock' : clock;
}

/// The frames of an initialised [controller], filling their box. With [cover]
/// they keep their shape and are cropped to it instead of being stretched.
Widget videoPicture(VideoPlayerController controller, {bool cover = false}) {
  final size = controller.value.size;
  if (!cover || size.isEmpty) return VideoPlayer(controller);
  return FittedBox(
    fit: BoxFit.cover,
    clipBehavior: Clip.hardEdge,
    child: SizedBox.fromSize(size: size, child: VideoPlayer(controller)),
  );
}

/// The picture of an initialised [controller] with tap-to-pause, a centred
/// play icon while paused and a scrubbable progress bar.
class ArticleVideoControls extends StatelessWidget {
  const ArticleVideoControls({
    super.key,
    required this.controller,
    required this.onToggle,
    this.showTime = false,
    this.muted = false,
    this.onToggleMute,
    this.cover = false,
  });

  final VideoPlayerController controller;
  final VoidCallback onToggle;
  final bool showTime, cover;

  /// Shows a sound button when [onToggleMute] is given.
  final bool muted;
  final VoidCallback? onToggleMute;

  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<VideoPlayerValue>(
    valueListenable: controller,
    builder: (context, value, _) => Stack(
      children: [
        Positioned.fill(child: videoPicture(controller, cover: cover)),
        Positioned.fill(
          child: Semantics(
            button: true,
            label: !value.isPlaying
                ? '播放视频'
                : onToggleMute != null && muted
                ? '打开声音'
                : '暂停视频',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: value.isPlaying
                  ? null
                  : const Center(
                      child: Icon(
                        Icons.play_circle_outline,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
        Positioned(
          left: 8,
          right: 8,
          bottom: 4,
          child: Row(
            children: [
              Expanded(
                child: VideoProgressIndicator(
                  controller,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              if (showTime) ...[
                const SizedBox(width: 8),
                Text(
                  '${videoClock(value.position)} / ${videoClock(value.duration)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontFeatures: [FontFeature.tabularFigures()],
                    shadows: [Shadow(blurRadius: 3, color: Colors.black54)],
                  ),
                ),
              ],
              if (onToggleMute != null)
                IconButton(
                  key: const ValueKey('video-sound'),
                  tooltip: muted ? '打开声音' : '关闭声音',
                  onPressed: onToggleMute,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 20,
                    shadows: const [
                      Shadow(blurRadius: 3, color: Colors.black54),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
