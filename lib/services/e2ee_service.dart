import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/backend/backend.dart';

/// Thrown when a message cannot be encrypted / decrypted.
class E2eeException implements Exception {
  E2eeException(this.message, {this.peerHasNoKey = false, this.keysChanged = false});

  final String message;

  /// The other person has not opened the updated app yet (no public key).
  final bool peerHasNoKey;

  /// This message was sealed with a private key this phone no longer has.
  final bool keysChanged;

  @override
  String toString() => message;
}

/// End-to-end encryption for one-to-one chats.
///
/// * Every device owns an **X25519** key pair. The private key lives only in the
///   phone's secure storage (Android Keystore / iOS Keychain); the public key is
///   published in `user_keys`.
/// * For a conversation both people derive the same secret
///   (X25519 → HKDF-SHA256) and seal every message with **AES-256-GCM**.
///   The server (and anybody with database access) only ever sees ciphertext.
/// * Each message stores the two public keys it was sealed with, so history stays
///   readable even after the *other* person reinstalls the app and gets a new key.
///
/// Limitation (by design, like most simple E2EE setups): the private key is not
/// backed up, so signing in on a new phone cannot read old messages.
class E2eeService {
  E2eeService._();
  static final E2eeService instance = E2eeService._();

  /// A separate instance with its own key (unit tests simulate two phones).
  @visibleForTesting
  E2eeService.forTesting();

  static const String _version = 'v1';
  static const String _imagePrefix = 'e2ee:';
  static const Duration _peerKeyTtl = Duration(minutes: 2);

  final X25519 _x25519 = X25519();
  final AesGcm _aes = AesGcm.with256bits();
  final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true, resetOnError: true),
  );

  String? _uid;
  SimpleKeyPair? _keyPair;
  String? _myPub;
  Future<void>? _initFuture;
  final Map<String, ({String pub, DateTime at})> _peerKeys = {};
  final Map<String, SecretKey> _secrets = {};

  /// Marker used in `messages.image_url` for encrypted photos.
  static bool isEncryptedImage(String? url) =>
      url != null && url.startsWith(_imagePrefix);
  static String imagePath(String url) => url.substring(_imagePrefix.length);

  String? get myPublicKey => _myPub;

  // ── Setup ───────────────────────────────────────────────────────────────────

  /// Loads (or creates) this user's key pair and publishes the public key.
  /// Safe to call repeatedly.
  Future<void> init(String userId) {
    if (_uid == userId && _keyPair != null) return Future.value();
    if (_uid == userId && _initFuture != null) return _initFuture!;
    _uid = userId;
    _keyPair = null;
    _myPub = null;
    _secrets.clear();
    _peerKeys.clear();
    return _initFuture = _init(userId).whenComplete(() => _initFuture = null);
  }

  /// Signed out: forget everything in memory (the private key stays on the
  /// device, so signing back in keeps the history readable).
  void reset() {
    _uid = null;
    _keyPair = null;
    _myPub = null;
    _secrets.clear();
    _peerKeys.clear();
  }

  Future<void> ensureReady() async {
    final uid = _uid ?? Backend.uid;
    if (uid == null) throw E2eeException('Not signed in.');
    await init(uid);
    if (_keyPair == null) {
      throw E2eeException('Secure messaging is not ready yet. Please try again.');
    }
  }

  String get _storageKey => 'rovlo_e2ee_sk_$_uid';

  Future<void> _init(String userId) async {
    SimpleKeyPair? pair;
    try {
      final saved = await _storage.read(key: _storageKey);
      if (saved != null && saved.isNotEmpty) {
        pair = await _x25519.newKeyPairFromSeed(base64Decode(saved));
      }
    } catch (e) {
      debugPrint('[E2EE] could not read the saved key: $e');
    }

    if (pair == null) {
      pair = await _x25519.newKeyPair();
      final seed = await pair.extractPrivateKeyBytes();
      try {
        await _storage.write(key: _storageKey, value: base64Encode(seed));
      } catch (e) {
        debugPrint('[E2EE] could not persist the key: $e');
      }
    }

    final pub = await pair.extractPublicKey();
    _keyPair = pair;
    _myPub = base64Encode(pub.bytes);
    await _publish(userId, _myPub!);
  }

  Future<void> _publish(String userId, String pub) async {
    if (!Backend.ready) return;
    try {
      final row = await Backend.client
          .from('user_keys')
          .select('public_key')
          .eq('user_id', userId)
          .maybeSingle();
      if (row != null && row['public_key'] == pub) return;
      await Backend.client.from('user_keys').upsert({
        'user_id': userId,
        'public_key': pub,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      // Not fatal now: sending is refused by the database until the key is
      // published, and ensureReady() retries on the next send.
      debugPrint('[E2EE] could not publish the public key: $e');
      _keyPair = null;
      _myPub = null;
    }
  }

  // ── Peer keys ───────────────────────────────────────────────────────────────

  Future<String> peerPublicKey(String peerId, {bool refresh = false}) async {
    final cached = _peerKeys[peerId];
    if (!refresh &&
        cached != null &&
        DateTime.now().difference(cached.at) < _peerKeyTtl) {
      return cached.pub;
    }
    final row = await Backend.client
        .from('user_keys')
        .select('public_key')
        .eq('user_id', peerId)
        .maybeSingle();
    final pub = row?['public_key'] as String?;
    if (pub == null || pub.isEmpty) {
      throw E2eeException(
        'This person has not set up secure chat yet. Ask them to open Rovlo once.',
        peerHasNoKey: true,
      );
    }
    _peerKeys[peerId] = (pub: pub, at: DateTime.now());
    return pub;
  }

  /// Test hook: use [pair] as this "phone's" key without storage / network.
  @visibleForTesting
  Future<String> debugUseKeyPair(SimpleKeyPair pair) async {
    _uid = 'test';
    _keyPair = pair;
    _myPub = base64Encode((await pair.extractPublicKey()).bytes);
    _secrets.clear();
    return _myPub!;
  }

  /// Test hook: encryption context for a peer whose public key is known.
  @visibleForTesting
  E2eeSession debugSessionWith(String peerPub) =>
      E2eeSession._(this, myPub: _myPub!, peerPub: peerPub);

  /// Opens an encryption context for sending to [peerId].
  Future<E2eeSession> sessionFor(String peerId, {bool refreshPeer = false}) async {
    await ensureReady();
    final peerPub = await peerPublicKey(peerId, refresh: refreshPeer);
    return E2eeSession._(this, myPub: _myPub!, peerPub: peerPub);
  }

  // ── Key derivation ──────────────────────────────────────────────────────────

  Future<SecretKey> _pairKey(String myPub, String peerPub) async {
    final cacheKey = '$myPub|$peerPub';
    final hit = _secrets[cacheKey];
    if (hit != null) return hit;

    final remote = SimplePublicKey(base64Decode(peerPub), type: KeyPairType.x25519);
    final shared = await _x25519.sharedSecretKey(
      keyPair: _keyPair!,
      remotePublicKey: remote,
    );
    // Both sides list the two public keys in the same (sorted) order.
    final sorted = [myPub, peerPub]..sort();
    final key = await _hkdf.deriveKey(
      secretKey: shared,
      nonce: utf8.encode('rovlo-e2ee-salt-$_version'),
      info: utf8.encode('rovlo-chat-$_version|${sorted.join('|')}'),
    );
    _secrets[cacheKey] = key;
    return key;
  }

  // ── Decrypting ──────────────────────────────────────────────────────────────

  /// Works out which public key belongs to the other person and makes sure the
  /// message was sealed with *my current* private key.
  Future<SecretKey> _keyForMessage({
    required String senderPub,
    required String recipientPub,
    required bool iAmSender,
  }) async {
    await ensureReady();
    final mine = iAmSender ? senderPub : recipientPub;
    final theirs = iAmSender ? recipientPub : senderPub;
    if (mine != _myPub) {
      throw E2eeException(
        'This message was sent to a previous device of yours.',
        keysChanged: true,
      );
    }
    return _pairKey(mine, theirs);
  }

  Future<String> decryptText({
    required String body,
    required String senderPub,
    required String recipientPub,
    required bool iAmSender,
  }) async {
    if (body.isEmpty) return '';
    try {
      final key = await _keyForMessage(
        senderPub: senderPub,
        recipientPub: recipientPub,
        iAmSender: iAmSender,
      );
      final bytes = _unwrap(body);
      final box = SecretBox.fromConcatenation(bytes, nonceLength: 12, macLength: 16);
      return utf8.decode(await _aes.decrypt(box, secretKey: key));
    } on E2eeException {
      rethrow;
    } catch (e) {
      throw E2eeException('This message could not be decrypted.');
    }
  }

  Future<Uint8List> decryptBytes({
    required Uint8List blob,
    required String senderPub,
    required String recipientPub,
    required bool iAmSender,
  }) async {
    try {
      final key = await _keyForMessage(
        senderPub: senderPub,
        recipientPub: recipientPub,
        iAmSender: iAmSender,
      );
      final box = SecretBox.fromConcatenation(blob, nonceLength: 12, macLength: 16);
      return Uint8List.fromList(await _aes.decrypt(box, secretKey: key));
    } on E2eeException {
      rethrow;
    } catch (e) {
      throw E2eeException('This photo could not be decrypted.');
    }
  }

  // ── Safety code ─────────────────────────────────────────────────────────────

  /// A short code both people can compare (in person / on a call) to make sure
  /// nobody is sitting in the middle. Identical on both phones.
  Future<String> safetyCode(String peerId) async {
    await ensureReady();
    final peerPub = await peerPublicKey(peerId, refresh: true);
    final sorted = [_myPub!, peerPub]..sort();
    final digest = crypto.sha256.convert(utf8.encode(sorted.join('|'))).bytes;
    final groups = <String>[];
    for (var i = 0; i < 6; i++) {
      final n = (digest[i * 2] << 8 | digest[i * 2 + 1]) % 100000;
      groups.add(n.toString().padLeft(5, '0'));
    }
    return groups.join(' ');
  }

  // ── Wire format ─────────────────────────────────────────────────────────────

  String _wrap(Uint8List bytes) => '$_version.${base64Encode(bytes)}';

  Uint8List _unwrap(String body) {
    final dot = body.indexOf('.');
    if (dot < 0 || body.substring(0, dot) != _version) {
      throw const FormatException('Unknown message format');
    }
    return base64Decode(body.substring(dot + 1));
  }

  static final Random _rng = Random.secure();
  static String randomName() =>
      List.generate(16, (_) => _rng.nextInt(36).toRadixString(36)).join();
}

/// Encrypts messages to one specific person with one specific pair of keys.
/// The public keys used are exactly what must be stored on the message row.
class E2eeSession {
  E2eeSession._(this._svc, {required this.myPub, required this.peerPub});

  final E2eeService _svc;
  final String myPub;
  final String peerPub;

  /// Text → `v1.<base64(nonce | ciphertext | tag)>`.
  Future<String> encryptText(String text) async {
    if (text.isEmpty) return '';
    final key = await _svc._pairKey(myPub, peerPub);
    final box = await _svc._aes.encrypt(utf8.encode(text), secretKey: key);
    return _svc._wrap(box.concatenation());
  }

  /// Photo bytes → `nonce | ciphertext | tag` (uploaded to the private bucket).
  Future<Uint8List> encryptBytes(Uint8List bytes) async {
    final key = await _svc._pairKey(myPub, peerPub);
    final box = await _svc._aes.encrypt(bytes, secretKey: key);
    return box.concatenation();
  }

  /// Row values every encrypted message must carry.
  Map<String, dynamic> get columns => {
        'is_encrypted': true,
        'sender_pub': myPub,
        'recipient_pub': peerPub,
      };
}
