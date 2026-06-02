import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

/// 「我」tab 内容（无嵌套 Scaffold）。
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(storageProvider).clearAuth();
    ref.read(accessTokenProvider.notifier).state = null;
    ref.read(authUserProvider.notifier).state = null;
    ref.read(needsNicknameProvider.notifier).state = false;
    ref.read(socketProvider).disconnect();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authUserProvider);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Container(
          color: AppTheme.listBackground,
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                child: Text(
                  (user?.nickname.isNotEmpty == true)
                      ? user!.nickname[0]
                      : '?',
                  style: const TextStyle(
                    fontSize: 28,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.nickname ?? '未登录',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.titleBlack,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      user?.email ?? '本机设备账号',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.subtitleGray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _logout(context, ref),
          child: Container(
            color: AppTheme.listBackground,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: const Row(
              children: [
                Expanded(child: Text('退出登录')),
                Icon(Icons.chevron_right, color: AppTheme.subtitleGray),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
