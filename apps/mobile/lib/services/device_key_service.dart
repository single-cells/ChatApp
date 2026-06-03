import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeviceKeyMaterial {
  const DeviceKeyMaterial({
    required this.publicKeyB64,
    required this.privateKeyB64,
  });

  final String publicKeyB64;
  final String privateKeyB64;
}

class DeviceKeyService {
  DeviceKeyService() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _publicKeyKey = 'device_ed25519_public';
  static const _privateKeyKey = 'device_ed25519_private';

  final _algorithm = Ed25519();

  Future<DeviceKeyMaterial> ensureKeyPair() async {
    final existingPublic = await _storage.read(key: _publicKeyKey);
    final existingPrivate = await _storage.read(key: _privateKeyKey);
    if (existingPublic != null &&
        existingPrivate != null &&
        existingPublic.isNotEmpty &&
        existingPrivate.isNotEmpty) {
      return DeviceKeyMaterial(
        publicKeyB64: existingPublic,
        privateKeyB64: existingPrivate,
      );
    }
    final keyPair = await _algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
    final publicKeyB64 = base64Encode(publicKey.bytes);
    final privateKeyB64 = base64Encode(privateKeyBytes);
    await _storage.write(key: _publicKeyKey, value: publicKeyB64);
    await _storage.write(key: _privateKeyKey, value: privateKeyB64);
    return DeviceKeyMaterial(
      publicKeyB64: publicKeyB64,
      privateKeyB64: privateKeyB64,
    );
  }

  Future<String> sign(String message, {required String privateKeyB64}) async {
    final keyPair = await _algorithm.newKeyPairFromSeed(
      base64Decode(privateKeyB64),
    );
    final signature = await _algorithm.sign(
      utf8.encode(message),
      keyPair: keyPair,
    );
    return base64Encode(signature.bytes);
  }
}
