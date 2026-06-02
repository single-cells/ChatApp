import '../config/app_config.dart';

/// Rewrites legacy MinIO URLs to authenticated API media proxy URLs.
abstract final class MediaUrlResolver {
  static String resolve(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final api = AppConfig.apiBaseUrl.replaceAll(RegExp(r'/$'), '');
    if (raw.startsWith(api)) return raw;

    final key = _extractKey(raw);
    if (key == null) return raw;
    return '$api/media/object?key=${Uri.encodeComponent(key)}';
  }

  static String? _extractKey(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return url.startsWith('rooms/') ? url : null;
    }
    final keyParam = uri.queryParameters['key'];
    if (keyParam != null && keyParam.isNotEmpty) return keyParam;

    final segments = uri.pathSegments;
    if (segments.isEmpty) return null;
    final bucketIdx = segments.indexOf('chat-media');
    if (bucketIdx >= 0 && bucketIdx + 1 < segments.length) {
      return segments.sublist(bucketIdx + 1).join('/');
    }
    if (segments.first == 'rooms') return segments.join('/');
    return null;
  }
}
