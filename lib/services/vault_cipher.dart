import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// AES-256-GCM, with a fresh 96-bit nonce for every blob. Binary format:
/// ASCII "MOR1" (4 bytes) | nonce (12) | GCM MAC (16) | ciphertext.
/// A successful decrypt authenticates the entire encrypted content.
///
/// AES runs in pure Dart, which takes seconds for a full-size photo, so the
/// work happens on a background isolate to keep the UI responsive.
class VaultCipher {
  VaultCipher(Uint8List key)
      : assert(key.length == 32),
        _key = Uint8List.fromList(key);

  final Uint8List _key;
  static const _header = [77, 79, 82, 49]; // MOR1

  static Uint8List generateKey() {
    final random = Random.secure();
    return Uint8List.fromList(List<int>.generate(32, (_) => random.nextInt(256)));
  }

  Future<Uint8List> encrypt(Uint8List cleartext) {
    final key = _key;
    return Isolate.run(() => _encrypt(key, cleartext));
  }

  Future<Uint8List> decrypt(Uint8List encrypted) async {
    if (encrypted.length < 32 ||
        !_header.asMap().entries.every(
          (part) => encrypted[part.key] == part.value,
        )) {
      throw const FormatException('Unrecognised Savour vault file.');
    }
    final key = _key;
    return Isolate.run(() => _decrypt(key, encrypted));
  }

  static Future<Uint8List> _encrypt(Uint8List key, Uint8List cleartext) async {
    final algorithm = AesGcm.with256bits();
    final box = await algorithm.encrypt(
      cleartext,
      secretKey: SecretKey(key),
      nonce: algorithm.newNonce(),
    );
    final out = Uint8List(32 + box.cipherText.length)
      ..setAll(0, _header)
      ..setAll(4, box.nonce)
      ..setAll(16, box.mac.bytes)
      ..setAll(32, box.cipherText);
    return out;
  }

  static Future<Uint8List> _decrypt(Uint8List key, Uint8List encrypted) async {
    final box = SecretBox(
      encrypted.sublist(32),
      nonce: encrypted.sublist(4, 16),
      mac: Mac(encrypted.sublist(16, 32)),
    );
    return Uint8List.fromList(
      await AesGcm.with256bits().decrypt(box, secretKey: SecretKey(key)),
    );
  }
}
