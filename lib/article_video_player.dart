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
                    else ...[
                      Positioned.fill(child: VideoPlayer(controller)),
                      Positioned.fill(
                        child: Semantics(
                          button: true,
                          label: value.isPlaying ? '暂停视频' : '播放视频',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () async {
                              if (value.isPlaying) {
                                await controller.pause();
                              } else {
                                if (value.isCompleted) {
                                  await controller.seekTo(Duration.zero);
                                }
                                if (mounted && controller == player) {
                                  await controller.play();
                                }
                              }
                            },
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
                        child: VideoProgressIndicator(
                          controller,
                          allowScrubbing: true,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
