import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// AES-256-GCM, with a fresh 96-bit nonce for every blob. Binary format:
/// ASCII "MOR1" (4 bytes) | nonce (12) | GCM MAC (16) | ciphertext.
/// A successful decrypt authenticates the entire encrypted content.
class VaultCipher {
  VaultCipher(Uint8List key)
      : assert(key.length == 32),
        _key = SecretKey(key);

  final SecretKey _key;
  final AesGcm _algorithm = AesGcm.with256bits();
  static const _header = [77, 79, 82, 49]; // MOR1

  static Uint8List generateKey() {
    final random = Random.secure();
    return Uint8List.fromList(List<int>.generate(32, (_) => random.nextInt(256)));
  }

  Future<Uint8List> encrypt(Uint8List cleartext) async {
    final nonce = _algorithm.newNonce();
    final box = await _algorithm.encrypt(
      cleartext,
      secretKey: _key,
      nonce: nonce,
    );
    return Uint8List.fromList([
      ..._header,
      ...nonce,
      ...box.mac.bytes,
      ...box.cipherText,
    ]);
  }

  Future<Uint8List> decrypt(Uint8List encrypted) async {
    if (encrypted.length < 32 ||
        !_header.asMap().entries.every(
          (part) => encrypted[part.key] == part.value,
        )) {
      throw const FormatException('Unrecognised Savour vault file.');
    }
    final box = SecretBox(
      encrypted.sublist(32),
      nonce: encrypted.sublist(4, 16),
      mac: Mac(encrypted.sublist(16, 32)),
    );
    return Uint8List.fromList(
      await _algorithm.decrypt(box, secretKey: _key),
    );
  }
}
