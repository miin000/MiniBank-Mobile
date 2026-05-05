import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Provides a stable per-installation device id and an RSA keypair.
///
/// - `deviceId` is stored in SharedPreferences.
/// - RSA keys are stored in secure storage (PEM).
class DeviceIdentity {
  static const _deviceIdKey = 'deviceId';

  static const _privateKeyPemKey = 'rsaPrivateKeyPem';
  static const _publicKeyPemKey = 'rsaPublicKeyPem';

  final FlutterSecureStorage _secureStorage;

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
    final existing = await _secureStorage.read(key: _publicKeyPemKey);
    if (existing != null && existing.trim().isNotEmpty) return existing;

    await _ensureKeyPair();
    final created = await _secureStorage.read(key: _publicKeyPemKey);
    if (created == null || created.trim().isEmpty) {
      throw StateError('Failed to create RSA public key');
    }
    return created;
  }

  Future<String> _getOrCreatePrivateKeyPem() async {
    final existing = await _secureStorage.read(key: _privateKeyPemKey);
    if (existing != null && existing.trim().isNotEmpty) return existing;

    await _ensureKeyPair();
    final created = await _secureStorage.read(key: _privateKeyPemKey);
    if (created == null || created.trim().isEmpty) {
      throw StateError('Failed to create RSA private key');
    }
    return created;
  }

  Future<void> _ensureKeyPair() async {
    final pub = await _secureStorage.read(key: _publicKeyPemKey);
    final priv = await _secureStorage.read(key: _privateKeyPemKey);
    if (pub != null && pub.trim().isNotEmpty && priv != null && priv.trim().isNotEmpty) {
      return;
    }

    // Generating a 2048-bit RSA keypair can take noticeable CPU time.
    // Do it on a background isolate to avoid blocking the UI isolate.
    final pems = await Isolate.run(() {
      final pair = CryptoUtils.generateRSAKeyPair();
      final privatePem = CryptoUtils.encodeRSAPrivateKeyToPemPkcs1(
        pair.privateKey as RSAPrivateKey,
      );
      final publicPem = CryptoUtils.encodeRSAPublicKeyToPem(
        pair.publicKey as RSAPublicKey,
      );
      return <String, String>{
        'private': privatePem,
        'public': publicPem,
      };
    });

    await _secureStorage.write(key: _privateKeyPemKey, value: pems['private']);
    await _secureStorage.write(key: _publicKeyPemKey, value: pems['public']);
  }

  /// Signs [message] with SHA256withRSA and returns base64(signature).
  Future<String> signToBase64(String message) async {
    final privatePem = await _getOrCreatePrivateKeyPem();
    final privateKey = CryptoUtils.rsaPrivateKeyFromPem(privatePem);

    final signer = Signer('SHA-256/RSA');
    signer.init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    final sig = signer.generateSignature(Uint8List.fromList(utf8.encode(message))) as RSASignature;
    return base64Encode(sig.bytes);
  }

  /// Generates a short idempotency key suitable for transfers.
  /// (Backend accepts up to 128 chars.)
  String newIdempotencyKey() {
    // Keep it URL/JSON friendly.
    final rand = Random.secure().nextInt(1 << 31);
    return 'mb_${DateTime.now().millisecondsSinceEpoch}_$rand';
  }
}
