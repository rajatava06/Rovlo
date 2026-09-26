import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rovlo/services/e2ee_service.dart';

/// Two "phones" (alice, bob) and an eavesdropper (eve), each with their own key.
Future<(E2eeService, String)> _phone() async {
  final svc = E2eeService.forTesting();
  final pub = await svc.debugUseKeyPair(await X25519().newKeyPair());
  return (svc, pub);
}

void main() {
  test('text sealed by alice opens on bob\'s phone and on alice\'s own', () async {
    final (alice, aPub) = await _phone();
    final (bob, bPub) = await _phone();

    final session = alice.debugSessionWith(bPub);
    final sealed = await session.encryptText('Hello Bob — नमस्ते 🌍');

    expect(sealed.startsWith('v1.'), isTrue);
    expect(sealed.contains('Hello'), isFalse); // ciphertext, not plaintext
    expect(session.columns, {
      'is_encrypted': true,
      'sender_pub': aPub,
      'recipient_pub': bPub,
    });

    final atBob = await bob.decryptText(
        body: sealed, senderPub: aPub, recipientPub: bPub, iAmSender: false);
    expect(atBob, 'Hello Bob — नमस्ते 🌍');

    final atAlice = await alice.decryptText(
        body: sealed, senderPub: aPub, recipientPub: bPub, iAmSender: true);
    expect(atAlice, 'Hello Bob — नमस्ते 🌍');
  });

  test('every message uses a fresh nonce', () async {
    final (alice, _) = await _phone();
    final (_, bPub) = await _phone();
    final s = alice.debugSessionWith(bPub);
    expect(await s.encryptText('same'), isNot(await s.encryptText('same')));
  });

  test('an eavesdropper with another key cannot read it', () async {
    final (alice, aPub) = await _phone();
    final (_, bPub) = await _phone();
    final (eve, _) = await _phone();

    final sealed = await alice.debugSessionWith(bPub).encryptText('secret');
    expect(
      () => eve.decryptText(
          body: sealed, senderPub: aPub, recipientPub: bPub, iAmSender: false),
      throwsA(isA<E2eeException>().having((e) => e.keysChanged, 'keysChanged', true)),
    );
  });

  test('tampering with the ciphertext is detected', () async {
    final (alice, aPub) = await _phone();
    final (bob, bPub) = await _phone();
    final sealed = await alice.debugSessionWith(bPub).encryptText('pay 100');

    final bytes = base64Decode(sealed.substring(3));
    bytes[14] ^= 0x01; // flip one bit inside the ciphertext
    final forged = 'v1.${base64Encode(bytes)}';

    expect(
      () => bob.decryptText(
          body: forged, senderPub: aPub, recipientPub: bPub, iAmSender: false),
      throwsA(isA<E2eeException>()),
    );
  });

  test('history stays readable after the OTHER person gets a new key', () async {
    final (alice, aPub) = await _phone();
    final (bob, bPub) = await _phone();
    final sealed = await alice.debugSessionWith(bPub).encryptText('old message');

    // Bob reinstalls: new key. Alice still holds her key + the keys stored on
    // the message row, so she can read her old message.
    await _phone(); // (bob's new key — irrelevant to old rows)
    expect(
      await alice.decryptText(
          body: sealed, senderPub: aPub, recipientPub: bPub, iAmSender: true),
      'old message',
    );
    // Bob (old key still in memory here) can too.
    expect(
      await bob.decryptText(
          body: sealed, senderPub: aPub, recipientPub: bPub, iAmSender: false),
      'old message',
    );
  });

  test('photos round-trip through encryption', () async {
    final (alice, aPub) = await _phone();
    final (bob, bPub) = await _phone();
    final photo = Uint8List.fromList(List.generate(200000, (i) => i % 251));

    final blob = await alice.debugSessionWith(bPub).encryptBytes(photo);
    expect(blob.length, photo.length + 12 + 16); // nonce + tag overhead
    expect(blob.sublist(12, 40), isNot(photo.sublist(0, 28)));

    final back = await bob.decryptBytes(
        blob: blob, senderPub: aPub, recipientPub: bPub, iAmSender: false);
    expect(back, photo);
  });

  test('empty text stays empty (photo-only messages)', () async {
    final (alice, _) = await _phone();
    final (_, bPub) = await _phone();
    expect(await alice.debugSessionWith(bPub).encryptText(''), '');
  });

  test('encrypted-photo marker helpers', () {
    expect(E2eeService.isEncryptedImage('e2ee:abc/def.bin'), isTrue);
    expect(E2eeService.isEncryptedImage('https://x/y.jpg'), isFalse);
    expect(E2eeService.isEncryptedImage(null), isFalse);
    expect(E2eeService.imagePath('e2ee:abc/def.bin'), 'abc/def.bin');
  });
}
