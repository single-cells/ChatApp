import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/room.dart';
import '../providers/app_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _nickname = TextEditingController();
  bool _register = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiProvider);
      final storage = ref.read(storageProvider);
      final Map<String, dynamic> res;
      if (_register) {
        res = await api.register(
          email: _email.text.trim(),
          password: _password.text,
          nickname: _nickname.text.trim().isEmpty
              ? null
              : _nickname.text.trim(),
        );
      } else {
        res = await api.login(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
      await storage.saveTokens(
        accessToken: res['accessToken'] as String,
        refreshToken: res['refreshToken'] as String,
      );
      ref.read(accessTokenProvider.notifier).state =
          res['accessToken'] as String;
      ref.read(authUserProvider.notifier).state =
          AuthUser.fromJson(res['user'] as Map<String, dynamic>);
      await ref.read(socketProvider).connect(res['accessToken'] as String);
      if (mounted) context.go('/hub');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('聊天室登录')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: '邮箱'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              decoration: const InputDecoration(labelText: '密码'),
              obscureText: true,
            ),
            if (_register) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _nickname,
                decoration: const InputDecoration(labelText: '昵称（可选）'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: Text(_loading ? '...' : (_register ? '注册' : '登录')),
            ),
            TextButton(
              onPressed: () => setState(() => _register = !_register),
              child: Text(_register ? '已有账号？登录' : '没有账号？注册'),
            ),
          ],
        ),
      ),
    );
  }
}
