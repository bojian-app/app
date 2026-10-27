import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'api/bojian_api.dart';
import 'app_icons.dart';
import 'app_photo_picker.dart';
import 'design.dart';

typedef CaptureAppPhoto = Future<XFile?> Function(ImageSource source);

Future<XFile?> pickAppPhoto(
  BuildContext context, {
  CaptureAppPhoto? capture,
  bool Function()? isCurrent,
}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .3),
    builder: (context) => const _PhotoSourceSheet(),
  );
  if (source == null || !context.mounted || isCurrent?.call() == false) {
    return null;
  }
  try {
    return await (capture ?? _capturePhoto)(source);
  } on PlatformException catch (error) {
    throw ApiFailure(switch (error.code) {
      'camera_access_denied' ||
      'camera_access_denied_without_prompt' ||
      'camera_access_restricted' => '无法使用相机，请在系统设置中允许相机访问',
      'photo_access_denied' ||
      'photo_access_denied_without_prompt' ||
      'photo_access_restricted' => '无法选择照片，请在系统设置中允许照片访问',
      _ => '无法打开${source == ImageSource.camera ? '相机' : '相册'}，请稍后重试',
    });
  } on UnsupportedError {
    throw const ApiFailure('当前设备不支持拍照，请从相册选择');
  }
}

Future<XFile?> _capturePhoto(ImageSource source) =>
    source == ImageSource.gallery
    ? pickAppGalleryPhoto()
    : ImagePicker().pickImage(source: source, requestFullMetadata: false);

class _PhotoSourceSheet extends StatelessWidget {
  const _PhotoSourceSheet();

  @override
  Widget build(BuildContext context) {
    Widget action(
      String label,
      String key,
      ImageSource? source,
      AppIconData? icon,
    ) => TextButton(
      key: ValueKey(key),
      style: TextButton.styleFrom(
        foregroundColor: context.colors.ink,
        minimumSize: const Size.fromHeight(58),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        shape: const RoundedRectangleBorder(),
      ).withoutHover(),
      onPressed: () => Navigator.of(context).pop(source),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            AppIcon(icon, size: 22, color: context.colors.accent),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );

    return Material(
      key: const ValueKey('photo-source-sheet'),
      color: context.colors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
                      child: Text(
                        '选择照片',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.muted,
                        ),
                      ),
                    ),
                    action(
                      '拍照',
                      'photo-source-camera',
                      ImageSource.camera,
                      AppIcons.camera,
                    ),
                    Divider(
                      height: 1,
                      thickness: .5,
                      color: context.colors.border,
                    ),
                    action(
                      '从相册选择',
                      'photo-source-gallery',
                      ImageSource.gallery,
                      AppIcons.avatarUpload,
                    ),
                  ],
                ),
              ),
            ),
            ColoredBox(
              color: context.colors.canvas,
              child: const SizedBox(height: 8),
            ),
            action('取消', 'photo-source-cancel', null, null),
          ],
        ),
      ),
    );
  }
}
