import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/room.dart';
import '../services/api_client.dart';
import '../services/app_update_service.dart';
import '../services/socket_service.dart';
import '../services/storage_service.dart';

final storageProvider = Provider((ref) => StorageService());

final apiProvider = Provider(
  (ref) => ApiClient(ref.watch(storageProvider)),
);

final appUpdateServiceProvider = Provider((ref) => AppUpdateService());

final socketProvider = Provider((ref) {
  final s = SocketService();
  ref.onDispose(s.disconnect);
  return s;
});

final authUserProvider = StateProvider<AuthUser?>((ref) => null);

final accessTokenProvider = StateProvider<String?>((ref) => null);

/// False until cold-start auth (token restore or device login) finishes.
final authReadyProvider = StateProvider<bool>((ref) => false);

/// True when device is known but user must pick a nickname on first launch.
final needsNicknameProvider = StateProvider<bool>((ref) => false);
