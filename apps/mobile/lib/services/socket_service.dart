import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/app_config.dart';
import '../models/message.dart';

typedef MessageHandler = void Function(ChatMessage message);
typedef PresenceHandler = void Function(String roomId, int count);
typedef RoomDeletedHandler = void Function(String roomId);

class SocketService {
  io.Socket? _socket;
  String? _currentRoomId;
  final List<MessageHandler> _messageHandlers = [];
  final List<PresenceHandler> _presenceHandlers = [];
  final List<RoomDeletedHandler> _roomDeletedHandlers = [];
  bool _coreListenersAttached = false;
  bool _presenceListenerAttached = false;
  bool _roomDeletedListenerAttached = false;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect(String token, {String? deviceId}) async {
    if (_socket?.connected == true) return;
    _socket?.dispose();
    _coreListenersAttached = false;
    _presenceListenerAttached = false;
    _roomDeletedListenerAttached = false;
    _socket = io.io(
      AppConfig.wsUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .setAuth({
            'token': token,
            if (deviceId != null) 'deviceId': deviceId,
          })
          .build(),
    );
    _socket!.onConnect((_) {
      _attachCoreListeners();
      _presenceListenerAttached = false;
      _attachPresenceListener();
    });
    _socket!.connect();
    if (_socket!.connected) {
      _attachCoreListeners();
      _attachPresenceListener();
    }
  }

  void _attachCoreListeners() {
    if (_coreListenersAttached || _socket == null) return;
    _coreListenersAttached = true;
    _socket!.off('message.new');
    _socket!.on('message.new', (data) {
      if (data is! Map) return;
      final msg = ChatMessage.fromJson(Map<String, dynamic>.from(data));
      for (final h in List<MessageHandler>.from(_messageHandlers)) {
        h(msg);
      }
    });
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _currentRoomId = null;
    _messageHandlers.clear();
    _presenceHandlers.clear();
    _roomDeletedHandlers.clear();
    _coreListenersAttached = false;
    _presenceListenerAttached = false;
    _roomDeletedListenerAttached = false;
  }

  void onMessageNew(MessageHandler handler) {
    _messageHandlers.add(handler);
    _attachCoreListeners();
  }

  void offMessageNew(MessageHandler handler) {
    _messageHandlers.remove(handler);
  }

  void onRoomReady(void Function(String roomId) handler) {
    _socket?.on('room.ready', (data) {
      if (data is Map && data['roomId'] != null) {
        handler(data['roomId'] as String);
      }
    });
  }

  void onPresence(PresenceHandler handler) {
    _presenceHandlers.add(handler);
    _attachPresenceListener();
  }

  void offPresence(PresenceHandler handler) {
    _presenceHandlers.remove(handler);
  }

  void onRoomDeleted(RoomDeletedHandler handler) {
    _roomDeletedHandlers.add(handler);
    _attachRoomDeletedListener();
  }

  void offRoomDeleted(RoomDeletedHandler handler) {
    _roomDeletedHandlers.remove(handler);
  }

  void _attachRoomDeletedListener() {
    if (_roomDeletedListenerAttached || _socket == null) return;
    if (_roomDeletedHandlers.isEmpty) return;
    _roomDeletedListenerAttached = true;
    _socket!.off('room.deleted');
    _socket!.on('room.deleted', (data) {
      if (data is! Map) return;
      final roomId = data['roomId'] as String? ?? '';
      if (roomId.isEmpty) return;
      for (final h in List<RoomDeletedHandler>.from(_roomDeletedHandlers)) {
        h(roomId);
      }
    });
  }

  void _attachPresenceListener() {
    if (_presenceListenerAttached || _socket == null) return;
    if (_presenceHandlers.isEmpty) return;
    _presenceListenerAttached = true;
    _socket!.off('presence.update');
    _socket!.on('presence.update', (data) {
      if (data is! Map) return;
      final roomId = data['roomId'] as String? ?? '';
      final count = (data['count'] as num?)?.toInt() ?? 0;
      for (final h in List<PresenceHandler>.from(_presenceHandlers)) {
        h(roomId, count);
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

  /// Sends a message; returns server message from ack when available.
  Future<ChatMessage?> sendMessage({
    required String roomId,
    required String type,
    String content = '',
    String? attachmentUrl,
    Map<String, dynamic>? attachmentMeta,
  }) async {
    final payload = {
      'roomId': roomId,
      'type': type,
      'content': content,
      if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
      if (attachmentMeta != null) 'attachmentMeta': attachmentMeta,
    };
    final socket = _socket;
    if (socket == null || !socket.connected) return null;

    return _emitWithAck(socket, payload);
  }

  Future<ChatMessage?> _emitWithAck(
    io.Socket socket,
    Map<String, dynamic> payload,
  ) {
    final completer = Completer<ChatMessage?>();
    socket.emitWithAck('message.send', payload, ack: (response) {
      if (!completer.isCompleted) {
        completer.complete(_parseAckMessage(response));
      }
    });
    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => null,
    );
  }

  ChatMessage? _parseAckMessage(dynamic response) {
    if (response is! Map) return null;
    final map = Map<String, dynamic>.from(response);
    final msg = map['message'];
    if (msg is Map) {
      return ChatMessage.fromJson(Map<String, dynamic>.from(msg));
    }
    return null;
  }

  void callJoin(String roomId) {
    _socket?.emit('call.join', {'roomId': roomId});
  }

  void callLeave(String roomId) {
    _socket?.emit('call.leave', {'roomId': roomId});
  }
}
