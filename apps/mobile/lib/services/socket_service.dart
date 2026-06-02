import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/app_config.dart';
import '../models/message.dart';

typedef MessageHandler = void Function(ChatMessage message);

class SocketService {
  io.Socket? _socket;
  String? _currentRoomId;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect(String token) async {
    if (_socket?.connected == true) return;
    _socket?.dispose();
    _socket = io.io(
      AppConfig.wsUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );
    _socket!.connect();
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _currentRoomId = null;
  }

  void onMessageNew(MessageHandler handler) {
    _socket?.on('message.new', (data) {
      if (data is Map) {
        handler(ChatMessage.fromJson(Map<String, dynamic>.from(data)));
      }
    });
  }

  void onRoomReady(void Function(String roomId) handler) {
    _socket?.on('room.ready', (data) {
      if (data is Map && data['roomId'] != null) {
        handler(data['roomId'] as String);
      }
    });
  }

  void onPresence(void Function(String roomId, int count) handler) {
    _socket?.on('presence.update', (data) {
      if (data is Map) {
        handler(
          data['roomId'] as String? ?? '',
          (data['count'] as num?)?.toInt() ?? 0,
        );
      }
    });
  }

  void onCallState(
    void Function(String roomId, List<Map<String, dynamic>> participants)
        handler,
  ) {
    _socket?.on('call.state', (data) {
      if (data is Map) {
        final parts = data['participants'] as List<dynamic>? ?? [];
        handler(
          data['roomId'] as String? ?? '',
          parts.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
        );
      }
    });
  }

  void joinRoom(String roomId) {
    _currentRoomId = roomId;
    _socket?.emit('room.join', {'roomId': roomId});
  }

  void leaveRoom(String roomId) {
    _socket?.emit('room.leave', {'roomId': roomId});
    if (_currentRoomId == roomId) _currentRoomId = null;
  }

  void sendMessage({
    required String roomId,
    required String type,
    String content = '',
    String? attachmentUrl,
    Map<String, dynamic>? attachmentMeta,
  }) {
    _socket?.emit('message.send', {
      'roomId': roomId,
      'type': type,
      'content': content,
      if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
      if (attachmentMeta != null) 'attachmentMeta': attachmentMeta,
    });
  }

  void callJoin(String roomId) {
    _socket?.emit('call.join', {'roomId': roomId});
  }

  void callLeave(String roomId) {
    _socket?.emit('call.leave', {'roomId': roomId});
  }
}
