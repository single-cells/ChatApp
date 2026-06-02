import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../models/message.dart';
import '../providers/app_providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();

  List<ChatMessage> _messages = [];
  String _roomTitle = '';
  int _onlineCount = 0;
  bool _loading = true;
  bool _recording = false;
  Room? _liveKitRoom;
  bool _inVoiceCall = false;
  List<Map<String, dynamic>> _voiceParticipants = [];

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _leaveVoice();
    ref.read(socketProvider).leaveRoom(widget.roomId);
    super.dispose();
  }

  Future<void> _initChat() async {
    final api = ref.read(apiProvider);
    final socket = ref.read(socketProvider);
    try {
      final room = await api.getRoom(widget.roomId);
      await api.joinRoom(widget.roomId);
      final messages = await api.fetchMessages(widget.roomId);
      socket.onMessageNew((m) {
        if (m.roomId != widget.roomId) return;
        setState(() {
          if (!_messages.any((x) => x.id == m.id)) {
            _messages.add(m);
            _messages.sort((a, b) => a.seq.compareTo(b.seq));
          }
        });
        _scrollBottom();
      });
      socket.onPresence((roomId, count) {
        if (roomId == widget.roomId) {
          setState(() => _onlineCount = count);
        }
      });
      socket.onCallState((roomId, participants) {
        if (roomId == widget.roomId) {
          setState(() => _voiceParticipants = participants);
        }
      });
      socket.joinRoom(widget.roomId);
      setState(() {
        _roomTitle = room.title;
        _messages = messages;
        _loading = false;
      });
      _scrollBottom();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
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

  void _sendText() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    ref.read(socketProvider).sendMessage(
          roomId: widget.roomId,
          type: 'text',
          content: text,
        );
    _textCtrl.clear();
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
      final presign = await api.presignUpload(
        roomId: widget.roomId,
        kind: kind,
        mime: mime,
        filename: filename,
      );
      await api.uploadFile(
        presign['uploadUrl'] as String,
        bytes,
        mime,
      );
      ref.read(socketProvider).sendMessage(
            roomId: widget.roomId,
            type: kind == 'image' ? 'image' : 'file',
            attachmentUrl: presign['attachmentUrl'] as String,
            attachmentMeta: {'mime': mime, 'filename': filename, 'size': bytes.length},
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败: $e')),
        );
      }
    }
  }

  Future<void> _startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      setState(() {
        _recording = true;
        _recordPath = path;
      });
    }
  }

  String? _recordPath;

  Future<void> _stopRecordingAndSend() async {
    if (!_recording) return;
    final path = await _audioRecorder.stop();
    setState(() => _recording = false);
    final filePath = path ?? _recordPath;
    if (filePath == null) return;
    final bytes = await File(filePath).readAsBytes();
    try {
      final api = ref.read(apiProvider);
      final presign = await api.presignUpload(
        roomId: widget.roomId,
        kind: 'voice',
        mime: 'audio/m4a',
        filename: 'voice.m4a',
      );
      await api.uploadFile(
        presign['uploadUrl'] as String,
        bytes,
        'audio/m4a',
      );
      ref.read(socketProvider).sendMessage(
            roomId: widget.roomId,
            type: 'voice',
            attachmentUrl: presign['attachmentUrl'] as String,
            attachmentMeta: {
              'mime': 'audio/m4a',
              'size': bytes.length,
              'durationSec': 1,
            },
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('语音发送失败: $e'),
        );
      }
    }
  }

  Future<void> _toggleVoiceCall() async {
    if (_inVoiceCall) {
      await _leaveVoice();
      ref.read(socketProvider).callLeave(widget.roomId);
      setState(() => _inVoiceCall = false);
      return;
    }
    try {
      final tokenRes = await ref.read(apiProvider).voiceToken(widget.roomId);
      final url = tokenRes['livekitUrl'] as String;
      final token = tokenRes['token'] as String;
      _liveKitRoom = Room();
      await _liveKitRoom!.connect(url, token);
      await _liveKitRoom!.localParticipant?.setMicrophoneEnabled(true);
      ref.read(socketProvider).callJoin(widget.roomId);
      setState(() => _inVoiceCall = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('连麦需要 LiveKit: $e')),
        );
      }
    }
  }

  Future<void> _leaveVoice() async {
    await _liveKitRoom?.disconnect();
    _liveKitRoom = null;
  }

  Future<void> _playVoice(String url) async {
    try {
      await _audioPlayer.setUrl(url);
      await _audioPlayer.play();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放失败: $e')),
        );
      }
    }
  }

  Widget _buildBubble(ChatMessage m) {
    final isMe = m.senderId == ref.read(authUserProvider)?.id;
    Widget body;
    switch (m.type) {
      case 'image':
        body = m.attachmentUrl != null
            ? Image.network(m.attachmentUrl!, height: 120, fit: BoxFit.cover)
            : const Text('[图片]');
        break;
      case 'file':
        body = TextButton(
          onPressed: () {},
          child: Text(m.attachmentMeta?['filename']?.toString() ?? '[文件]'),
        );
        break;
      case 'voice':
        body = TextButton.icon(
          onPressed: m.attachmentUrl != null
              ? () => _playVoice(m.attachmentUrl!)
              : null,
          icon: const Icon(Icons.play_arrow),
          label: Text('语音 ${m.durationSec ?? "?"}s'),
        );
        break;
      default:
        body = Text(m.content);
    }
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(
                m.senderName,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            body,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_roomTitle.isEmpty ? widget.roomId : _roomTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/hub'),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text('在线 $_onlineCount'),
            ),
          ),
          IconButton(
            icon: Icon(_inVoiceCall ? Icons.call_end : Icons.call),
            onPressed: _toggleVoiceCall,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_inVoiceCall && _voiceParticipants.isNotEmpty)
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _voiceParticipants
                          .map(
                            (p) => Chip(
                              label: Text(p['nickname']?.toString() ?? ''),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(8),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _buildBubble(_messages[i]),
                  ),
                ),
                SafeArea(
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.image),
                        onPressed: _pickImage,
                      ),
                      IconButton(
                        icon: const Icon(Icons.attach_file),
                        onPressed: _pickFile,
                      ),
                      GestureDetector(
                        onLongPressStart: (_) => _startRecording(),
                        onLongPressEnd: (_) => _stopRecordingAndSend(),
                        child: Icon(
                          _recording ? Icons.mic : Icons.mic_none,
                          color: _recording ? Colors.red : null,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _textCtrl,
                          decoration: const InputDecoration(
                            hintText: '消息',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _sendText(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _sendText,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
