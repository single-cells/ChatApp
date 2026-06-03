import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'device_key_service.dart';

class AuthChallenge {
  const AuthChallenge({
    required this.challengeId,
    required this.nonce,
    required this.expiresAt,
  });

  final String challengeId;
  final String nonce;
  final String expiresAt;

  factory AuthChallenge.fromJson(Map<String, dynamic> json) {
    return AuthChallenge(
      challengeId: json['challengeId'] as String,
      nonce: json['nonce'] as String,
      expiresAt: json['expiresAt'] as String,
    );
  }
}

class RequestSigner {
  RequestSigner(this._dio, this._deviceKeys);

  final Dio _dio;
  final DeviceKeyService _deviceKeys;

  Future<AuthChallenge> fetchChallenge() async {
    final res = await _dio.get('/auth/challenge');
    return AuthChallenge.fromJson(res.data as Map<String, dynamic>);
  }

  String deviceAuthBodyDigest(String deviceId, {String? nickname}) {
    final raw = '$deviceId|${nickname ?? ''}';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  String buildAuthCanonical({
    required String method,
    required String path,
    required AuthChallenge challenge,
    required String deviceId,
    required String bodySha256Hex,
  }) {
    return [
      method.toUpperCase(),
      path,
      challenge.challengeId,
      challenge.nonce,
      deviceId,
      bodySha256Hex,
    ].join('\n');
  }

  String hmacHex(String canonical) {
    final key = utf8.encode(AppConfig.clientAppSecret);
    final mac = Hmac(sha256, key);
    return mac.convert(utf8.encode(canonical)).toString();
  }

  Map<String, String> authHeaders({
    required String method,
    required String path,
    required AuthChallenge challenge,
    required String deviceId,
    required Map<String, dynamic> body,
  }) {
    final digest = deviceAuthBodyDigest(
      deviceId,
      nickname: body['nickname'] as String?,
    );
    final canonical = buildAuthCanonical(
      method: method,
      path: path,
      challenge: challenge,
      deviceId: deviceId,
      bodySha256Hex: digest,
    );
    return {
      'X-Client-Challenge-Id': challenge.challengeId,
      'X-Client-Nonce': challenge.nonce,
      'X-Client-Signature': hmacHex(canonical),
    };
  }

  Future<Map<String, dynamic>> buildDeviceAuthBody({
    required String deviceId,
    String? nickname,
  }) async {
    final challenge = await fetchChallenge();
    final keys = await _deviceKeys.ensureKeyPair();
    final payload = '${challenge.challengeId}|${challenge.nonce}|$deviceId';
    final deviceSignature = await _deviceKeys.sign(
      payload,
      privateKeyB64: keys.privateKeyB64,
    );
    return {
      'deviceId': deviceId,
      'challengeId': challenge.challengeId,
      'deviceSignature': deviceSignature,
      'publicKey': keys.publicKeyB64,
      if (nickname != null && nickname.isNotEmpty) 'nickname': nickname,
      '_challenge': challenge,
    };
  }

  Future<({Map<String, dynamic> body, Map<String, String> headers})>
      prepareDeviceLogin({
    required String deviceId,
    String? nickname,
  }) async {
    final raw = await buildDeviceAuthBody(
      deviceId: deviceId,
      nickname: nickname,
    );
    final challenge = raw.remove('_challenge') as AuthChallenge;
    final body = Map<String, dynamic>.from(raw);
    final headers = authHeaders(
      method: 'POST',
      path: '/auth/device',
      challenge: challenge,
      deviceId: deviceId,
      body: body,
    );
    return (body: body, headers: headers);
  }
}
