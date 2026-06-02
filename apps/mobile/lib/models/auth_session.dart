import 'room.dart';

sealed class DeviceAuthResult {
  const DeviceAuthResult();

  factory DeviceAuthResult.fromJson(Map<String, dynamic> json) {
    if (json['needsNickname'] == true) {
      return const DeviceAuthNeedsNickname();
    }
    return DeviceAuthSuccess(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      isNewUser: json['isNewUser'] as bool? ?? false,
    );
  }
}

class DeviceAuthNeedsNickname extends DeviceAuthResult {
  const DeviceAuthNeedsNickname();
}

class DeviceAuthSuccess extends DeviceAuthResult {
  const DeviceAuthSuccess({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    required this.isNewUser,
  });

  final String accessToken;
  final String refreshToken;
  final AuthUser user;
  final bool isNewUser;
}
