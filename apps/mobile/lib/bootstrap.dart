import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/app_providers.dart';

/// Restore session from secure storage on cold start.
Future<void> bootstrapAuth(WidgetRef ref) async {
  final storage = ref.read(storageProvider);
  final token = await storage.getAccessToken();
  if (token == null) return;
  ref.read(accessTokenProvider.notifier).state = token;
  try {
    final api = ref.read(apiProvider);
    final user = await api.me();
    ref.read(authUserProvider.notifier).state = user;
    await ref.read(socketProvider).connect(token);
  } catch (_) {
    await storage.clear();
    ref.read(accessTokenProvider.notifier).state = null;
  }
}
