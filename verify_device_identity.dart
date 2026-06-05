import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/api.dart'
    show KeyParameter, ParametersWithRandom, PrivateKeyParameter, PublicKeyParameter, SecureRandom;
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/ecc/api.dart';
import 'package:pointycastle/ecc/curves/secp256r1.dart';
import 'package:pointycastle/signers/ecdsa_signer.dart';

void main() {
  final domain = ECCurve_secp256r1();
  final privateScalar = _randomPrivateScalar(domain);
  final publicPoint = (domain.G * privateScalar)!;
  final privateKey = ECPrivateKey(privateScalar, domain);
  final publicKey = ECPublicKey(publicPoint, domain);
  const message = 'from=1111111111758&to=6868686883244&amount=500000.00';

  final signer = ECDSASigner(SHA256Digest());
  signer.init(
    true,
    ParametersWithRandom(
      PrivateKeyParameter<ECPrivateKey>(privateKey),
      _secureRandom(),
    ),
  );

  final signature = signer.generateSignature(
    Uint8List.fromList(utf8.encode(message)),
  ) as ECSignature;
  final der = _encodeEcdsaSignatureDer(signature);

  final verifier = ECDSASigner(SHA256Digest());
  verifier.init(false, PublicKeyParameter<ECPublicKey>(publicKey));
  final verified = verifier.verifySignature(
    Uint8List.fromList(utf8.encode(message)),
    signature,
  );

  if (!verified || der.isEmpty || der.first != 0x30) {
    throw StateError('Device identity ECDSA verification failed');
  }

  stdout.writeln('Device identity ECDSA OK');
  stdout.writeln('DER signature base64: ${base64Encode(der)}');
}

BigInt _randomPrivateScalar(ECDomainParameters domain) {
  final random = Random.secure();
  while (true) {
    final bytes = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    final d = _bytesToBigInt(bytes);
    if (d > BigInt.zero && d < domain.n) return d;
  }
}

SecureRandom _secureRandom() {
  final secureRandom = SecureRandom('Fortuna');
  final random = Random.secure();
  final seed = Uint8List.fromList(
    List<int>.generate(32, (_) => random.nextInt(256)),
  );
  secureRandom.seed(KeyParameter(seed));
  return secureRandom;
}

Uint8List _encodeEcdsaSignatureDer(ECSignature signature) {
  final r = _derInteger(_unsignedBigIntBytes(signature.r));
  final s = _derInteger(_unsignedBigIntBytes(signature.s));
  return _derSequence(Uint8List.fromList([...r, ...s]));
}

Uint8List _unsignedBigIntBytes(BigInt value) {
  if (value == BigInt.zero) return Uint8List.fromList([0]);
  final bytes = <int>[];
  var remaining = value;
  while (remaining > BigInt.zero) {
    bytes.insert(0, (remaining & BigInt.from(0xff)).toInt());
    remaining >>= 8;
  }
  return Uint8List.fromList(bytes);
}

Uint8List _derInteger(List<int> value) {
  var start = 0;
  while (start < value.length - 1 && value[start] == 0) {
    start++;
  }
  final trimmed = value.sublist(start);
  final needsPadding = trimmed.isNotEmpty && (trimmed.first & 0x80) != 0;
  final bytes = needsPadding ? [0x00, ...trimmed] : trimmed;
  return Uint8List.fromList([0x02, ..._derLength(bytes.length), ...bytes]);
}

Uint8List _derSequence(Uint8List value) {
  return Uint8List.fromList([0x30, ..._derLength(value.length), ...value]);
}

Uint8List _derLength(int length) {
  if (length < 0x80) return Uint8List.fromList([length]);
  final bytes = <int>[];
  var remaining = length;
  while (remaining > 0) {
    bytes.insert(0, remaining & 0xff);
    remaining >>= 8;
  }
  return Uint8List.fromList([0x80 | bytes.length, ...bytes]);
}

BigInt _bytesToBigInt(List<int> bytes) {
  var result = BigInt.zero;
  for (final byte in bytes) {
    result = (result << 8) | BigInt.from(byte & 0xff);
  }
  return result;
}