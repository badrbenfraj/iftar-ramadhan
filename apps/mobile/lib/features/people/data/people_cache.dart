import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/settings/settings_controller.dart';
import '../../../core/settings/settings_storage.dart';
import '../domain/fasting_person.dart';

class CachedPeople {
  const CachedPeople(this.people, this.syncedAt);

  final List<FastingPerson> people;

  /// When this list was loaded from the server.
  final DateTime syncedAt;
}

/// The region's people list kept on the phone, so volunteers can identify
/// people with no connection (spec 2A §5.4). Best effort: a storage error
/// reads as "nothing saved" and never breaks the app.
abstract interface class PeopleCache {
  /// The saved list for [regionId]; null when none, another region's, or
  /// unreadable.
  Future<CachedPeople?> read({required int regionId});

  Future<void> write({
    required int regionId,
    required List<FastingPerson> people,
    required DateTime syncedAt,
  });

  /// On logout: the list holds names, CIN and phone numbers. After it,
  /// writes are ignored until [open].
  Future<void> clear();

  /// After a sign-in: writes are accepted again (see [clear]).
  void open();
}

/// AES-GCM encrypted file; the 256-bit key lives in the platform keystore.
class EncryptedFilePeopleCache implements PeopleCache {
  EncryptedFilePeopleCache({
    required this._directory,
    required this._keys,
  });

  static const fileName = 'people_cache.bin';
  static const keyName = 'people_cache_key';
  static const _version = 1;

  final Future<Directory> Function() _directory;
  final SettingsStorage _keys;
  final AesGcm _algorithm = AesGcm.with256bits();

  /// Writes and clears run one after another, in call order, so a clear on
  /// logout always lands after any write already started.
  Future<void> _queue = Future.value();

  /// Set by [clear]; a write that runs after it is dropped.
  bool _closed = false;

  Future<void> _enqueue(Future<void> Function() op) {
    final next = _queue.then((_) => op());
    _queue = next.catchError((_) {});
    return next;
  }

  Future<File> _file() async => File('${(await _directory()).path}/$fileName');

  Future<SecretKey> _key({required bool create}) async {
    final stored = await _keys.read(keyName);
    if (stored != null) return SecretKey(base64Decode(stored));
    if (!create) throw StateError('No people cache key');
    final key = await _algorithm.newSecretKey();
    await _keys.write(keyName, base64Encode(await key.extractBytes()));
    return key;
  }

  @override
  Future<CachedPeople?> read({required int regionId}) async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final box = SecretBox.fromConcatenation(
        await file.readAsBytes(),
        nonceLength: _algorithm.nonceLength,
        macLength: _algorithm.macAlgorithm.macLength,
      );
      final clear = await _algorithm.decrypt(
        box,
        secretKey: await _key(create: false),
      );
      final json = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
      if (json['v'] != _version || json['regionId'] != regionId) {
        await _delete();
        return null;
      }
      return CachedPeople(
        [
          for (final p in json['people'] as List)
            FastingPerson.fromJson(p as Map<String, dynamic>),
        ],
        DateTime.parse(json['syncedAt'] as String).toLocal(),
      );
    } on Object {
      // Undecryptable (key lost in a restore), corrupt, or no storage.
      await _delete();
      return null;
    }
  }

  @override
  Future<void> write({
    required int regionId,
    required List<FastingPerson> people,
    required DateTime syncedAt,
  }) => _enqueue(() async {
    if (_closed) return;
    try {
      final clear = utf8.encode(
        jsonEncode({
          'v': _version,
          'regionId': regionId,
          'syncedAt': syncedAt.toUtc().toIso8601String(),
          'people': [for (final p in people) p.toJson()],
        }),
      );
      final box = await _algorithm.encrypt(
        clear,
        secretKey: await _key(create: true),
      );
      final file = await _file();
      // Write then rename, so a crash never leaves half a file.
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsBytes(box.concatenation(), flush: true);
      await tmp.rename(file.path);
    } on Object {
      // Best effort: the list on screen is unaffected.
    }
  });

  @override
  void open() => _closed = false;

  @override
  Future<void> clear() {
    _closed = true;
    return _enqueue(_wipe);
  }

  Future<void> _wipe() async {
    await _delete();
    try {
      final file = await _file();
      final tmp = File('${file.path}.tmp');
      if (await tmp.exists()) await tmp.delete();
    } on Object {
      // No stray temp file, or no storage.
    }
    try {
      await _keys.write(keyName, null);
    } on Object {
      // The file is gone; a stray key decrypts nothing.
    }
  }

  Future<void> _delete() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } on Object {
      // Nothing to delete, or no storage.
    }
  }
}

/// In memory, for tests and previews.
class MemoryPeopleCache implements PeopleCache {
  MemoryPeopleCache([this.saved, this.regionId]);

  CachedPeople? saved;
  int? regionId;
  int writes = 0;
  int clears = 0;
  bool closed = false;

  @override
  Future<CachedPeople?> read({required int regionId}) async =>
      regionId == this.regionId ? saved : null;

  @override
  Future<void> write({
    required int regionId,
    required List<FastingPerson> people,
    required DateTime syncedAt,
  }) async {
    if (closed) return;
    this.regionId = regionId;
    saved = CachedPeople(List.of(people), syncedAt);
    writes++;
  }

  @override
  void open() => closed = false;

  @override
  Future<void> clear() async {
    closed = true;
    saved = null;
    regionId = null;
    clears++;
  }
}

final peopleCacheProvider = Provider<PeopleCache>(
  (ref) => EncryptedFilePeopleCache(
    directory: getApplicationDocumentsDirectory,
    keys: ref.watch(settingsStorageProvider),
  ),
);
