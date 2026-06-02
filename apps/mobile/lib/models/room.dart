class RoomSummary {
  RoomSummary({
    required this.roomId,
    required this.title,
    this.memberCount,
    this.joinedAt,
    this.lastMessagePreview,
    this.lastMessageSender,
    this.lastMessageAt,
    this.creatorNickname,
    this.createdBy,
  });

  final String roomId;
  final String title;
  final int? memberCount;
  final String? joinedAt;
  final String? lastMessagePreview;
  final String? lastMessageSender;
  final DateTime? lastMessageAt;
  final String? creatorNickname;
  final String? createdBy;

  factory RoomSummary.fromJson(Map<String, dynamic> json) {
    DateTime? lastAt;
    final rawAt = json['lastMessageAt'];
    if (rawAt is String) {
      lastAt = DateTime.tryParse(rawAt);
    }
    return RoomSummary(
      roomId: json['roomId'] as String,
      title: json['title'] as String,
      memberCount: json['memberCount'] as int?,
      joinedAt: json['joinedAt'] as String?,
      lastMessagePreview: json['lastMessagePreview'] as String?,
      lastMessageSender: json['lastMessageSender'] as String?,
      lastMessageAt: lastAt,
      creatorNickname: json['creatorNickname'] as String?,
      createdBy: json['createdBy'] as String?,
    );
  }

  String get listSubtitle {
    if (lastMessagePreview == null || lastMessagePreview!.isEmpty) {
      if (creatorNickname != null && creatorNickname!.isNotEmpty) {
        final n = memberCount;
        return n != null
            ? '由 $creatorNickname 创建 · $n 人'
            : '由 $creatorNickname 创建';
      }
      final n = memberCount;
      return n != null ? '$n 人在线聊' : '点击进入聊天室';
    }
    if (lastMessageSender != null && lastMessageSender!.isNotEmpty) {
      return '$lastMessageSender: $lastMessagePreview';
    }
    return lastMessagePreview!;
  }
}

class AuthUser {
  AuthUser({
    required this.id,
    required this.nickname,
    this.email,
    this.avatarUrl,
  });

  final String id;
  final String? email;
  final String nickname;
  final String? avatarUrl;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String?,
      nickname: json['nickname'] as String,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}
