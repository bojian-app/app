/// The system picker can give an image a filename derived from stale metadata.
String? photoMimeFromBytes(List<int> bytes) => switch (bytes) {
  [0xff, 0xd8, 0xff, ...] => 'image/jpeg',
  [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, ...] => 'image/png',
  [0x52, 0x49, 0x46, 0x46, _, _, _, _, 0x57, 0x45, 0x42, 0x50, ...] =>
    'image/webp',
  [0x47, 0x49, 0x46, 0x38, 0x37 || 0x39, 0x61, ...] => 'image/gif',
  _ => null,
};

String photoUploadName(String name, String mime) {
  final extension = switch (mime) {
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/webp' => 'webp',
    'image/gif' => 'gif',
    _ => null,
  };
  if (extension == null) return name;
  final dot = name.lastIndexOf('.');
  final stem = dot > 0 ? name.substring(0, dot) : name;
  return '${stem.isEmpty ? 'photo' : stem}.$extension';
}
