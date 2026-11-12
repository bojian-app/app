import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'api/bojian_api.dart';
import 'app_action_sheet.dart';
import 'app_icons.dart';
import 'app_photo_picker.dart';

typedef CaptureAppPhoto = Future<XFile?> Function(ImageSource source);

Future<XFile?> pickAppPhoto(
  BuildContext context, {
  CaptureAppPhoto? capture,
  bool Function()? isCurrent,
}) async {
  final source = await showAppListSheet<ImageSource>(
    context,
    sheet: const AppListSheet(
      key: ValueKey('photo-source-sheet'),
      caption: '选择照片',
      cancelKey: ValueKey('photo-source-cancel'),
      items: [
        AppListSheetItem(
          label: '拍照',
          key: ValueKey('photo-source-camera'),
          value: ImageSource.camera,
          icon: AppIcons.camera,
        ),
        AppListSheetItem(
          label: '从相册选择',
          key: ValueKey('photo-source-gallery'),
          value: ImageSource.gallery,
          icon: AppIcons.avatarUpload,
        ),
      ],
    ),
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
