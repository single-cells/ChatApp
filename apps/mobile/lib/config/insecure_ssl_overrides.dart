import 'dart:io';

/// Trusts any server certificate. Only enable via [AppConfig.allowInsecureSsl]
/// for self-signed HTTPS (e.g. nginx bootstrap); never for production LE certs.
class InsecureSslOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (_, __, ___) => true;
    return client;
  }
}

void applyInsecureSslIfConfigured(bool enabled) {
  if (enabled) {
    HttpOverrides.global = InsecureSslOverrides();
  }
}
