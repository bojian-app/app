import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'api/bojian_api.dart';
import 'app_store.dart';
import 'article_video_player.dart';
import 'design.dart';
import 'feed_video.dart';
import 'network_image_cache.dart';

/// The signed addresses of one media file. A large still picture also comes in
/// a [thumbnail] and a [preview] rendition; otherwise both are [url], the
/// file's own.
typedef ArticleMediaAddresses = ({
  String url,
  String thumbnail,
  String preview,
});

/// Where to get a picture at the size wanted, and its [original] in case that
/// rendition cannot be had; empty when [url] is the original.
typedef ArticlePicture = ({String url, String original});

ArticlePicture articlePicture(
  ArticleMediaAddresses media, {
  bool small = false,
}) {
  final url = small ? media.thumbnail : media.preview;
  return (url: url, original: url == media.url ? '' : media.url);
}

final _mediaURLs =
    <String, ({DateTime at, Future<ArticleMediaAddresses> addresses})>{};

/// The signed addresses of a post's media file, shared for a few minutes so
/// cards scrolled back into view reuse the same address and decoded image.
Future<ArticleMediaAddresses> articleMediaAddresses(
  AppStore store,
  int fileID, {
  int articleID = 0,
}) {
  final key = '${store.epoch}:$articleID:$fileID';
  final now = DateTime.now();
  final hit = _mediaURLs[key];
  if (hit != null && now.difference(hit.at) < const Duration(minutes: 5)) {
    return hit.addresses;
  }
  final addresses = store
      .request(
        'GetFilesIdArticleMedia',
        path: {'id': '$fileID'},
        query: {if (articleID > 0) 'article_id': '$articleID'},
        expectedEpoch: store.epoch,
      )
      .then((response) {
        String? checked(Object? value) {
          final uri = value is String ? Uri.tryParse(value) : null;
          return uri == null || uri.scheme != 'https' || uri.host.isEmpty
              ? null
              : uri.toString();
        }

        final url = checked(response.data['url']);
        if (url == null) throw const ApiFailure('媒体地址无效');
        // A small original comes with fewer renditions, or none.
        final preview = checked(response.data['preview_url']) ?? url;
        return (
          url: url,
          thumbnail: checked(response.data['thumbnail_url']) ?? preview,
          preview: preview,
        );
      });
  _mediaURLs.remove(key);
  _mediaURLs[key] = (at: now, addresses: addresses);
  // A failed request is asked again next time instead of being remembered.
  addresses.then<void>(
    (_) {},
    onError: (_) {
      if (identical(_mediaURLs[key]?.addresses, addresses)) {
        _mediaURLs.remove(key);
      }
    },
  );
  while (_mediaURLs.length > 300) {
    _mediaURLs.remove(_mediaURLs.keys.first);
  }
  return addresses;
}

/// The address of the file itself, as a video is played from.
Future<String> articleMediaURL(
  AppStore store,
  int fileID, {
  int articleID = 0,
}) => articleMediaAddresses(
  store,
  fileID,
  articleID: articleID,
).then((media) => media.url);

/// Drops a remembered address, after a picture failed to load from it.
void forgetArticleMediaURL(AppStore store, int fileID, {int articleID = 0}) =>
    _mediaURLs.remove('${store.epoch}:$articleID:$fileID');

@visibleForTesting
void clearArticleMediaURLs() => _mediaURLs.clear();

/// One picture or video of a post. A picture is an uploaded file or an older
/// post's direct link; a video is always an uploaded file.
class FeedMedia {
  const FeedMedia({this.fileID = 0, this.url = '', this.alt = '', this.video});

  factory FeedMedia.image(Map data) => FeedMedia(
    fileID: integer(data['file_id']),
    url: '${data['url'] ?? ''}'.trim(),
    alt: '${data['alt'] ?? data['caption'] ?? ''}'.trim(),
  );

  factory FeedMedia.video(Map<String, dynamic> data) =>
      FeedMedia(fileID: integer(data['file_id']), video: data);

  final int fileID;
  final String url, alt;

  /// The block's `video` map, absent for a picture.
  final Map<String, dynamic>? video;

  String get id => fileID > 0 ? 'f$fileID' : url;

  Future<String> address(AppStore store, int articleID) => fileID > 0
      ? articleMediaURL(store, fileID, articleID: articleID)
      : Future.value(url);

  /// This picture to look at, or [small] for a grid cell.
  Future<ArticlePicture> picture(
    AppStore store,
    int articleID, {
    bool small = false,
  }) => fileID > 0
      ? articleMediaAddresses(
          store,
          fileID,
          articleID: articleID,
        ).then((media) => articlePicture(media, small: small))
      : Future.value((url: url, original: ''));
}

/// The box of a post's only picture or video, [ratio] being its width over its
/// height, kept as modest as a chat photo: square and tall ones stand 0.62 of
/// the card's width high, wider ones grow sideways from that, up to the full
/// width. Extreme shapes are cropped to fit.
Size loneMediaSize(double width, double ratio) {
  final shape = ratio.clamp(0.75, 2.0);
  final side = width * 0.62;
  final boxWidth = shape >= 1 ? math.min(width, side * shape) : side * shape;
  return Size(boxWidth, math.min(boxWidth / shape, 320));
}

/// A post's pictures and videos on its feed card: one at its own shape,
/// several in a grid of up to nine, in the author's order. A tap opens them
/// full screen.
class FeedGallery extends StatelessWidget {
  const FeedGallery({
    super.key,
    required this.store,
    required this.media,
    this.articleID = 0,
    this.watermark,
  });

  final AppStore store;
  final List<FeedMedia> media;
  final int articleID;
  final String? watermark;

  static const gap = 4.0;
  static const shown = 9;

  /// Kept on the device under the file's own name, so a picture seen once is
  /// not downloaded again under its next signed address.
  @visibleForTesting
  static ImageProvider Function(String url, [String original]) imageFor =
      _cached;

  static ImageProvider _cached(String url, [String original = '']) =>
      CachedNetworkImage(url, fallback: original);

  void open(BuildContext context, int index) => openPage<void>(
    context,
    FeedMediaViewer(
      store: store,
      media: media,
      articleID: articleID,
      initial: index,
      watermark: watermark,
    ),
  );

  Widget tile(BuildContext context, int index, {double? single, int more = 0}) {
    final item = media[index];
    return _PhotoTile(
      key: ValueKey('feed-photo-${item.id}'),
      store: store,
      photo: item,
      articleID: articleID,
      single: single,
      more: more,
      watermark: single == null ? null : watermark,
      onTap: () => open(context, index),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : 320.0;
      if (media.length == 1) {
        final video = media.first.video;
        return video == null
            ? tile(context, 0, single: width)
            // A lone video plays on the card itself.
            : FeedVideo(store: store, video: video, articleID: articleID);
      }
      final columns = media.length == 2 || media.length == 4 ? 2 : 3;
      final cell = (width - gap * (columns - 1)) / columns;
      final count = math.min(media.length, shown);
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (var i = 0; i < count; i++)
            SizedBox.square(
              dimension: cell,
              child: cellAt(
                context,
                i,
                more: i == count - 1 ? media.length - count : 0,
              ),
            ),
        ],
      );
    },
  );

  Widget cellAt(BuildContext context, int index, {required int more}) {
    final video = media[index].video;
    if (video == null) return tile(context, index, more: more);
    return FeedVideo(
      key: ValueKey('feed-clip-${media[index].fileID}'),
      store: store,
      video: video,
      articleID: articleID,
      more: more,
      onOpen: () => open(context, index),
    );
  }
}

/// The count over a grid's last cell of what the grid leaves out.
class FeedMoreCount extends StatelessWidget {
  const FeedMoreCount(this.count, {super.key});
  final int count;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black.withValues(alpha: 0.45),
    child: Center(
      child: Text(
        '+$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _PhotoTile extends StatefulWidget {
  const _PhotoTile({
    super.key,
    required this.store,
    required this.photo,
    required this.articleID,
    required this.onTap,
    this.single,
    this.more = 0,
    this.watermark,
  });

  final AppStore store;
  final FeedMedia photo;
  final int articleID;
  final VoidCallback onTap;

  /// The card width when this is a post's only picture; it then sizes itself
  /// to the picture's shape.
  final double? single;
  final int more;
  final String? watermark;

  @override
  State<_PhotoTile> createState() => _PhotoTileState();
}

class _PhotoTileState extends State<_PhotoTile> {
  late Future<ArticlePicture> address;
  ImageStream? stream;
  ImageStreamListener? listener;
  ImageProvider? provider;
  double? ratio;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(_PhotoTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo.id != widget.photo.id ||
        oldWidget.articleID != widget.articleID ||
        oldWidget.store != widget.store) {
      ratio = null;
      load();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (provider != null) watch();
  }

  void load() {
    failed = false;
    provider = null;
    final requested = address = widget.photo.picture(
      widget.store,
      widget.articleID,
      small: widget.single == null,
    );
    requested.then(
      (picture) {
        if (!mounted || !identical(requested, address)) return;
        setState(() => provider = decode(picture));
        watch();
      },
      onError: (_) {
        if (mounted && identical(requested, address)) {
          setState(() => failed = true);
        }
      },
    );
  }

  ImageProvider decode(ArticlePicture picture) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final logical = widget.single ?? 160.0;
    // Grid cells crop to a square, so wide pictures need room to spare.
    final pixels = (logical * dpr * (widget.single == null ? 2 : 1))
        .clamp(200, 1440)
        .round();
    return ResizeImage(
      FeedGallery.imageFor(picture.url, picture.original),
      width: pixels,
      policy: ResizeImagePolicy.fit,
    );
  }

  /// Follows the picture's loading for its shape and for failures.
  void watch() {
    final next = provider?.resolve(createLocalImageConfiguration(context));
    if (next == null || next.key == stream?.key) return;
    unwatch();
    listener = ImageStreamListener(
      (info, _) {
        final size = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
        info.dispose();
        if (mounted && size.height > 0 && widget.single != null) {
          setState(() => ratio = size.width / size.height);
        }
      },
      onError: (_, _) {
        if (mounted) setState(() => failed = true);
      },
    );
    stream = next..addListener(listener!);
  }

  void unwatch() {
    if (listener != null) stream?.removeListener(listener!);
    stream = null;
    listener = null;
  }

  @override
  void dispose() {
    unwatch();
    super.dispose();
  }

  void retry() {
    unwatch();
    final image = provider;
    if (image != null) image.evict();
    forgetArticleMediaURL(
      widget.store,
      widget.photo.fileID,
      articleID: widget.articleID,
    );
    setState(load);
  }

  @override
  Widget build(BuildContext context) {
    final image = provider;
    Widget child;
    if (failed) {
      child = ColoredBox(
        color: context.colors.inset,
        child: Center(
          child: Icon(
            Icons.refresh_rounded,
            size: 22,
            color: context.colors.muted,
          ),
        ),
      );
    } else if (image == null) {
      child = const SkeletonFill();
    } else {
      child = Image(
        image: image,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        semanticLabel: widget.photo.alt.isEmpty ? '动态图片' : widget.photo.alt,
        frameBuilder: (context, child, frame, synchronous) =>
            frame == null && !synchronous ? const SkeletonFill() : child,
        errorBuilder: (context, _, _) => ColoredBox(
          color: context.colors.inset,
          child: Center(
            child: Icon(
              Icons.refresh_rounded,
              size: 22,
              color: context.colors.muted,
            ),
          ),
        ),
      );
    }
    final label = widget.watermark?.trim() ?? '';
    final tile = ClipRRect(
      borderRadius: BorderRadius.circular(widget.single == null ? 6 : 10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (widget.more > 0) FeedMoreCount(widget.more),
          if (label.isNotEmpty && image != null && !failed)
            Positioned(
              right: 8,
              bottom: 6,
              left: 8,
              child: Text(
                label,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black87)],
                ),
              ),
            ),
        ],
      ),
    );
    final tappable = Semantics(
      button: true,
      label: failed ? '图片加载失败，重试' : '查看图片',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: failed ? retry : widget.onTap,
        child: tile,
      ),
    );
    final width = widget.single;
    if (width == null) return tappable;
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox.fromSize(
        size: loneMediaSize(width, ratio ?? 4 / 3),
        child: tappable,
      ),
    );
  }
}

/// A post's pictures and videos full screen, swiped through; pictures zoom.
class FeedMediaViewer extends StatefulWidget {
  const FeedMediaViewer({
    super.key,
    required this.store,
    required this.media,
    this.articleID = 0,
    this.initial = 0,
    this.watermark,
  });

  final AppStore store;
  final List<FeedMedia> media;
  final int articleID, initial;
  final String? watermark;

  @override
  State<FeedMediaViewer> createState() => _FeedMediaViewerState();
}

class _FeedMediaViewerState extends State<FeedMediaViewer> {
  late final pages = PageController(initialPage: widget.initial);
  late int index = widget.initial;

  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: widget.media.length > 1
          ? Text(
              '${index + 1}/${widget.media.length}',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            )
          : null,
      centerTitle: true,
    ),
    body: PageView.builder(
      controller: pages,
      itemCount: widget.media.length,
      onPageChanged: (value) => setState(() => index = value),
      itemBuilder: (context, i) => widget.media[i].video != null
          ? SafeArea(
              top: false,
              child: _ClipPage(
                key: ValueKey('viewer-clip-$i'),
                store: widget.store,
                clip: widget.media[i],
                articleID: widget.articleID,
                active: i == index,
              ),
            )
          : _ViewerPage(
              store: widget.store,
              photo: widget.media[i],
              articleID: widget.articleID,
              watermark: widget.watermark,
            ),
    ),
  );
}

/// One video of the viewer: it plays with sound while it is the page on show.
class _ClipPage extends StatefulWidget {
  const _ClipPage({
    super.key,
    required this.store,
    required this.clip,
    required this.articleID,
    required this.active,
  });

  final AppStore store;
  final FeedMedia clip;
  final int articleID;
  final bool active;

  @override
  State<_ClipPage> createState() => _ClipPageState();
}

class _ClipPageState extends State<_ClipPage> with WidgetsBindingObserver {
  VideoPlayerController? player;
  bool failed = false;
  int attempt = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.active) load();
  }

  @override
  void didUpdateWidget(_ClipPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active == widget.active) return;
    if (!widget.active) {
      player?.pause();
    } else if (player == null) {
      load();
    } else if (player!.value.isInitialized) {
      player!.play();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) player?.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    attempt++;
    player?.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final token = ++attempt;
    player?.dispose();
    player = null;
    if (failed) setState(() => failed = false);
    VideoPlayerController? controller;
    try {
      final url = await widget.clip.address(widget.store, widget.articleID);
      if (!mounted || token != attempt) return;
      controller = FeedVideo.createController(Uri.parse(url));
      setState(() => player = controller);
      await controller.initialize();
      if (!mounted || token != attempt) return;
      if (widget.active) await controller.play();
      if (mounted && token == attempt) setState(() {});
    } catch (_) {
      if (!mounted || token != attempt) return;
      player = null;
      controller?.dispose();
      setState(() => failed = true);
    }
  }

  Future<void> toggle(VideoPlayerController controller) async {
    final value = controller.value;
    if (value.isPlaying) return controller.pause();
    if (value.isCompleted) await controller.seekTo(Duration.zero);
    if (mounted && identical(controller, player)) await controller.play();
  }

  @override
  Widget build(BuildContext context) {
    final controller = player;
    if (failed) {
      return Center(
        child: TextButton.icon(
          onPressed: load,
          icon: const Icon(Icons.refresh, color: Colors.white),
          label: const Text('视频加载失败，重试', style: TextStyle(color: Colors.white)),
        ),
      );
    }
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    final ratio = controller.value.aspectRatio;
    return Center(
      child: AspectRatio(
        aspectRatio: ratio > 0 ? ratio : 16 / 9,
        child: ArticleVideoControls(
          controller: controller,
          onToggle: () => toggle(controller),
          showTime: true,
        ),
      ),
    );
  }
}

class _ViewerPage extends StatefulWidget {
  const _ViewerPage({
    required this.store,
    required this.photo,
    required this.articleID,
    this.watermark,
  });

  final AppStore store;
  final FeedMedia photo;
  final int articleID;
  final String? watermark;

  @override
  State<_ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<_ViewerPage> {
  late Future<ArticlePicture> address = widget.photo.picture(
    widget.store,
    widget.articleID,
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<ArticlePicture>(
    future: address,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      }
      final retry = Center(
        child: TextButton.icon(
          // The new request must not be what setState's callback returns.
          onPressed: () => setState(() {
            forgetArticleMediaURL(
              widget.store,
              widget.photo.fileID,
              articleID: widget.articleID,
            );
            address = widget.photo.picture(widget.store, widget.articleID);
          }),
          icon: const Icon(Icons.refresh, color: Colors.white),
          label: const Text('图片加载失败，重试', style: TextStyle(color: Colors.white)),
        ),
      );
      if (!snapshot.hasData) return retry;
      final label = widget.watermark?.trim() ?? '';
      return InteractiveViewer(
        maxScale: 5,
        child: Center(
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Image(
                image: ResizeImage(
                  FeedGallery.imageFor(
                    snapshot.requireData.url,
                    snapshot.requireData.original,
                  ),
                  width: 2880,
                  policy: ResizeImagePolicy.fit,
                ),
                fit: BoxFit.contain,
                semanticLabel: widget.photo.alt.isEmpty
                    ? '动态图片'
                    : widget.photo.alt,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const SizedBox.square(
                        dimension: 40,
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                errorBuilder: (_, _, _) => retry,
              ),
              if (label.isNotEmpty)
                Positioned(
                  right: 8,
                  bottom: 8,
                  left: 8,
                  child: Text(
                    label,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black87)],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
