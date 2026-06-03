class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );
  static const wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'http://localhost:3000',
  );
  static const clientAppSecret = String.fromEnvironment(
    'CLIENT_APP_SECRET',
    defaultValue: 'dev-client-secret',
  );

  /// When true, accepts self-signed / untrusted TLS (dev bootstrap HTTPS only).
  static const allowInsecureSsl = bool.fromEnvironment(
    'ALLOW_INSECURE_SSL',
    defaultValue: false,
  );

  /// OTA check UI + startup prompt. Set true via --dart-define when bandwidth allows.
  static const enableAppUpdate = bool.fromEnvironment(
    'ENABLE_APP_UPDATE',
    defaultValue: false,
  );

  static String get updateManifestUrl {
    const override = String.fromEnvironment('UPDATE_MANIFEST_URL');
    if (override.isNotEmpty) return override;
    final base = apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/releases/latest.json';
  }
}
