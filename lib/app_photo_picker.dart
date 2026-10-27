import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'api/bojian_api.dart';

Future<XFile?> pickAppGalleryPhoto() async {
  final implementation = ImagePickerPlatform.instance;
  if (implementation is ImagePickerAndroid) {
    implementation.useAndroidPhotoPicker = true;
  }
  try {
    return await ImagePicker().pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
  } on PlatformException catch (error) {
    throw ApiFailure(switch (error.code) {
      'photo_access_denied' ||
      'photo_access_denied_without_prompt' ||
      'photo_access_restricted' => '无法选择照片，请在系统设置中允许照片访问',
      _ => '无法打开相册，请稍后重试',
    });
  }
}
