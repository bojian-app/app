import 'package:flutter/material.dart';

import 'api/bojian_api.dart';
import 'article_media_picker.dart';
import 'article_video_player.dart';
import 'app_store.dart';
import 'design.dart';
import 'feed_media.dart'
    show
        ArticleMediaAddresses,
        articleMediaAddresses,
        articlePicture,
        forgetArticleMediaURL;
import 'network_image_cache.dart';
import 'photo_format.dart';
import 'resume_importer.dart' show ResumeUpload, uploadResumeDocument;
import 'when_near_viewport.dart';

/// How far an upload of several files has got.
typedef UploadProgress = void Function(int done, int total);

/// How many files go up at once.
const articleUploadsAtOnce = 3;

/// Uploads [files] a few at a time and returns their blocks in the order they
/// were picked. Once one fails no more are started; [error] is that failure.
Future<({List<Map<String, dynamic>> blocks, Object? error})>
uploadArticleMediaFiles(
  List<PickedArticleMedia> files,
  Future<Map<String, dynamic>> Function(PickedArticleMedia) upload, {
  UploadProgress? onProgress,
}) async {
  final blocks = List<Map<String, dynamic>?>.filled(files.length, null);
  Object? error;
  var next = 0, done = 0;
  onProgress?.call(done, files.length);
  Future<void> worker() async {
    while (error == null && next < files.length) {
      final index = next++;
      try {
        blocks[index] = await upload(files[index]);
        onProgress?.call(++done, files.length);
      } catch (failure) {
        error ??= failure;
      }
    }
  }

  await Future.wait([for (var i = 0; i < articleUploadsAtOnce; i++) worker()]);
  return (blocks: [for (final block in blocks) ?block], error: error);
}

Future<List<Map<String, dynamic>>> pickArticlePhotos(
  BuildContext context,
  AppStore store, {
  int? limit,
  UploadProgress? onProgress,
}) async {
  final epoch = store.epoch;
  final files = await openPage<List<PickedArticleMedia>>(
    context,
    ArticleMediaPicker(limit: limit),
  );
  if (!context.mounted || files == null || files.isEmpty) return [];
  final (:blocks, :error) = await uploadArticleMediaFiles(files, (file) {
    // Nothing more is sent for a page that has been closed.
    if (!context.mounted) throw const ApiFailure('已取消上传');
    return uploadArticleMedia(store, file, epoch: epoch);
  }, onProgress: onProgress);
  if (!context.mounted) return [];
  if (error != null) {
    if (blocks.isEmpty || store.epoch != epoch) throw error;
    toast(context, '已添加 ${blocks.length} 项，其他图片或视频未添加：$error');
  }
  return blocks;
}

Future<Map<String, dynamic>> uploadArticleMedia(
  AppStore store,
  PickedArticleMedia media, {
  required int epoch,
  ResumeUpload? transfer,
}) async {
  final (:file, :mime) = await media.forUpload();
  final kind = media.isVideo ? 'video' : 'image';
  final filename = media.isVideo
      ? 'article-video.${file.name.split('.').last.toLowerCase()}'
      : photoUploadName('article-image', mime);
  final session = await store.request(
    'PostFilesUploads',
    expectedEpoch: epoch,
    body: {
      'purpose': 'POST_ASSET',
      'filename': filename,
      'content_type': mime,
      'size_bytes': await file.length(),
    },
  );
  final id = integer(session.data['id']);
  if (id <= 0) throw const ApiFailure('无法上传动态媒体，请重试');
  if (transfer != null) {
    await transfer(session.data, file, mime);
  } else {
    await uploadResumeDocument(
      session.data,
      file,
      mime,
      filename: filename,
      timeout: media.isVideo
          ? const Duration(minutes: 15)
          : const Duration(seconds: 90),
    );
  }
  await store.request(
    'PostFilesUploadsIdComplete',
    path: {'id': '$id'},
    expectedEpoch: epoch,
    body: {},
  );
  // Save only the file reference; every viewer gets their own temporary URL.
  return {
    'kind': kind,
    kind: {
      'file_id': id,
      if (media.duration != null) 'duration_ms': media.duration!.inMilliseconds,
    },
  };
}

class ArticlePhoto extends StatefulWidget {
  const ArticlePhoto({
    super.key,
    required this.store,
    required this.fileID,
    this.articleID,
    this.video = false,
    this.watermark,
  });
  final AppStore store;
  final int fileID;
  final int? articleID;
  final bool video;
  final String? watermark;

  @override
  State<ArticlePhoto> createState() => _ArticlePhotoState();
}

class _ArticlePhotoState extends State<ArticlePhoto> {
  /// Asked for once the reader gets near.
  Future<ArticleMediaAddresses>? address;
  late int epoch = widget.store.epoch;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(onAccountChanged);
  }

  @override
  void didUpdateWidget(ArticlePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(onAccountChanged);
      widget.store.addListener(onAccountChanged);
    }
    if (address != null &&
        (oldWidget.store != widget.store ||
            oldWidget.fileID != widget.fileID ||
            oldWidget.articleID != widget.articleID)) {
      load();
    }
  }

  void onAccountChanged() {
    if (widget.store.epoch == epoch) return;
    epoch = widget.store.epoch;
    if (address != null) setState(load);
  }

  void load() {
    epoch = widget.store.epoch;
    // A picture shares the feed card's address; a video asks for a fresh one,
    // which has all its time left to play in.
    if (widget.video) {
      forgetArticleMediaURL(
        widget.store,
        widget.fileID,
        articleID: widget.articleID ?? 0,
      );
    }
    address = articleMediaAddresses(
      widget.store,
      widget.fileID,
      articleID: widget.articleID ?? 0,
    );
  }

  void reload() => setState(() {
    forgetArticleMediaURL(
      widget.store,
      widget.fileID,
      articleID: widget.articleID ?? 0,
    );
    load();
  });

  @override
  void dispose() {
    widget.store.removeListener(onAccountChanged);
    super.dispose();
  }

  Widget retry() => Center(
    child: TextButton.icon(
      onPressed: reload,
      icon: const Icon(Icons.refresh, size: 16),
      label: Text(widget.video ? '视频加载失败，重试' : '图片加载失败，重试'),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (address == null) {
      return WhenNearViewport(
        onNear: () => setState(load),
        child: const _PhotoPlaceholder(),
      );
    }
    return FutureBuilder<ArticleMediaAddresses>(
      future: address,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _PhotoPlaceholder();
        }
        if (!snapshot.hasData) return retry();
        final media = snapshot.requireData;
        if (widget.video) {
          return ArticleVideoPlayer(source: media.url, onRetry: reload);
        }
        final picture = articlePicture(media);
        return ArticleNetworkPhoto(
          url: picture.url,
          original: picture.original,
          watermark: widget.watermark,
          onRetry: reload,
        );
      },
    );
  }
}

/// Holds a picture's room while it is on its way, at the commonest shape.
class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) =>
      const AspectRatio(aspectRatio: 4 / 3, child: SkeletonFill(radius: 8));
}

class ArticleNetworkPhoto extends StatelessWidget {
  const ArticleNetworkPhoto({
    super.key,
    required this.url,
    this.original = '',
    this.watermark,
    this.alt,
    this.imageProvider,
    this.onRetry,
  });
  final String url;

  /// Used instead when [url], a smaller rendition of it, cannot be had.
  final String original;
  final String? watermark, alt;

  /// Stands in for the picture at [url].
  final ImageProvider? imageProvider;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => openPage<void>(
      context,
      Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: InteractiveViewer(maxScale: 5, child: photo(zoomed: true)),
        ),
      ),
    ),
    child: photo(),
  );

  Widget photo({bool zoomed = false}) {
    final image = Image(
      image: ResizeImage(
        imageProvider ?? CachedNetworkImage(url, fallback: original),
        width: zoomed ? 2880 : 1440,
        policy: ResizeImagePolicy.fit,
      ),
      frameBuilder: (context, child, frame, synchronous) =>
          frame == null && !synchronous && !zoomed
          ? const _PhotoPlaceholder()
          : child,
      semanticLabel: alt == null || alt!.isEmpty ? '动态图片' : alt,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => onRetry == null
          ? Text(alt?.isNotEmpty == true ? alt! : '图片暂时无法显示')
          : Center(
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('图片加载失败，重试'),
              ),
            ),
    );
    final label = watermark?.trim();
    if (label == null || label.isEmpty) return image;
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        image,
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
    );
  }
}
