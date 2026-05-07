import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Provides a stable per-installation device id and an ECDSA P-256 keypair.
///
/// - `deviceId` is stored in SharedPreferences.
/// - EC key material is stored in secure storage (base64 bytes).
class DeviceIdentity {
  static const _deviceIdKey = 'deviceId';

  static const _privateKeyB64Key = 'ecPrivateKeyB64';
  static const _publicKeyB64Key = 'ecPublicKeyB64';

  // Cleanup legacy RSA keys after migration.
  static const _legacyPrivateKeyPemKey = 'rsaPrivateKeyPem';
  static const _legacyPublicKeyPemKey = 'rsaPublicKeyPem';

  final FlutterSecureStorage _secureStorage;
  final Ecdsa _ecdsa = Ecdsa.p256(Sha256());

  EcKeyPair? _cachedKeyPair;
  String? _cachedPublicKeyPem;

  DeviceIdentity({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.trim().isNotEmpty) return existing;

    final id = const Uuid().v4();
    await prefs.setString(_deviceIdKey, id);
    return id;
  }

  Future<String> getOrCreatePublicKeyPem() async {
    if (_cachedPublicKeyPem != null && _cachedPublicKeyPem!.trim().isNotEmpty) {
      return _cachedPublicKeyPem!;
    }

    final keyPair = await _getOrCreateKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final der = _encodeEcPublicKeyDer(publicKey);
    final pem = _pemEncode(der, 'PUBLIC KEY');
    _cachedPublicKeyPem = pem;
    return pem;
  }

  /// Signs [message] with SHA256withECDSA and returns base64(signature).
  Future<String> signToBase64(String message) async {
    try {
      return _sign(message);
    } catch (_) {
      await _resetKeyPair();
      return _sign(message);
    }
  }

  Future<void> _resetKeyPair() async {
    _cachedKeyPair = null;
    _cachedPublicKeyPem = null;
    await _deleteKey(_privateKeyB64Key);
    await _deleteKey(_publicKeyB64Key);
    await _deleteKey(_legacyPrivateKeyPemKey);
    await _deleteKey(_legacyPublicKeyPemKey);
    await _getOrCreateKeyPair();
  }

  Future<String?> _readKey(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }
    return _secureStorage.read(key: key);
  }

  Future<void> _writeKey(String key, String? value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      if (value == null) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, value);
      }
      return;
    }
    await _secureStorage.write(key: key, value: value);
  }

  Future<void> _deleteKey(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      return;
    }
    await _secureStorage.delete(key: key);
  }

  Future<String> _sign(String message) async {
    final keyPair = await _getOrCreateKeyPair();
    final sig = await _ecdsa.sign(utf8.encode(message), keyPair: keyPair);
    return base64Encode(sig.bytes);
  }

  Future<EcKeyPair> _getOrCreateKeyPair() async {
    if (_cachedKeyPair != null) {
      return _cachedKeyPair!;
    }

    final privateB64 = await _readKey(_privateKeyB64Key);
    final publicB64 = await _readKey(_publicKeyB64Key);
    if (privateB64 != null && privateB64.isNotEmpty && publicB64 != null && publicB64.isNotEmpty) {
      try {
        final d = base64Decode(privateB64);
        final publicPoint = base64Decode(publicB64);
        if (publicPoint.length != 65 || publicPoint.first != 0x04) {
          throw StateError('Unsupported EC public key format in storage');
        }
        final x = publicPoint.sublist(1, 33);
        final y = publicPoint.sublist(33, 65);

        _cachedKeyPair = EcKeyPairData(
          d: d,
          x: x,
          y: y,
          type: KeyPairType.p256,
        );
        return _cachedKeyPair!;
      } catch (_) {
        await _deleteKey(_privateKeyB64Key);
        await _deleteKey(_publicKeyB64Key);
      }
    }

    await _deleteKey(_legacyPrivateKeyPemKey);
    await _deleteKey(_legacyPublicKeyPemKey);

    final newKeyPair = await _ecdsa.newKeyPair();
    final extracted = await newKeyPair.extract();
    final publicKey = await newKeyPair.extractPublicKey();
    final publicPoint = Uint8List.fromList([0x04, ...publicKey.x, ...publicKey.y]);

    await _writeKey(_privateKeyB64Key, base64Encode(extracted.d));
    await _writeKey(_publicKeyB64Key, base64Encode(publicPoint));

    _cachedKeyPair = EcKeyPairData(
      d: extracted.d,
      x: publicKey.x,
      y: publicKey.y,
      type: KeyPairType.p256,
    );
    return _cachedKeyPair!;
  }

  static Uint8List _encodeEcPublicKeyDer(EcPublicKey publicKey) {
    return publicKey.toDer();
  }

  static String _pemEncode(Uint8List der, String label) {
    final b64 = base64Encode(der);
    final chunks = <String>[];
    for (var i = 0; i < b64.length; i += 64) {
      final end = (i + 64 < b64.length) ? i + 64 : b64.length;
      chunks.add(b64.substring(i, end));
    }
    return '-----BEGIN $label-----\n${chunks.join('\n')}\n-----END $label-----';
  }

  /// Generates a short idempotency key suitable for transfers.
  /// (Backend accepts up to 128 chars.)
  String newIdempotencyKey() {
    // Keep it URL/JSON friendly.
    final rand = Random.secure().nextInt(1 << 31);
    return 'mb_${DateTime.now().millisecondsSinceEpoch}_$rand';
  }
}
