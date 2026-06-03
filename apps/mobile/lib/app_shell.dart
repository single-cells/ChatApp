import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'bootstrap.dart';
import 'config/app_config.dart';
import 'providers/app_providers.dart';
import 'providers/theme_provider.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'widgets/app_update_dialog.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _updateCheckStarted = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => bootstrapAuth(ref));
  }

  Future<void> _checkAppUpdate() async {
    if (!AppConfig.enableAppUpdate) return;
    try {
      final release =
          await ref.read(appUpdateServiceProvider).checkForUpdate();
      if (release == null || !mounted) return;
      await AppUpdateDialog.show(
        context,
        release: release,
        updateService: ref.read(appUpdateServiceProvider),
      );
    } catch (_) {
      // Offline or manifest missing — ignore on startup.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(authReadyProvider, (prev, next) {
      if (!AppConfig.enableAppUpdate) return;
      if (next && !_updateCheckStarted) {
        _updateCheckStarted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _checkAppUpdate();
        });
      }
    });

    final router = ref.watch(routerProvider);
    final palette = ref.watch(appPaletteProvider);
    AppTheme.applyPalette(palette);
    final overlay = AppTheme.systemUiOverlay;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setSystemUIOverlayStyle(overlay);
    });
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: MaterialApp.router(
        key: ValueKey(palette.id),
        title: 'FreeChat',
        theme: AppTheme.light(),
        routerConfig: router,
      ),
    );
  }
}
