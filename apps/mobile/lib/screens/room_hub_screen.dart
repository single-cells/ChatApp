import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/room.dart';
import '../providers/app_providers.dart';

class RoomHubScreen extends ConsumerStatefulWidget {
  const RoomHubScreen({super.key});

  @override
  ConsumerState<RoomHubScreen> createState() => _RoomHubScreenState();
}

class _RoomHubScreenState extends ConsumerState<RoomHubScreen> {
  final _roomIdCtrl = TextEditingController();
  final _titleCtrl = TextEditingController(text: '新聊天室');
  List<RoomSummary> _recent = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void dispose() {
    _roomIdCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    try {
      final list = await ref.read(apiProvider).recentRooms();
      if (mounted) setState(() {
        _recent = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _enterRoom(String roomId) async {
    try {
      await ref.read(apiProvider).joinRoom(roomId);
      if (mounted) context.go('/chat/$roomId');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('进入失败: $e')),
        );
      }
    }
  }

  Future<void> _createRoom() async {
    try {
      final room = await ref.read(apiProvider).createRoom(_titleCtrl.text.trim());
      if (mounted) context.go('/chat/${room.roomId}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e')),
        );
      }
    }
  }

  Future<void> _logout() async {
    await ref.read(storageProvider).clear();
    ref.read(accessTokenProvider.notifier).state = null;
    ref.read(authUserProvider.notifier).state = null;
    ref.read(socketProvider).disconnect();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authUserProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('你好，${user?.nickname ?? ""}'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _roomIdCtrl,
            decoration: const InputDecoration(
              labelText: '房间 ID',
              hintText: '输入 roomId 进入',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () {
              final id = _roomIdCtrl.text.trim();
              if (id.isNotEmpty) _enterRoom(id);
            },
            child: const Text('进入房间'),
          ),
          const Divider(height: 32),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: '新房间名称'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _createRoom,
            child: const Text('创建房间'),
          ),
          const Divider(height: 32),
          const Text('最近房间', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_recent.isEmpty)
            const Text('暂无')
          else
            ..._recent.map(
              (r) => ListTile(
                title: Text(r.title),
                subtitle: Text(r.roomId),
                onTap: () => _enterRoom(r.roomId),
              ),
            ),
        ],
      ),
    );
  }
}
