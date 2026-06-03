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
}
