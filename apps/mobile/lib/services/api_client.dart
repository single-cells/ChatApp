import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../models/auth_session.dart';
import '../models/message.dart';
import '../models/room.dart';
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
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final StorageService _storage;
  late final Dio _dio;

  Future<DeviceAuthResult> deviceLogin({
    required String deviceId,
    String? nickname,
  }) async {
    final res = await _dio.post('/auth/device', data: {
      'deviceId': deviceId,
      if (nickname != null && nickname.isNotEmpty) 'nickname': nickname,
    });
    return DeviceAuthResult.fromJson(res.data as Map<String, dynamic>);
  }

  Future<RoomSummary> createRoom(String title) async {
    final res = await _dio.post('/rooms', data: {'title': title});
    return RoomSummary.fromJson(res.data as Map<String, dynamic>);
  }

  Future<RoomSummary> getRoom(String roomId) async {
    final res = await _dio.get('/rooms/$roomId');
    return RoomSummary.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> joinRoom(String roomId) async {
    await _dio.post('/rooms/$roomId/join');
  }

  Future<void> leaveRoom(String roomId) async {
    await _dio.post('/rooms/$roomId/leave');
  }

  Future<void> deleteRoom(String roomId) async {
    await _dio.delete('/rooms/$roomId');
  }

  Future<List<RoomSummary>> recentRooms() async {
    final res = await _dio.get('/rooms/recent');
    final list = res.data as List<dynamic>;
    return list
        .map((e) => RoomSummary.fromJson(e as Map<String, dynamic>))
        .toList();
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
}
