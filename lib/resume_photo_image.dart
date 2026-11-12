import 'network_image_cache.dart';

/// Keep the URL fixed while giving each uploaded photo its own cache key.
class ResumePhotoImage extends CachedNetworkImage {
  const ResumePhotoImage(super.url, {required this.fileID})
    : super(variant: 'file-$fileID');
  final int fileID;
}
