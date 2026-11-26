import 'package:flutter/material.dart';

import 'api/bojian_api.dart';
import 'article_media_picker.dart';
import 'article_video_player.dart';
import 'app_store.dart';
import 'design.dart';
import 'network_image_cache.dart';
import 'photo_format.dart';
import 'resume_importer.dart' show ResumeUpload, uploadResumeDocument;

Future<List<Map<String, dynamic>>> pickArticlePhotos(
  BuildContext context,
  AppStore store, {
  int? limit,
}) async {
  final epoch = store.epoch;
  final files = await openPage<List<PickedArticleMedia>>(
    context,
    ArticleMediaPicker(limit: limit),
  );
  if (!context.mounted || files == null || files.isEmpty) return [];
  final blocks = <Map<String, dynamic>>[];
  for (final file in files) {
    if (!context.mounted) return [];
    try {
      blocks.add(await uploadArticleMedia(store, file, epoch: epoch));
    } catch (error) {
      if (blocks.isEmpty || store.epoch != epoch || !context.mounted) rethrow;
      toast(context, '已添加 ${blocks.length} 项，其他图片或视频未添加：$error');
      break;
    }
  }
  return blocks;
}

Future<Map<String, dynamic>> uploadArticleMedia(
  AppStore store,
  PickedArticleMedia media, {
  required int epoch,
  ResumeUpload? transfer,
}) async {
  final mime = media.mime;
  final file = await media.fileForUpload();
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
  late Future<String> address;
  late int epoch;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(onAccountChanged);
    load();
  }

  @override
  void didUpdateWidget(ArticlePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(onAccountChanged);
      widget.store.addListener(onAccountChanged);
    }
    if (oldWidget.store != widget.store ||
        oldWidget.fileID != widget.fileID ||
        oldWidget.articleID != widget.articleID) {
      load();
    }
  }

  void onAccountChanged() {
    if (widget.store.epoch != epoch) setState(load);
  }

  void load() {
    epoch = widget.store.epoch;
    address = widget.store
        .request(
          'GetFilesIdArticleMedia',
          path: {'id': '${widget.fileID}'},
          query: {
            if ((widget.articleID ?? 0) > 0)
              'article_id': '${widget.articleID}',
          },
          expectedEpoch: epoch,
        )
        .then((response) {
          final url = response.data['url'];
          final uri = url is String ? Uri.tryParse(url) : null;
          if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
            throw const ApiFailure('媒体地址无效');
          }
          return uri.toString();
        });
  }

  @override
  void dispose() {
    widget.store.removeListener(onAccountChanged);
    super.dispose();
  }

  Widget retry() => Center(
    child: TextButton.icon(
      onPressed: () => setState(load),
      icon: const Icon(Icons.refresh, size: 16),
      label: Text(widget.video ? '视频加载失败，重试' : '图片加载失败，重试'),
    ),
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: address,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const SizedBox(height: 100, child: SkeletonFill(radius: 8));
      }
      if (!snapshot.hasData) return retry();
      final url = snapshot.requireData;
      if (widget.video) {
        return ArticleVideoPlayer(source: url, onRetry: () => setState(load));
      }
      return ArticleNetworkPhoto(
        url: url,
        watermark: widget.watermark,
        imageProvider: NetworkImage(url),
        onRetry: () => setState(load),
      );
    },
  );
}

class ArticleNetworkPhoto extends StatelessWidget {
  const ArticleNetworkPhoto({
    super.key,
    required this.url,
    this.watermark,
    this.alt,
    this.imageProvider,
    this.onRetry,
  });
  final String url;
  final String? watermark, alt;
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
        imageProvider ?? CachedNetworkImage(url),
        width: zoomed ? 2880 : 1440,
        policy: ResizeImagePolicy.fit,
      ),
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
