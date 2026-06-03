import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../models/auth_session.dart';
import '../models/message.dart';
import '../models/room.dart';
import 'device_key_service.dart';
import 'request_signer.dart';
import 'storage_service.dart';

class ApiClient {
  ApiClient(this._storage) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    _deviceKeys = DeviceKeyService();
    _signer = RequestSigner(_dio, _deviceKeys);
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          final deviceId = await _storage.getOrCreateDeviceId();
          options.headers['X-Device-Id'] = deviceId;
          handler.next(options);
        },
      ),
    );
  }

  final StorageService _storage;
  late final Dio _dio;
  late final DeviceKeyService _deviceKeys;
  late final RequestSigner _signer;


  Future<DeviceAuthResult> deviceLogin({
    required String deviceId,
    String? nickname,
  }) async {
    final prepared = await _signer.prepareDeviceLogin(
      deviceId: deviceId,
      nickname: nickname,
    );
    final res = await _dio.post(
      '/auth/device',
      data: prepared.body,
      options: Options(headers: prepared.headers),
    );
    return DeviceAuthResult.fromJson(res.data as Map<String, dynamic>);
  }

  Future<bool> refreshSession() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null) return false;
    try {
      final deviceId = await _storage.getOrCreateDeviceId();
      final res = await _dio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(headers: {'X-Device-Id': deviceId}),
      );
      final data = res.data as Map<String, dynamic>;
      await _storage.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<RoomSummary> createRoom(String title, {String? password}) async {
    final res = await _dio.post(
      '/rooms',
      data: {
        'title': title,
        if (password != null && password.isNotEmpty) 'password': password,
      },
    );
    return RoomSummary.fromJson(res.data as Map<String, dynamic>);
  }

  Future<RoomSummary> getRoom(String roomId) async {
    final res = await _dio.get('/rooms/$roomId');
    return RoomSummary.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> joinRoom(String roomId, {String? password}) async {
    await _dio.post(
      '/rooms/$roomId/join',
      data: {
        if (password != null && password.isNotEmpty) 'password': password,
      },
    );
  }

  Future<void> updateRoomPassword(String roomId, {String? password}) async {
    await _dio.patch(
      '/rooms/$roomId/password',
      data: {'password': password ?? ''},
    );
  }

  Future<void> leaveRoom(String roomId) async {
    await _dio.post('/rooms/$roomId/leave');
  }

  /// Remove local recent entry when the room no longer exists.
  Future<void> dismissRoomMembership(String roomId) async {
    await _dio.delete('/rooms/$roomId/membership');
  }

  Future<void> deleteRoom(String roomId) async {
    await _dio.delete('/rooms/$roomId');
  }

  Future<({List<RoomSummary> items, int prunedCount})> recentRooms() async {
    final res = await _dio.get('/rooms/recent');
    final data = res.data;
    if (data is Map<String, dynamic>) {
      final list = data['items'] as List<dynamic>? ?? [];
      return (
        items: list
            .map((e) => RoomSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
        prunedCount: (data['prunedCount'] as num?)?.toInt() ?? 0,
      );
    }
    final list = data as List<dynamic>;
    return (
      items: list
          .map((e) => RoomSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      prunedCount: 0,
    );
  }

  Future<List<RoomSummary>> listAllRooms() async {
    final res = await _dio.get('/rooms/all');
    final list = res.data as List<dynamic>;
    return list
        .map((e) => RoomSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<({int count, int max})> createdRoomQuota() async {
    final res = await _dio.get('/rooms/created-quota');
    final data = res.data as Map<String, dynamic>;
    return (
      count: data['count'] as int,
      max: data['max'] as int,
    );
  }

  Future<List<ChatMessage>> fetchMessages(
    String roomId, {
    int? before,
    int? after,
    int limit = 50,
  }) async {
    final res = await _dio.get(
      '/rooms/$roomId/messages',
      queryParameters: {
        if (before != null) 'before': before,
        if (after != null) 'after': after,
        'limit': limit,
      },
    );
    final list = res.data as List<dynamic>;
    return list
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> presignUpload({
    required String roomId,
    required String kind,
    required String mime,
    String? filename,
  }) async {
    final res = await _dio.post(
      '/rooms/$roomId/uploads/presign',
      data: {
        'kind': kind,
        'mime': mime,
        if (filename != null) 'filename': filename,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  /// Upload via API (avoids direct MinIO connection from the device).
  Future<Map<String, dynamic>> uploadMedia({
    required String roomId,
    required List<int> bytes,
    required String kind,
    required String mime,
    String? filename,
  }) async {
    final formData = FormData.fromMap({
      'kind': kind,
      'mime': mime,
      if (filename != null) 'filename': filename,
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename ?? 'upload',
      ),
    });
    final res = await _dio.post('/rooms/$roomId/uploads', data: formData);
    return res.data as Map<String, dynamic>;
  }

  @Deprecated('Use uploadMedia — presigned MinIO URLs are often unreachable on device')
  Future<void> uploadFile(String uploadUrl, List<int> bytes, String mime) async {
    await Dio().put(
      uploadUrl,
      data: bytes,
      options: Options(
        headers: {'Content-Type': mime},
        contentType: mime,
      ),
    );
  }

  Future<Map<String, dynamic>> voiceToken(String roomId) async {
    final res = await _dio.post('/rooms/$roomId/voice/token');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> health() async {
    final res = await _dio.get('/health');
    return res.data as Map<String, dynamic>;
  }

  Future<AuthUser> me() async {
    final res = await _dio.get('/auth/me');
    return AuthUser.fromJson(res.data as Map<String, dynamic>);
  }

  Future<AuthUser> updateNickname(String nickname) async {
    final res = await _dio.patch(
      '/auth/nickname',
      data: {'nickname': nickname},
    );
    return AuthUser.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteAccount() async {
    await _dio.delete('/auth/account');
  }
}
