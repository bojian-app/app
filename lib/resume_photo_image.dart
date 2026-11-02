import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Keep the URL fixed while giving each uploaded photo its own memory cache key.
class ResumePhotoImage extends ImageProvider<ResumePhotoImage> {
  const ResumePhotoImage(this.url, {required this.fileID});
  final String url;
  final int fileID;
  @override
  Future<ResumePhotoImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(
    ResumePhotoImage key,
    ImageDecoderCallback decode,
  ) {
    final network = NetworkImage(key.url);
    // Delegate HTTP/codec handling; the outer provider supplies the cache key.
    // ignore: deprecated_member_use
    return network.loadImage(network, decode);
  }

  @override
  bool operator ==(Object other) =>
      other is ResumePhotoImage && other.url == url && other.fileID == fileID;
  @override
  int get hashCode => Object.hash(runtimeType, url, fileID);
}
