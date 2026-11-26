import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:video_player/video_player.dart';

import 'api/bojian_api.dart';
import 'article_video_player.dart';
import 'article_high_efficiency_photo.dart';
import 'photo_format.dart';
import 'design.dart';
import 'resume_photo.dart';

const maxArticleVideoDuration = Duration(minutes: 5);
const maxArticlePhotoBytes = 20 << 20;

class PickedArticleMedia {
  const PickedArticleMedia(
    this.file,
    this.mime, {
    this.duration,
    this.convertToPng = false,
  });
  final XFile file;
  final String mime;
  final Duration? duration;
  final bool convertToPng;

  Future<XFile> fileForUpload() async => convertToPng
      ? articlePhotoAsPng(file, maxBytes: maxArticlePhotoBytes)
      : file;
  bool get isVideo => duration != null;
}

Future<PickedArticleMedia> checkArticleMedia(XFile file) async {
  final size = await file.length();
  final prefix = await file
      .openRead(0, size.clamp(0, 256))
      .expand((chunk) => chunk)
      .toList();
  if (isHighEfficiencyPhoto(prefix)) {
    if (size > maxArticlePhotoBytes) throw const ApiFailure('照片不能超过 20 MB');
    await checkPhotoDecodes(await file.readAsBytes());
    // Keep the original for previews and encode one photo at a time during upload.
    return PickedArticleMedia(file, 'image/png', convertToPng: true);
  }
  final ext = file.name.split('.').last.toLowerCase();
  final videoType = switch (ext) {
    'mp4' || 'm4v' => 'video/mp4',
    'mov' => 'video/quicktime',
    'webm' => 'video/webm',
    '3gp' => 'video/3gpp',
    _ => null,
  };
  if (videoType == null || photoMimeFromBytes(prefix) != null) {
    return PickedArticleMedia(
      file,
      await validatePickedPhoto(
        file,
        maxBytes: maxArticlePhotoBytes,
        allowGif: true,
      ),
    );
  }
  if (size <= 0 || size > 512 << 20) {
    throw const ApiFailure('视频不能为空，且不能超过 512 MB');
  }
  final player = VideoPlayerController.file(File(file.path));
  late Duration duration;
  try {
    await player.initialize();
    duration = player.value.duration;
  } catch (_) {
    throw const ApiFailure('无法读取这个视频，请重新选择');
  } finally {
    await player.dispose();
  }
  if (duration <= Duration.zero || duration > maxArticleVideoDuration) {
    throw const ApiFailure('请选择时长大于 0 秒且不超过 5 分钟的视频');
  }
  return PickedArticleMedia(file, videoType, duration: duration);
}

class ArticleMediaPicker extends StatefulWidget {
  const ArticleMediaPicker({super.key, this.limit});
  final int? limit;
  @override
  State<ArticleMediaPicker> createState() => _ArticleMediaPickerState();
}

enum _Source { gallery, photo, video }

class _ArticleMediaPickerState extends State<ArticleMediaPicker> {
  final selected = <PickedArticleMedia>[];
  bool picking = false;

  Future<void> capture() async {
    final mode = await showModalBottomSheet<_Source>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(context, _Source.photo),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('录视频'),
              onTap: () => Navigator.pop(context, _Source.video),
            ),
          ],
        ),
      ),
    );
    if (mounted && mode != null) await pick(mode);
  }

  Future<void> pick(_Source source) async {
    if (picking) return;
    final remaining = widget.limit == null
        ? null
        : widget.limit! - selected.length;
    if (remaining != null && remaining <= 0) {
      toast(context, '最多可添加 ${widget.limit} 个图片或视频');
      return;
    }
    setState(() => picking = true);
    try {
      final implementation = ImagePickerPlatform.instance;
      if (implementation is ImagePickerAndroid) {
        implementation.useAndroidPhotoPicker = true;
      }
      final picker = ImagePicker();
      final List<XFile> files;
      if (source == _Source.gallery) {
        files = await picker.pickMultipleMedia(
          limit: remaining,
          requestFullMetadata: false,
        );
      } else {
        final captured = source == _Source.video
            ? await picker.pickVideo(
                source: ImageSource.camera,
                maxDuration: maxArticleVideoDuration,
              )
            : await picker.pickImage(
                source: ImageSource.camera,
                requestFullMetadata: false,
              );
        files = [?captured];
      }
      if (!mounted) return;
      if (remaining != null && files.length > remaining) {
        throw ApiFailure('还可添加 $remaining 个图片或视频，请重新选择');
      }
      String? error;
      for (final file in files) {
        if (!mounted) return;
        if (selected.any((item) => item.file.path == file.path)) continue;
        try {
          final item = await checkArticleMedia(file);
          if (mounted) setState(() => selected.add(item));
        } catch (e) {
          error = e.toString();
        }
      }
      if (mounted && error != null) toast(context, error);
    } on PlatformException catch (e) {
      if (mounted) {
        toast(
          context,
          e.code.contains('denied') ? '请在系统设置中允许相机或相册访问' : '无法打开相机或相册，请重试',
        );
      }
    } catch (error) {
      if (mounted) toast(context, error.toString());
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> preview(PickedArticleMedia item) async {
    final remove = await openPage<bool>(
      context,
      Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          actions: [
            Builder(
              builder: (context) => IconButton(
                tooltip: '移除',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => Navigator.pop(context, true),
              ),
            ),
          ],
        ),
        body: Center(
          child: item.isVideo
              ? ArticleVideoPlayer(source: item.file.path, local: true)
              : InteractiveViewer(
                  maxScale: 5,
                  child: Image.file(File(item.file.path)),
                ),
        ),
      ),
    );
    if (mounted && remove == true) setState(() => selected.remove(item));
  }

  Widget sourceTile(String label, IconData icon, VoidCallback action) =>
      Material(
        color: context.colors.inset,
        child: InkWell(
          onTap: picking ? null : action,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28),
              const SizedBox(height: 5),
              Text(label),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('选择图片或视频'),
      actions: [
        IconButton(
          tooltip: '上传说明',
          icon: const Icon(Icons.info_outline_rounded),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('上传说明'),
              content: const Text('上传视频最短不能小于 0 秒钟，最长不能大于5分钟'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('知道了'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
    body: Column(
      children: [
        if (picking) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: 2 + selected.length,
            itemBuilder: (context, index) {
              if (index == 0) {
                return sourceTile('拍摄', Icons.camera_alt_outlined, capture);
              }
              if (index == 1) {
                return sourceTile(
                  '相册',
                  Icons.photo_library_outlined,
                  () => pick(_Source.gallery),
                );
              }
              final item = selected[index - 2];
              return Stack(
                fit: StackFit.expand,
                children: [
                  InkWell(
                    onTap: () => preview(item),
                    child: item.isVideo
                        ? ColoredBox(
                            color: Colors.black87,
                            child: Center(
                              child: Text(
                                '▶  ${item.duration!.inMinutes}:${(item.duration!.inSeconds % 60).toString().padLeft(2, '0')}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          )
                        : Image.file(
                            File(item.file.path),
                            fit: BoxFit.cover,
                            cacheWidth: 224,
                          ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      tooltip: '移除第 ${index - 1} 项',
                      onPressed: picking
                          ? null
                          : () => setState(() => selected.remove(item)),
                      icon: CircleAvatar(
                        radius: 12,
                        backgroundColor: context.colors.accent,
                        child: Text(
                          '${index - 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Align(
          alignment: Alignment.centerRight,
          heightFactor: 1,
          child: FilledButton(
            onPressed: selected.isEmpty || picking
                ? null
                : () => Navigator.pop(context, selected),
            child: Text('下一步(${selected.length})'),
          ),
        ),
      ),
    ),
  );
}
