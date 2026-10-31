import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:savour/services/vault_cipher.dart';

void main() {
  group('Savour private vault encryption', () {
    final cipher = VaultCipher(VaultCipher.generateKey());
    test('full binary round trip', () async {
      final photo = Uint8List.fromList(List.generate(1024, (index) => index % 256));
      final encrypted = await cipher.encrypt(photo);
      expect(encrypted, isNot(photo));
      expect(encrypted.sublist(0, 4), [77, 79, 82, 49]);
      expect(await cipher.decrypt(encrypted), photo);
    });

    test('same input uses different random nonce', () async {
      final data = Uint8List.fromList([1, 2, 3]);
      final a = await cipher.encrypt(data);
      final b = await cipher.encrypt(data);
      expect(a, isNot(b));
      expect(a.toList(), isNot(equals(b.toList())));
    });

    test('modifying authenticated ciphertext is rejected', () async {
      final encrypted = await cipher.encrypt(Uint8List.fromList([23, 42, 99]));
      encrypted[encrypted.length - 1] ^= 0xff;
      expect(() => cipher.decrypt(encrypted), throwsA(isA<Exception>()));
    });

    test('unknown format is rejected', () async {
      expect(() => cipher.decrypt(Uint8List.fromList([1, 2, 3])), throwsFormatException);
    });
  });
}
