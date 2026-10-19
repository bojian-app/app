import 'app_store.dart';

class ProfileIdentityData {
  const ProfileIdentityData({
    required this.userID,
    required this.name,
    this.publicID = '',
    this.bio = '',
    this.avatarURL = '',
    this.ipLocation = '',
    this.registeredAt,
  });

  factory ProfileIdentityData.fromStore(AppStore store) => ProfileIdentityData(
    userID: store.userID,
    name: store.name,
    publicID: store.publicID,
    bio: store.bio,
    avatarURL: store.avatarURL,
    ipLocation: store.ipLocation,
    registeredAt: store.registeredAt,
  );

  factory ProfileIdentityData.fromJson(Map<String, dynamic> data) =>
      ProfileIdentityData(
        userID: integer(data['id']),
        name: '${data['nickname'] ?? ''}'.trim(),
        publicID: '${data['public_id'] ?? ''}'.trim(),
        bio: '${data['bio'] ?? ''}'.trim(),
        avatarURL: '${data['avatar_url'] ?? ''}'.trim(),
        ipLocation: '${data['city'] ?? ''}'.trim(),
        registeredAt: DateTime.tryParse('${data['created_at'] ?? ''}'),
      );

  final int userID;
  final String name, publicID, bio, avatarURL, ipLocation;
  final DateTime? registeredAt;
  String get avatarSeed => userID > 0 ? '$userID' : publicID;
}
