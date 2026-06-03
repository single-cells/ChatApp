import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/app_config.dart';
import '../providers/app_providers.dart';
import '../providers/theme_provider.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';
import '../widgets/app_update_dialog.dart';

/// 「我」tab 内容（无嵌套 Scaffold）。
class MeScreen extends ConsumerStatefulWidget {
  const MeScreen({super.key});

  @override
  ConsumerState<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends ConsumerState<MeScreen> {
  bool _busy = false;
  String _versionLabel = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshProfile();
      _loadVersion();
    });
  }

  Future<void> _loadVersion() async {
    try {
      final v = await ref.read(appUpdateServiceProvider).localVersion();
      if (mounted) {
        setState(() => _versionLabel = 'v${v.versionName} (${v.versionCode})');
      }
    } catch (_) {}
  }

  Future<void> _checkUpdate() async {
    if (!AppConfig.enableAppUpdate) return;
    setState(() => _busy = true);
    try {
      final release =
          await ref.read(appUpdateServiceProvider).checkForUpdate();
      if (!mounted) return;
      if (release == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前已是最新版本')),
        );
        return;
      }
      await AppUpdateDialog.show(
        context,
        release: release,
        updateService: ref.read(appUpdateServiceProvider),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('检查更新失败，请稍后重试')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshProfile() async {
    try {
      final user = await ref.read(apiProvider).me();
      if (mounted) ref.read(authUserProvider.notifier).state = user;
    } catch (_) {}
  }

  Future<void> _editNickname() async {
    final user = ref.read(authUserProvider);
    if (user == null) return;

    if (!user.canChangeNicknameToday) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('今日已修改过昵称，请明天再试')),
      );
      return;
    }

    final ctrl = TextEditingController(text: user.nickname);
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 64,
          decoration: const InputDecoration(
            labelText: '昵称',
            hintText: '每天仅可修改一次',
          ),
          textInputAction: TextInputAction.done,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (submitted != true || !mounted) {
      ctrl.dispose();
      return;
    }

    final nickname = ctrl.text.trim();
    ctrl.dispose();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入昵称')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final updated = await ref.read(apiProvider).updateNickname(nickname);
      if (!mounted) return;
      ref.read(authUserProvider.notifier).state = updated;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('昵称已更新')),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data is Map
          ? (e.response!.data as Map)['message']?.toString()
          : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg ?? '修改失败，请稍后重试')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('修改失败，请稍后重试')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAccount() async {
    final user = ref.read(authUserProvider);
    if (user == null) return;

    setState(() => _busy = true);
    int createdCount = 0;
    try {
      final quota = await ref.read(apiProvider).createdRoomQuota();
      createdCount = quota.count;
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法检查聊天室，请稍后重试')),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    if (createdCount > 0) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('无法注销'),
          content: Text(
            '您创建了 $createdCount 个聊天室，请先删除全部您创建的聊天室后再注销账号。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('注销账号'),
        content: const Text(
          '注销后本机账号数据将被删除，下次打开需重新设置昵称。确定继续？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              '注销',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).deleteAccount();
      ref.read(socketProvider).disconnect();
      await ref.read(storageProvider).clearAuth();
      ref.read(accessTokenProvider.notifier).state = null;
      ref.read(authUserProvider.notifier).state = null;
      ref.read(needsNicknameProvider.notifier).state = true;
      if (!mounted) return;
      context.go('/');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('账号已注销')),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data is Map
          ? (e.response!.data as Map)['message']?.toString()
          : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg ?? '注销失败，请稍后重试')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('注销失败，请稍后重试')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authUserProvider);
    final canChange = user?.canChangeNicknameToday ?? true;
    final currentPalette = ref.watch(appPaletteProvider);

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
                  style: TextStyle(
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
                    if (!AppConfig.enableAppUpdate &&
                        _versionLabel.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _versionLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.subtitleGray,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          color: AppTheme.listBackground,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '主题色',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.titleBlack,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '赤橙黄绿青蓝紫等 12 种配色，点击方块即时切换',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.subtitleGray,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final p in AppPalette.presets)
                    _ThemeColorSwatch(
                      palette: p,
                      selected: p.id == currentPalette.id,
                      onTap: () =>
                          ref.read(appPaletteProvider.notifier).select(p.id),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _busy ? null : _editNickname,
          child: Container(
            color: AppTheme.listBackground,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('修改昵称'),
                      if (!canChange)
                        const Text(
                          '今日已修改，明天可再改',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.subtitleGray,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_busy)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primary,
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right,
                    color: canChange
                        ? AppTheme.subtitleGray
                        : AppTheme.subtitleGray.withValues(alpha: 0.4),
                  ),
              ],
            ),
          ),
        ),
        if (AppConfig.enableAppUpdate) ...[
          const SizedBox(height: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _busy ? null : _checkUpdate,
            child: Container(
              color: AppTheme.listBackground,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('检查更新'),
                        if (_versionLabel.isNotEmpty)
                          Text(
                            _versionLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.subtitleGray,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppTheme.subtitleGray,
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _busy ? null : _deleteAccount,
          child: Container(
            color: AppTheme.listBackground,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: const Row(
              children: [
                Expanded(
                  child: Text(
                    '注销账号',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                Icon(Icons.chevron_right, color: AppTheme.subtitleGray),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ThemeColorSwatch extends StatelessWidget {
  const _ThemeColorSwatch({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: palette.label,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: palette.primary,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppTheme.titleBlack : Colors.transparent,
              width: selected ? 3 : 0,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: palette.primary.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 22)
              : null,
        ),
      ),
    );
  }
}
