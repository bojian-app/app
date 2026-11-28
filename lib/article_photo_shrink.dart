/// Phone photos run to several megabytes each, far more than a post is ever
/// shown at, so they are cut down before they are uploaded.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// A posted photo's short side at most, and its pixels at most: bounding the
/// short side leaves long screenshots their width.
const photoShortSide = 1440;
const photoMaxPixels = 12 * 1000 * 1000;
const photoQuality = 85;

/// Files this small go as they are.
const photoKeptBytes = 500 * 1024;

const _decodablePixels = 64 * 1024 * 1024;

/// [bytes] as a smaller JPEG, or null where the photo should go as it is:
/// small already, moving, see-through, unreadable, or no smaller afterwards.
///
/// With [convert] the photo is in a format that cannot be sent, so it is made
/// into a JPEG whatever its size, and an unreadable one throws.
Future<Uint8List?> shrinkPhoto(Uint8List bytes, {bool convert = false}) async {
  if (!convert && bytes.length <= photoKeptBytes) return null;
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? frame;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final width = descriptor.width, height = descriptor.height;
    final pixels = width * height;
    if (width <= 0 || height <= 0 || pixels > _decodablePixels) {
      if (convert) throw const FormatException('photo size');
      return null;
    }
    final scale = math.min(
      1.0,
      math.min(
        photoShortSide / math.min(width, height),
        math.sqrt(photoMaxPixels / pixels),
      ),
    );
    // One side alone, so the picture keeps its shape.
    codec = await descriptor.instantiateCodec(
      targetWidth: scale < 1 ? math.max(1, (width * scale).round()) : null,
    );
    if (codec.frameCount != 1) {
      if (convert) throw const FormatException('moving photo');
      return null;
    }
    frame = (await codec.getNextFrame()).image;
    final data = await frame.toByteData();
    if (data == null) throw const FormatException('photo pixels');
    final raw = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    if (!convert) {
      // A JPEG has no transparency to keep.
      for (var i = 3; i < raw.length; i += 4) {
        if (raw[i] != 255) return null;
      }
    }
    final jpeg = await compute(_encodeJpeg, (
      pixels: raw,
      width: frame.width,
      height: frame.height,
    ));
    return convert || jpeg.length < bytes.length ? jpeg : null;
  } catch (_) {
    if (convert) rethrow;
    return null;
  } finally {
    frame?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer?.dispose();
  }
}

Uint8List _encodeJpeg(({Uint8List pixels, int width, int height}) photo) =>
    img.encodeJpg(
      img.Image.fromBytes(
        width: photo.width,
        height: photo.height,
        bytes: photo.pixels.buffer,
        bytesOffset: photo.pixels.offsetInBytes,
        numChannels: 4,
      ),
      quality: photoQuality,
      chroma: img.JpegChroma.yuv420,
    );
