import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final _storage = const FlutterSecureStorage();
  static const _deviceIdKey = 'device_id';
  static const _themePresetKey = 'theme_preset_id';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: 'access_token', value: accessToken);
    await _storage.write(key: 'refresh_token', value: refreshToken);
  }

  Future<String?> getAccessToken() => _storage.read(key: 'access_token');

  Future<String?> getRefreshToken() => _storage.read(key: 'refresh_token');

  /// Stable per-install identity for device login.
  Future<String> getOrCreateDeviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final id = const Uuid().v4();
    await _storage.write(key: _deviceIdKey, value: id);
    return id;
  }

  /// Clears session tokens only; keeps [device_id] for the next device login.
  Future<String?> getThemePresetId() => _storage.read(key: _themePresetKey);

  Future<void> saveThemePresetId(String id) =>
      _storage.write(key: _themePresetKey, value: id);

  Future<void> clearAuth() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  Future<void> clear() async {
    await _storage.deleteAll();
  }
}
