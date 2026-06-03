import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../models/message.dart';
import '../providers/app_providers.dart';
import '../services/socket_service.dart';
import '../theme/app_theme.dart';
import '../utils/defer_set_state.dart';
import '../providers/unread_provider.dart';
import '../utils/room_open_errors.dart';
import '../widgets/auth_network_image.dart';
import '../widgets/room_password_dialog.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.roomId,
    this.initialTitle = '',
  });

  final String roomId;
  final String initialTitle;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with DeferSetStateMixin {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<ChatMessage> _messages = [];
  late String _roomTitle;
  int _onlineCount = 0;
  bool _loading = true;
  bool _isCreator = false;
  bool _roomHasPassword = false;
  bool _roomActionBusy = false;
  bool _inputHasText = false;
  Map<String, String>? _authHeaders;
  late final SocketService _socket;

  void _onMessageNew(ChatMessage m) {
    if (m.roomId != widget.roomId || !mounted) return;
    _upsertMessage(m);
  }

  void _onPresenceUpdate(String roomId, int count) {
    if (roomId != widget.roomId || !mounted) return;
    deferSetState(() => _onlineCount = count);
  }

  void _onRoomDeleted(String roomId) {
    if (roomId != widget.roomId || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('聊天室已被删除')),
    );
    context.pop();
  }

  @override
  void initState() {
    super.initState();
    _roomTitle = widget.initialTitle.trim();
    _socket = ref.read(socketProvider);
    _socket.onMessageNew(_onMessageNew);
    _socket.onPresence(_onPresenceUpdate);
    _socket.onRoomDeleted(_onRoomDeleted);
    ref.read(unreadProvider.notifier).setActiveRoom(widget.roomId);
    _initChat();
  }

  @override
  void dispose() {
    ref.read(unreadProvider.notifier).setActiveRoom(null);
    _socket.offMessageNew(_onMessageNew);
    _socket.offPresence(_onPresenceUpdate);
    _socket.offRoomDeleted(_onRoomDeleted);
    _socket.leaveRoom(widget.roomId);
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _mediaHeaders() async {
    if (_authHeaders != null) return _authHeaders!;
    if (!mounted) return {};
    final token = await ref.read(storageProvider).getAccessToken();
    if (!mounted) return {};
    _authHeaders = {
      if (token != null) 'Authorization': 'Bearer $token',
    };
    return _authHeaders!;
  }

  Future<void> _initChat() async {
    if (!mounted) return;
    final api = ref.read(apiProvider);
    try {
      await _mediaHeaders();
      if (!mounted) return;
      final room = await api.getRoom(widget.roomId);
      if (!mounted) return;
      try {
        await api.joinRoom(widget.roomId);
      } catch (e) {
        if (!mounted) return;
        if (isRoomPasswordRequired(e)) {
          final pwd = await showRoomPasswordDialog(context);
          if (pwd == null || !mounted) {
            context.pop();
            return;
          }
          await api.joinRoom(widget.roomId, password: pwd);
        } else {
          rethrow;
        }
      }
      if (!mounted) return;
      _socket.joinRoom(widget.roomId);
      final messages = await api.fetchMessages(widget.roomId);
      if (!mounted) return;
      final userId = ref.read(authUserProvider)?.id;
      setState(() {
        _roomTitle = room.title;
        _messages = messages;
        _isCreator =
            userId != null && room.createdBy != null && room.createdBy == userId;
        _roomHasPassword = room.hasPassword;
        _loading = false;
      });
      ref.read(unreadProvider.notifier).markRoomRead(widget.roomId);
      _scrollBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (isRoomMissingError(e)) {
        try {
          await api.dismissRoomMembership(widget.roomId);
        } catch (_) {}
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('该聊天室已不存在，已从最近列表移除')),
        );
        context.pop();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载失败: $e')),
      );
    }
  }

  void _upsertMessage(ChatMessage m) {
    if (!mounted) return;
    deferSetState(() {
      final idx = _messages.indexWhere((x) => x.id == m.id);
      if (idx >= 0) {
        _messages[idx] = m;
      } else {
        _messages.add(m);
      }
      _messages.sort((a, b) => a.seq.compareTo(b.seq));
    });
    _scrollBottom();
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  ChatMessage _optimisticMessage({
    required String type,
    String content = '',
    String? attachmentUrl,
    Map<String, dynamic>? attachmentMeta,
  }) {
    final user = ref.read(authUserProvider)!;
    final nextSeq = _messages.isEmpty
        ? 1
        : _messages.map((m) => m.seq).reduce((a, b) => a > b ? a : b) + 1;
    return ChatMessage(
      id: 'pending-${DateTime.now().millisecondsSinceEpoch}',
      roomId: widget.roomId,
      senderId: user.id,
      senderName: user.nickname,
      type: type,
      content: content,
      attachmentUrl: attachmentUrl,
      attachmentMeta: attachmentMeta,
      seq: nextSeq,
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  Future<void> _sendText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || ref.read(authUserProvider) == null) return;
    _textCtrl.clear();
    deferSetState(() => _inputHasText = false);
    final pending = _optimisticMessage(type: 'text', content: text);
    _upsertMessage(pending);
    final confirmed = await ref.read(socketProvider).sendMessage(
          roomId: widget.roomId,
          type: 'text',
          content: text,
        );
    if (!mounted) return;
    if (confirmed != null) {
      setState(() {
        _messages.removeWhere((m) => m.id == pending.id);
      });
      _upsertMessage(confirmed);
    }
  }

  Future<void> _emitMediaMessage({
    required String type,
    required String attachmentUrl,
    Map<String, dynamic>? attachmentMeta,
  }) async {
    final pending = _optimisticMessage(
      type: type,
      attachmentUrl: attachmentUrl,
      attachmentMeta: attachmentMeta,
    );
    _upsertMessage(pending);
    final confirmed = await ref.read(socketProvider).sendMessage(
          roomId: widget.roomId,
          type: type,
          attachmentUrl: attachmentUrl,
          attachmentMeta: attachmentMeta,
        );
    if (!mounted) return;
    if (confirmed != null) {
      setState(() => _messages.removeWhere((m) => m.id == pending.id));
      _upsertMessage(confirmed);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    await _uploadMedia(
      kind: 'image',
      mime: 'image/jpeg',
      filename: 'image.jpg',
      bytes: await file.readAsBytes(),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.bytes == null) return;
    final f = result.files.single;
    await _uploadMedia(
      kind: 'file',
      mime: 'application/octet-stream',
      filename: f.name,
      bytes: f.bytes!,
    );
  }

  Future<void> _uploadMedia({
    required String kind,
    required String mime,
    required String filename,
    required List<int> bytes,
  }) async {
    try {
      final api = ref.read(apiProvider);
      final uploaded = await api.uploadMedia(
        roomId: widget.roomId,
        bytes: bytes,
        kind: kind,
        mime: mime,
        filename: filename,
      );
      await _emitMediaMessage(
        type: kind == 'image' ? 'image' : 'file',
        attachmentUrl: uploaded['attachmentUrl'] as String,
        attachmentMeta: {
          'mime': mime,
          'filename': filename,
          'size': bytes.length,
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败: $e')),
        );
      }
    }
  }

  String _apiErrorMessage(Object e, String fallback) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] is String) {
        final msg = data['message'];
        if (msg is String) return msg;
        if (msg is List && msg.isNotEmpty) return msg.first.toString();
      }
    }
    return fallback;
  }

  Future<void> _confirmDeleteRoom() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除聊天室'),
        content: const Text('将永久删除该房间及全部消息，且无法恢复。确定继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              '删除',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _roomActionBusy = true);
    try {
      await ref.read(apiProvider).deleteRoom(widget.roomId);
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_apiErrorMessage(e, '删除失败'))),
        );
      }
    } finally {
      if (mounted) setState(() => _roomActionBusy = false);
    }
  }

  Future<void> _manageRoomPassword() async {
    final value = await showRoomPasswordManageDialog(
      context,
      hasPassword: _roomHasPassword,
    );
    if (value == null || !mounted) return;
    setState(() => _roomActionBusy = true);
    try {
      await ref.read(apiProvider).updateRoomPassword(
            widget.roomId,
            password: value.trim().isEmpty ? '' : value.trim(),
          );
      if (mounted) {
        setState(() => _roomHasPassword = value.trim().isNotEmpty);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value.trim().isEmpty ? '已取消房间密码' : '房间密码已更新',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_apiErrorMessage(e, '更新密码失败'))),
        );
      }
    } finally {
      if (mounted) setState(() => _roomActionBusy = false);
    }
  }

  Future<void> _confirmLeaveRoom() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出聊天室'),
        content: const Text('退出后该房间将从你的列表中移除，可再次通过房间 ID 加入。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('退出', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _roomActionBusy = true);
    try {
      await ref.read(apiProvider).leaveRoom(widget.roomId);
      _socket.leaveRoom(widget.roomId);
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_apiErrorMessage(e, '退出失败'))),
        );
      }
    } finally {
      if (mounted) setState(() => _roomActionBusy = false);
    }
  }

  void _previewImage(String url) async {
    final headers = await _mediaHeaders();
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: AuthNetworkImage(
              url: url,
              headers: headers,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(ChatMessage m) {
    final me = ref.read(authUserProvider);
    final isMe = m.senderId == me?.id;
    final displayName = m.senderName.isNotEmpty
        ? m.senderName
        : (isMe ? (me?.nickname ?? '') : '');
    final headers = _authHeaders ?? {};
    Widget body;
    switch (m.type) {
      case 'image':
        body = m.attachmentUrl != null
            ? AuthNetworkImage(
                url: m.attachmentUrl!,
                headers: headers,
                height: 160,
                borderRadius: BorderRadius.circular(4),
                onTap: () => _previewImage(m.attachmentUrl!),
              )
            : const Text('[图片]', style: TextStyle(fontSize: 16));
        break;
      case 'file':
        body = GestureDetector(
          onTap: () {},
          child: Text(
            m.attachmentMeta?['filename']?.toString() ?? '[文件]',
            style: const TextStyle(fontSize: 16, color: AppTheme.titleBlack),
          ),
        );
        break;
      case 'voice':
        body = const Text('[语音]', style: TextStyle(fontSize: 16));
        break;
      default:
        body = Text(
          m.content,
          style: const TextStyle(
            fontSize: 16,
            color: AppTheme.titleBlack,
            height: 1.35,
          ),
        );
    }

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.72,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isMe ? AppTheme.bubbleSelf : AppTheme.bubbleOther,
        borderRadius: BorderRadius.circular(6),
        boxShadow: isMe
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: body,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            _senderAvatar(displayName),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (displayName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4, left: 2),
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.subtitleGray,
                        ),
                      ),
                    ),
                  bubble,
                ],
              ),
            ),
          ] else ...[
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (displayName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4, right: 2),
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.subtitleGray,
                        ),
                      ),
                    ),
                  bubble,
                ],
              ),
            ),
            const SizedBox(width: 8),
            _senderAvatar(displayName),
          ],
        ],
      ),
    );
  }

  Widget _senderAvatar(String name) {
    final label = name.isNotEmpty ? name[0] : '?';
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.primaryDark,
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _roomTitle.isNotEmpty
        ? _roomTitle
        : (_loading ? '加载中…' : '聊天室');
    final hasText = _inputHasText;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayFor(AppTheme.chatBackground),
      child: Scaffold(
          backgroundColor: AppTheme.chatBackground,
          appBar: AppBar(
            backgroundColor: AppTheme.chatBackground,
            systemOverlayStyle: AppTheme.overlayFor(AppTheme.chatBackground),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => context.pop(),
            ),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontSize: 17)),
                if (!_loading)
                  Text(
                    _onlineCount > 0 ? '$_onlineCount 人在线' : '聊天室',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.normal,
                      color: AppTheme.subtitleGray,
                    ),
                  ),
              ],
            ),
            actions: [
              if (!_loading)
                PopupMenuButton<String>(
                  enabled: !_roomActionBusy,
                  onSelected: (value) {
                    if (value == 'password') {
                      _manageRoomPassword();
                    } else if (value == 'delete') {
                      _confirmDeleteRoom();
                    } else if (value == 'leave') {
                      _confirmLeaveRoom();
                    }
                  },
                  itemBuilder: (ctx) => [
                    if (_isCreator) ...[
                      const PopupMenuItem(
                        value: 'password',
                        child: Text('房间密码'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          '删除聊天室',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ] else
                      const PopupMenuItem(
                        value: 'leave',
                        child: Text('退出聊天室'),
                      ),
                  ],
                ),
            ],
          ),
          body: _loading
              ? Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _buildBubble(_messages[i]),
                      ),
                    ),
                    _buildInputBar(hasText),
                  ],
                ),
      ),
    );
  }

  Widget _buildInputBar(bool hasText) {
    return Container(
      color: AppTheme.navBar,
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: 8 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            color: AppTheme.titleBlack,
            onPressed: _showAttachSheet,
          ),
          Expanded(
            child: TextField(
              controller: _textCtrl,
              maxLines: 4,
              minLines: 1,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: '输入消息',
                filled: true,
                fillColor: AppTheme.listBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
              onChanged: (v) {
                final has = v.trim().isNotEmpty;
                if (has == _inputHasText) return;
                deferSetState(() => _inputHasText = has);
              },
              onSubmitted: (_) => _sendText(),
            ),
          ),
          const SizedBox(width: 4),
          if (hasText)
            TextButton(
              onPressed: _sendText,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('发送', style: TextStyle(fontSize: 16)),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  void _showAttachSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.chatBackground,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _attachAction(
                icon: Icons.image_outlined,
                label: '相册',
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage();
                },
              ),
              _attachAction(
                icon: Icons.insert_drive_file_outlined,
                label: '文件',
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFile();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.listBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 28, color: AppTheme.titleBlack),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
