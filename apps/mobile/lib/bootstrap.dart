import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/auth_session.dart';
import 'providers/app_providers.dart';

Future<void> applyAuthSession(WidgetRef ref, DeviceAuthSuccess session) async {
  final storage = ref.read(storageProvider);
  await storage.saveTokens(
    accessToken: session.accessToken,
    refreshToken: session.refreshToken,
  );
  ref.read(accessTokenProvider.notifier).state = session.accessToken;
  ref.read(authUserProvider.notifier).state = session.user;
  ref.read(needsNicknameProvider.notifier).state = false;
  final deviceId = await ref.read(storageProvider).getOrCreateDeviceId();
  await ref.read(socketProvider).connect(
    session.accessToken,
    deviceId: deviceId,
  );
}

/// Restore JWT or sign in with persisted device id on cold start.
Future<void> bootstrapAuth(WidgetRef ref) async {
  final storage = ref.read(storageProvider);
  try {
    var token = await storage.getAccessToken();
    if (token != null) {
      ref.read(accessTokenProvider.notifier).state = token;
      try {
        final api = ref.read(apiProvider);
        final user = await api.me();
        ref.read(authUserProvider.notifier).state = user;
        ref.read(needsNicknameProvider.notifier).state = false;
        final deviceId = await storage.getOrCreateDeviceId();
        await ref.read(socketProvider).connect(token, deviceId: deviceId);
        return;
      } catch (_) {
        final api = ref.read(apiProvider);
        if (await api.refreshSession()) {
          token = await storage.getAccessToken();
          if (token != null) {
            ref.read(accessTokenProvider.notifier).state = token;
            try {
              final user = await api.me();
              ref.read(authUserProvider.notifier).state = user;
              ref.read(needsNicknameProvider.notifier).state = false;
              final deviceId = await storage.getOrCreateDeviceId();
              await ref.read(socketProvider).connect(
                token,
                deviceId: deviceId,
              );
              return;
            } catch (_) {
              /* fall through to clear */
            }
          }
        }
        await storage.clearAuth();
        ref.read(accessTokenProvider.notifier).state = null;
        token = null;
      }
    }

    final deviceId = await storage.getOrCreateDeviceId();
    final api = ref.read(apiProvider);
    final result = await api.deviceLogin(deviceId: deviceId);
    switch (result) {
      case DeviceAuthNeedsNickname():
        ref.read(needsNicknameProvider.notifier).state = true;
      case DeviceAuthSuccess():
        await applyAuthSession(ref, result);
    }
  } finally {
    ref.read(authReadyProvider.notifier).state = true;
  }
}
