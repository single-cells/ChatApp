import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../bootstrap.dart';
import '../models/auth_session.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _nickname = TextEditingController();
  bool _loading = false;
  bool _silentLoginAttempted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _trySilentDeviceLogin());
  }

  Future<void> _trySilentDeviceLogin() async {
    if (_silentLoginAttempted || !mounted) return;
    final authReady = ref.read(authReadyProvider);
    final token = ref.read(accessTokenProvider);
    final needsNickname = ref.read(needsNicknameProvider);
    if (!authReady || token != null || needsNickname) return;
    _silentLoginAttempted = true;
    setState(() => _loading = true);
    try {
      final deviceId = await ref.read(storageProvider).getOrCreateDeviceId();
      final result =
          await ref.read(apiProvider).deviceLogin(deviceId: deviceId);
      if (result case DeviceAuthSuccess success) {
        await applyAuthSession(ref, success);
      }
    } catch (_) {
      // Show nickname form on failure.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nickname = _nickname.text.trim();
    if (nickname.isEmpty) {
      setState(() => _error = '请输入昵称');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final storage = ref.read(storageProvider);
      final deviceId = await storage.getOrCreateDeviceId();
      final result = await ref.read(apiProvider).deviceLogin(
            deviceId: deviceId,
            nickname: nickname,
          );
      switch (result) {
        case DeviceAuthNeedsNickname():
          setState(() => _error = '请填写昵称');
        case DeviceAuthSuccess():
          await applyAuthSession(ref, result);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authReady = ref.watch(authReadyProvider);
    final token = ref.watch(accessTokenProvider);
    final needsNickname = ref.watch(needsNicknameProvider);

    if (!authReady || (token != null && !needsNickname)) {
      return _loginScaffold(
        Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    if (token != null) {
      return _loginScaffold(
        Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    return _loginScaffold(
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 56),
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppTheme.brandGradient.createShader(bounds),
                  child: const Icon(
                    Icons.chat_bubble_rounded,
                    size: 72,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppTheme.brandGradient.createShader(bounds),
                  child: const Text(
                    'FreeChat',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '设置昵称即可开始',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.subtitleGray,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '本机账号；换设备或清空应用数据后需重新设置',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.subtitleGray,
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.listBackground,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _nickname,
                        decoration: const InputDecoration(
                          labelText: '昵称',
                          prefixIcon: Icon(
                            Icons.person_outline,
                            color: AppTheme.subtitleGray,
                          ),
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        autofocus: true,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      GradientButton(
                        onPressed: _submit,
                        isLoading: _loading,
                        child: const Text(
                          '进入',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}

Widget _loginScaffold(Widget body) {
  return AnnotatedRegion<SystemUiOverlayStyle>(
    value: AppTheme.overlayFor(AppTheme.statusBarGradientTop),
    child: Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: AppTheme.subtleGradient),
        child: body,
      ),
    ),
  );
}
