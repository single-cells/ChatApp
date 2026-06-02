class ChatMessage {
  ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.type,
    required this.content,
    this.attachmentUrl,
    this.attachmentMeta,
    required this.seq,
    required this.createdAt,
  });

  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String type;
  final String content;
  final String? attachmentUrl;
  final Map<String, dynamic>? attachmentMeta;
  final int seq;
  final String createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      roomId: json['roomId'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String? ?? 'User',
      senderAvatar: json['senderAvatar'] as String?,
      type: json['type'] as String,
      content: json['content'] as String? ?? '',
      attachmentUrl: json['attachmentUrl'] as String?,
      attachmentMeta: json['attachmentMeta'] as Map<String, dynamic>?,
      seq: json['seq'] as int,
      createdAt: json['createdAt'] as String,
    );
  }

  int? get durationSec {
    final d = attachmentMeta?['durationSec'];
    if (d is int) return d;
    if (d is num) return d.toInt();
    return null;
  }
}
