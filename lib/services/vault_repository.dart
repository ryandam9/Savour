import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image/image.dart' as im;
import 'package:path_provider/path_provider.dart';

import '../models/food_entry.dart';
import 'vault_cipher.dart';

/// All original photos, thumbnails and the journal index are encrypted at rest.
/// The AES key is kept in the platform keychain/keystore, not in the vault.
class VaultRepository extends ChangeNotifier {
  VaultRepository({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _keyName = 'savour.v1.key';
  static const _lockName = 'savour.v1.appLock';
  final FlutterSecureStorage _secureStorage;
  late final Directory _directory;
  late final VaultCipher _cipher;
  final Map<String, Uint8List> _thumbnailCache = {};
  List<FoodEntry> _entries = [];
  bool _ready = false;

  List<FoodEntry> get entries => List.unmodifiable(_entries);
  int get count => _entries.length;
  bool get isReady => _ready;
  int get favouriteCount => _entries.where((e) => e.isFavourite).length;

  File get _index => File('${_directory.path}/journal.mor');
  File _photo(String id) => File('${_directory.path}/$id.photo.mor');
  File _thumb(String id) => File('${_directory.path}/$id.thumb.mor');

  Future<void> initialise() async {
    final base = await getApplicationSupportDirectory();
    _directory = Directory('${base.path}/savour_vault');
    await _directory.create(recursive: true);
    final encodedKey = await _secureStorage.read(key: _keyName);
    if (encodedKey == null) {
      // Never silently orphan existing data after a keychain/keystore reset.
      if (await _index.exists() ||
          (await _directory.list().any((entity) => entity.path.endsWith('.mor') || entity.path.endsWith('.mor.pending')))) {
        throw const VaultException(
          'Your encrypted vault exists, but its security key is unavailable. '
          'No files have been changed. Restore the key using your device backup.',
        );
      }
      final fresh = VaultCipher.generateKey();
      await _secureStorage.write(key: _keyName, value: base64Encode(fresh));
      _cipher = VaultCipher(fresh);
    } else {
      final key = base64Decode(encodedKey);
      if (key.length != 32) {
        throw const VaultException('Your vault security key is invalid.');
      }
      _cipher = VaultCipher(Uint8List.fromList(key));
    }
    if (await _index.exists()) {
      try {
        final encrypted = await _index.readAsBytes();
        final clear = await _cipher.decrypt(encrypted);
        final decoded = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
        if (decoded['version'] != 1) {
          throw const FormatException('Unsupported vault format.');
        }
        _entries = (decoded['entries'] as List<dynamic>)
            .map((entry) => FoodEntry.fromJson(entry as Map<String, dynamic>))
            .toList();
      } catch (error) {
        throw VaultException('The encrypted journal could not be opened: $error');
      }
    }
    _sortEntries();
    _ready = true;
    notifyListeners();
  }

  Future<bool> getAppLockEnabled() async =>
      await _secureStorage.read(key: _lockName) == 'yes';

  Future<void> setAppLockEnabled(bool enabled) =>
      _secureStorage.write(key: _lockName, value: enabled ? 'yes' : 'no');

  void _sortEntries() {
    _entries.sort((a, b) => b.eatenAt.compareTo(a.eatenAt));
  }

  Future<void> _saveIndex() async {
    final clear = Uint8List.fromList(utf8.encode(jsonEncode({
      'version': 1,
      'entries': _entries.map((e) => e.toJson()).toList(),
    })));
    final encrypted = await _cipher.encrypt(clear);
    final pending = File('${_index.path}.pending');
    await pending.writeAsBytes(encrypted, flush: true);
    await pending.rename(_index.path);
  }

  Future<FoodEntry> addPhoto(
    Uint8List photo, {
    required DateTime eatenAt,
    String name = '',
    String description = '',
  }) async {
    if (!_ready) { throw const VaultException('Vault is not ready.'); }
    if (photo.isEmpty) { throw const VaultException('The selected photo is empty.'); }
    final now = DateTime.now();
    final random = Random.secure();
    final id = '${now.microsecondsSinceEpoch}_${random.nextInt(0x7fffffff).toRadixString(16)}';
    final entry = FoodEntry(
      id: id,
      eatenAt: eatenAt,
      createdAt: now,
      name: name.trim(),
      description: description.trim(),
    );
    try {
      final thumbnail = await compute(_generateThumbnail, photo);
      await _photo(id).writeAsBytes(await _cipher.encrypt(photo), flush: true);
      await _thumb(id).writeAsBytes(await _cipher.encrypt(thumbnail), flush: true);
      _entries.add(entry);
      _sortEntries();
      await _saveIndex();
      _rememberThumbnail(id, thumbnail);
      notifyListeners();
      return entry;
    } catch (_) {
      _entries.removeWhere((item) => item.id == id);
      await _deleteIfExists(_photo(id));
      await _deleteIfExists(_thumb(id));
      rethrow;
    }
  }

  Future<void> update(FoodEntry changed) async {
    final old = List<FoodEntry>.of(_entries);
    final index = _entries.indexWhere((entry) => entry.id == changed.id);
    if (index < 0) { throw const VaultException('This photo no longer exists.'); }
    _entries[index] = changed;
    _sortEntries();
    try {
      await _saveIndex();
      notifyListeners();
    } catch (_) {
      _entries = old;
      rethrow;
    }
  }

  Future<void> toggleFavourite(FoodEntry entry) =>
      update(entry.copyWith(isFavourite: !entry.isFavourite));

  Future<void> delete(FoodEntry entry) async {
    final old = List<FoodEntry>.of(_entries);
    _entries.removeWhere((item) => item.id == entry.id);
    try {
      await _saveIndex();
    } catch (_) {
      _entries = old;
      rethrow;
    }
    _thumbnailCache.remove(entry.id);
    notifyListeners();
    // Stale orphaned encrypted files can be cleaned later if a deletion fails.
    await _deleteIfExists(_photo(entry.id));
    await _deleteIfExists(_thumb(entry.id));
  }

  Future<void> deleteEverything() async {
    final old = List<FoodEntry>.of(_entries);
    _entries = [];
    try {
      await _saveIndex();
    } catch (_) {
      _entries = old;
      rethrow;
    }
    _thumbnailCache.clear();
    notifyListeners();
    for (final entry in old) {
      await _deleteIfExists(_photo(entry.id));
      await _deleteIfExists(_thumb(entry.id));
    }
  }

  Future<Uint8List> thumbnail(String id) async {
    final cached = _thumbnailCache[id];
    if (cached != null) { return cached; }
    final file = _thumb(id);
    final data = await _cipher.decrypt(await file.readAsBytes());
    _rememberThumbnail(id, data);
    return data;
  }

  Future<Uint8List> photo(String id) async =>
      _cipher.decrypt(await _photo(id).readAsBytes());

  void _rememberThumbnail(String id, Uint8List data) {
    _thumbnailCache.remove(id);
    _thumbnailCache[id] = data;
    if (_thumbnailCache.length > 48) {
      _thumbnailCache.remove(_thumbnailCache.keys.first);
    }
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) { await file.delete(); }
  }
}

class VaultException implements Exception {
  const VaultException(this.message);
  final String message;
  @override
  String toString() => message;
}

Uint8List _generateThumbnail(Uint8List bytes) {
  final decoded = im.decodeImage(bytes);
  if (decoded == null) {
    // Native HEIC and other formats can remain supported by the device codec.
    return bytes;
  }
  final upright = im.bakeOrientation(decoded);
  final shorter = upright.width < upright.height ? upright.width : upright.height;
  if (shorter <= 720 && upright.width <= 1100 && upright.height <= 1100) {
    return Uint8List.fromList(im.encodeJpg(upright, quality: 82));
  }
  final reduced = upright.width >= upright.height
      ? im.copyResize(upright, width: 960)
      : im.copyResize(upright, height: 960);
  return Uint8List.fromList(im.encodeJpg(reduced, quality: 82));
}
