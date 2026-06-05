import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/api.dart' show KeyParameter, ParametersWithRandom, PrivateKeyParameter, SecureRandom;
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/ecc/api.dart';
import 'package:pointycastle/ecc/curves/secp256r1.dart';
import 'package:pointycastle/signers/ecdsa_signer.dart';
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
  final ECDomainParameters _ecDomain = ECCurve_secp256r1();

  ECPrivateKey? _cachedPrivateKey;
  ECPublicKey? _cachedPublicKey;
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

    final publicKey = (await _getOrCreateKeyPair()).$2;
    final der = _encodeEcPublicKeyDer(publicKey);
    final pem = _pemEncode(der, 'PUBLIC KEY');
    _cachedPublicKeyPem = pem;
    return pem;
  }

  /// Signs [message] with SHA256withECDSA and returns base64(signature).
  Future<String> signToBase64(String message) async {
    try {
      return await _sign(message);
    } catch (_) {
      await _resetKeyPair();
      return _sign(message);
    }
  }

  Future<void> _resetKeyPair() async {
    _cachedPrivateKey = null;
    _cachedPublicKey = null;
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
    final signer = ECDSASigner(SHA256Digest());
    signer.init(
      true,
      ParametersWithRandom(
        PrivateKeyParameter<ECPrivateKey>(keyPair.$1),
        _secureRandom(),
      ),
    );
    final signature = signer.generateSignature(
      Uint8List.fromList(utf8.encode(message)),
    ) as ECSignature;
    return base64Encode(_encodeEcdsaSignatureDer(signature));
  }

  static Uint8List _encodeEcdsaSignatureDer(ECSignature signature) {
    final r = _derInteger(_unsignedBigIntBytes(signature.r));
    final s = _derInteger(_unsignedBigIntBytes(signature.s));
    return _derSequence(Uint8List.fromList([...r, ...s]));
  }

  static Uint8List _unsignedBigIntBytes(BigInt value) {
    if (value == BigInt.zero) return Uint8List.fromList([0]);
    final bytes = <int>[];
    var remaining = value;
    while (remaining > BigInt.zero) {
      bytes.insert(0, (remaining & BigInt.from(0xff)).toInt());
      remaining >>= 8;
    }
    return Uint8List.fromList(bytes);
  }

  static Uint8List _derInteger(List<int> value) {
    var start = 0;
    while (start < value.length - 1 && value[start] == 0) {
      start++;
    }
    final trimmed = value.sublist(start);
    final needsPadding = trimmed.isNotEmpty && (trimmed.first & 0x80) != 0;
    final bytes = needsPadding ? [0x00, ...trimmed] : trimmed;
    return Uint8List.fromList([0x02, ..._derLength(bytes.length), ...bytes]);
  }

  Future<(ECPrivateKey, ECPublicKey)> _getOrCreateKeyPair() async {
    if (_cachedPrivateKey != null && _cachedPublicKey != null) {
      return (_cachedPrivateKey!, _cachedPublicKey!);
    }

    final privateB64 = await _readKey(_privateKeyB64Key);
    final publicB64 = await _readKey(_publicKeyB64Key);
    if (privateB64 != null &&
        privateB64.isNotEmpty &&
        publicB64 != null &&
        publicB64.isNotEmpty) {
      try {
        final d = _bytesToBigInt(base64Decode(privateB64));
        final publicPoint = base64Decode(publicB64);
        if (publicPoint.length != 65 || publicPoint.first != 0x04) {
          throw StateError('Unsupported EC public key format in storage');
        }
        final q = _ecDomain.curve.decodePoint(publicPoint);
        if (q == null) {
          throw StateError('Invalid EC public key in storage');
        }

        _cachedPrivateKey = ECPrivateKey(d, _ecDomain);
        _cachedPublicKey = ECPublicKey(q, _ecDomain);
        return (_cachedPrivateKey!, _cachedPublicKey!);
      } catch (_) {
        await _deleteKey(_privateKeyB64Key);
        await _deleteKey(_publicKeyB64Key);
      }
    }

    await _deleteKey(_legacyPrivateKeyPemKey);
    await _deleteKey(_legacyPublicKeyPemKey);

    final d = _randomPrivateScalar();
    final q = (_ecDomain.G * d)!;
    final publicPoint = q.getEncoded(false);

    await _writeKey(_privateKeyB64Key, base64Encode(_fixedBigIntBytes(d, 32)));
    await _writeKey(_publicKeyB64Key, base64Encode(publicPoint));

    _cachedPrivateKey = ECPrivateKey(d, _ecDomain);
    _cachedPublicKey = ECPublicKey(q, _ecDomain);
    return (_cachedPrivateKey!, _cachedPublicKey!);
  }

  static Uint8List _encodeEcPublicKeyDer(ECPublicKey publicKey) {
    final publicPoint = publicKey.Q!.getEncoded(false);
    if (publicPoint.length != 65 || publicPoint.first != 0x04) {
      throw StateError('Unsupported EC public key format');
    }
    final algorithmIdentifier = _derSequence(
      Uint8List.fromList([
        // id-ecPublicKey: 1.2.840.10045.2.1
        0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01,
        // prime256v1 / secp256r1: 1.2.840.10045.3.1.7
        0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07,
      ]),
    );
    final subjectPublicKey = _derBitString(publicPoint);
    return _derSequence(
      Uint8List.fromList([...algorithmIdentifier, ...subjectPublicKey]),
    );
  }

  static Uint8List _derSequence(Uint8List value) {
    return Uint8List.fromList([0x30, ..._derLength(value.length), ...value]);
  }

  static Uint8List _derBitString(Uint8List value) {
    return Uint8List.fromList([
      0x03,
      ..._derLength(value.length + 1),
      0x00,
      ...value,
    ]);
  }

  static Uint8List _derLength(int length) {
    if (length < 0x80) return Uint8List.fromList([length]);
    final bytes = <int>[];
    var remaining = length;
    while (remaining > 0) {
      bytes.insert(0, remaining & 0xFF);
      remaining >>= 8;
    }
    return Uint8List.fromList([0x80 | bytes.length, ...bytes]);
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

  BigInt _randomPrivateScalar() {
    final random = Random.secure();
    while (true) {
      final bytes = Uint8List.fromList(
        List<int>.generate(32, (_) => random.nextInt(256)),
      );
      final d = _bytesToBigInt(bytes);
      if (d > BigInt.zero && d < _ecDomain.n) return d;
    }
  }

  static SecureRandom _secureRandom() {
    final secureRandom = SecureRandom('Fortuna');
    final random = Random.secure();
    final seed = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    secureRandom.seed(KeyParameter(seed));
    return secureRandom;
  }

  static BigInt _bytesToBigInt(List<int> bytes) {
    var result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte & 0xff);
    }
    return result;
  }

  static Uint8List _fixedBigIntBytes(BigInt value, int length) {
    final bytes = _unsignedBigIntBytes(value);
    if (bytes.length > length) {
      return Uint8List.fromList(bytes.sublist(bytes.length - length));
    }
    if (bytes.length == length) return bytes;
    return Uint8List.fromList([...List<int>.filled(length - bytes.length, 0), ...bytes]);
  }

  /// Generates a short idempotency key suitable for transfers.
  /// (Backend accepts up to 128 chars.)
  String newIdempotencyKey() {
    // Keep it URL/JSON friendly.
    final rand = Random.secure().nextInt(1 << 31);
    return 'mb_${DateTime.now().millisecondsSinceEpoch}_$rand';
  }
}
