import 'package:dio/dio.dart';

String? _errorCode(Object error) {
  if (error is! DioException) return null;
  final data = error.response?.data;
  if (data is Map && data['code'] is String) {
    return data['code'] as String;
  }
  return null;
}

bool isRoomPasswordRequired(Object error) =>
    _errorCode(error) == 'ROOM_PASSWORD_REQUIRED';

bool isRoomPasswordInvalid(Object error) =>
    _errorCode(error) == 'ROOM_PASSWORD_INVALID';

bool isRoomMissingError(Object error) {
  if (error is! DioException) return false;
  final code = error.response?.statusCode;
  if (code == 404) return true;
  if (error.response?.data is Map) {
    final msg =
        (error.response!.data as Map)['message']?.toString().toLowerCase() ??
            '';
    return msg.contains('not found') || msg.contains('room not found');
  }
  return false;
}
