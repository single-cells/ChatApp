import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

/// Create / join room flows (used by FAB and list screen).
class RoomActionsSheet {
  static void show(
    BuildContext context,
    WidgetRef ref, {
    VoidCallback? onRoomsChanged,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.listBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add, color: Colors.white),
              ),
              title: const Text('创建聊天室'),
              subtitle: const Text('新建一个房间并开始聊天'),
              onTap: () async {
                Navigator.pop(ctx);
                await _showCreateDialog(
                  context,
                  ref,
                  onRoomsChanged: onRoomsChanged,
                );
              },
            ),
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.login, color: AppTheme.primary),
              ),
              title: const Text('加入聊天室'),
              subtitle: const Text('输入房间 ID 进入已有房间'),
              onTap: () {
                Navigator.pop(ctx);
                _showJoinDialog(context, ref, onRoomsChanged: onRoomsChanged);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  static Future<void> _showCreateDialog(
    BuildContext context,
    WidgetRef ref, {
    VoidCallback? onRoomsChanged,
  }) async {
    ({int count, int max})? quota;
    try {
      quota = await ref.read(apiProvider).createdRoomQuota();
      if (quota.count >= quota.max) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '每人最多创建 ${quota.max} 个聊天室（已创建 ${quota.count} 个）',
              ),
            ),
          );
        }
        return;
      }
    } catch (_) {}

    if (!context.mounted) return;
    final ctrl = TextEditingController(text: '新聊天室');
    final quotaHint = quota != null
        ? '还可创建 ${quota.max - quota.count} 个（上限 ${quota.max} 个）'
        : '';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('创建聊天室'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (quotaHint.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  quotaHint,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.subtitleGray,
                  ),
                ),
              ),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(hintText: '房间名称'),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final t = ctrl.text.trim();
              Navigator.pop(ctx);
              if (t.isEmpty) return;
              try {
                final room = await ref.read(apiProvider).createRoom(t);
                onRoomsChanged?.call();
                if (context.mounted) {
                  await _openChat(
                    context,
                    ref,
                    roomId: room.roomId,
                    title: room.title,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  final msg = e is DioException
                      ? (e.response?.data is Map &&
                              (e.response!.data as Map)['message'] is String
                          ? (e.response!.data as Map)['message'] as String
                          : '创建失败: $e')
                      : '创建失败: $e';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(msg)),
                  );
                }
              }
            },
            child: const Text('创建',
                style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  static void _showJoinDialog(
    BuildContext context,
    WidgetRef ref, {
    VoidCallback? onRoomsChanged,
  }) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('加入聊天室'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: '房间 ID'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final id = ctrl.text.trim();
              Navigator.pop(ctx);
              if (id.isEmpty) return;
              await _openChat(context, ref, roomId: id, onRoomsChanged: onRoomsChanged);
            },
            child: const Text('进入',
                style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  static Future<void> _openChat(
    BuildContext context,
    WidgetRef ref, {
    required String roomId,
    String? title,
    VoidCallback? onRoomsChanged,
  }) async {
    try {
      final api = ref.read(apiProvider);
      await api.joinRoom(roomId);
      var roomTitle = title?.trim() ?? '';
      if (roomTitle.isEmpty) {
        try {
          final room = await api.getRoom(roomId);
          roomTitle = room.title;
        } catch (_) {
          roomTitle = '聊天室';
        }
      }
      onRoomsChanged?.call();
      if (context.mounted) {
        final q = roomTitle.isNotEmpty
            ? '?title=${Uri.encodeComponent(roomTitle)}'
            : '';
        await context.push('/chat/$roomId$q');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('进入失败: $e')),
        );
      }
    }
  }

  /// Navigate to chat with known room title (from list).
  static Future<void> openChatWithTitle(
    BuildContext context,
    WidgetRef ref, {
    required String roomId,
    required String title,
    VoidCallback? onRoomsChanged,
  }) {
    return _openChat(
      context,
      ref,
      roomId: roomId,
      title: title,
      onRoomsChanged: onRoomsChanged,
    );
  }
}
