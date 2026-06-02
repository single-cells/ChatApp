class RoomSummary {
  RoomSummary({
    required this.roomId,
    required this.title,
    this.memberCount,
    this.joinedAt,
  });

  final String roomId;
  final String title;
  final int? memberCount;
  final String? joinedAt;

  factory RoomSummary.fromJson(Map<String, dynamic> json) {
    return RoomSummary(
      roomId: json['roomId'] as String,
      title: json['title'] as String,
      memberCount: json['memberCount'] as int?,
      joinedAt: json['joinedAt'] as String?,
    );
  }
}

class AuthUser {
  AuthUser({
    required this.id,
    required this.email,
    required this.nickname,
    this.avatarUrl,
  });

  final String id;
  final String email;
  final String nickname;
  final String? avatarUrl;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      nickname: json['nickname'] as String,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}
