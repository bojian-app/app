import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image_picker/image_picker.dart';

import 'api/bojian_api.dart';

const _stillPhotoBrands = {
  'heic',
  'heix',
  'heim',
  'heis',
  'mif1',
  'mif2',
  'miaf',
  'avif',
};
const _sequenceBrands = {'hevc', 'hevx', 'hevm', 'hevs', 'msf1', 'avis'};

Iterable<String> _fileBrands(List<int> prefix) sync* {
  final end = math.min(256, prefix.length);
  int uint32(int i) =>
      prefix[i] * 0x1000000 +
      prefix[i + 1] * 0x10000 +
      prefix[i + 2] * 0x100 +
      prefix[i + 3];
  var offset = 0;
  while (offset + 8 <= end) {
    var length = uint32(offset);
    var header = 8;
    if (length == 1) {
      if (offset + 16 > end || uint32(offset + 8) != 0) return;
      length = uint32(offset + 12);
      header = 16;
    } else if (length == 0) {
      length = end - offset;
    }
    if (length < header) return;
    if (String.fromCharCodes(prefix, offset + 4, offset + 8) == 'ftyp') {
      final first = offset + header;
      final last = math.min(offset + length, end);
      if (first + 4 > last) return;
      yield String.fromCharCodes(prefix, first, first + 4);
      // The four bytes immediately after the major brand are a version number.
      for (var i = first + 8; i + 4 <= last; i += 4) {
        yield String.fromCharCodes(prefix, i, i + 4);
      }
      return;
    }
    offset += length;
  }
}

bool isHighEfficiencyPhoto(List<int> prefix) => _fileBrands(prefix).any(
  (brand) =>
      _stillPhotoBrands.contains(brand) || _sequenceBrands.contains(brand),
);

Future<XFile> articlePhotoAsPng(XFile file, {required int maxBytes}) async {
  final size = await file.length();
  if (size <= 0 || size > maxBytes) {
    throw ApiFailure('照片不能为空，且不能超过 ${maxBytes ~/ (1024 * 1024)} MB');
  }
  final builder = BytesBuilder(copy: false);
  await for (final chunk in file.openRead(0, size)) {
    builder.add(chunk);
  }
  final bytes = builder.takeBytes();
  if (!isHighEfficiencyPhoto(bytes)) {
    throw const ApiFailure('无法识别这张照片的格式，请重新选择');
  }
  if (_fileBrands(bytes).any(_sequenceBrands.contains)) {
    throw const ApiFailure('仅支持静态 HEIF 或 AVIF 照片');
  }
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? frame;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final width = descriptor.width, height = descriptor.height;
    final pixels = width * height;
    if (width <= 0 || height <= 0 || pixels > 64 * 1024 * 1024) {
      throw const ApiFailure('照片分辨率过高或无效，请选择尺寸较小的图片');
    }
    // Leave room for PNG overhead even when the pixels compress poorly.
    final scale = math.min(
      1.0,
      math.min(
        4096 / math.max(width, height),
        math.sqrt(maxBytes / (5 * pixels)),
      ),
    );
    codec = await descriptor.instantiateCodec(
      targetWidth: math.max(1, (width * scale).floor()),
      targetHeight: math.max(1, (height * scale).floor()),
    );
    if (codec.frameCount != 1) {
      throw const ApiFailure('仅支持静态 HEIF 或 AVIF 照片');
    }
    frame = (await codec.getNextFrame()).image;
    final png = await frame.toByteData(format: ui.ImageByteFormat.png);
    if (png == null || png.lengthInBytes > maxBytes) {
      throw const ApiFailure('转换后的照片过大，请选择尺寸较小的图片');
    }
    return XFile.fromData(
      png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
      path: file.path,
      mimeType: 'image/png',
    );
  } on ApiFailure {
    rethrow;
  } catch (_) {
    throw const ApiFailure('当前设备无法读取这张照片，请重新选择');
  } finally {
    frame?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer?.dispose();
  }
}
