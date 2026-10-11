import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../settings/settings_storage.dart';
import 'byte_store.dart';

/// One JSON document kept AES-GCM encrypted in a [ByteStore] entry (a file
/// on Android), with its 256-bit key in the platform keystore. Writes run one after another. Best effort: a
/// storage error never throws.
class EncryptedJsonFile {
  EncryptedJsonFile({
    required this._store,
    required this._keys,
    required this.fileName,
    required this.keyName,
  });

  final ByteStore _store;
  final SettingsStorage _keys;
  final String fileName;
  final String keyName;
  final AesGcm _algorithm = AesGcm.with256bits();
  Future<void> _queue = Future.value();

  Future<bool> _enqueue(Future<bool> Function() op) {
    final next = _queue.then((_) => op());
    _queue = next.then<void>((_) {}).catchError((_) {});
    return next;
  }

  Future<SecretKey> _key({required bool create}) async {
    final stored = await _keys.read(keyName);
    if (stored != null) return SecretKey(base64Decode(stored));
    if (!create) throw StateError('No key for $fileName');
    final key = await _algorithm.newSecretKey();
    await _keys.write(keyName, base64Encode(await key.extractBytes()));
    return key;
  }

  Future<Object?> _decode(Uint8List bytes) async {
    final box = SecretBox.fromConcatenation(
      bytes,
      nonceLength: _algorithm.nonceLength,
      macLength: _algorithm.macAlgorithm.macLength,
    );
    final clear = await _algorithm.decrypt(
      box,
      secretKey: await _key(create: false),
    );
    return jsonDecode(utf8.decode(clear));
  }

  /// The saved document, or null when there is none. A file that can't be
  /// read is moved aside (`<file>.unreadable-<time>`), never deleted: it may
  /// hold meals that were really served. See [readSetAside].
  Future<Object?> read() async {
    try {
      final bytes = await _store.read(fileName);
      if (bytes == null) return null;
      return await _decode(bytes);
    } on Object {
      try {
        final base =
            '$fileName.unreadable-${DateTime.now().millisecondsSinceEpoch}';
        // Never overwrite an earlier set-aside file from the same millisecond.
        final taken = (await _store.names()).toSet();
        var target = base;
        for (var i = 1; taken.contains(target); i++) {
          target = '$base-$i';
        }
        await _store.rename(fileName, target);
      } on Object {
        // Nothing more to do.
      }
      return null;
    }
  }

  /// The set-aside files that can be read now, by name, with their
  /// documents. The files stay where they are; the caller deletes them (see
  /// [deleteSetAside]) once it has kept their content. Never throws.
  Future<List<(String, Object?)>> readSetAside() async {
    final found = <(String, Object?)>[];
    try {
      for (final name in await _store.names()) {
        if (!name.startsWith('$fileName.unreadable')) continue;
        try {
          final bytes = await _store.read(name);
          if (bytes != null) found.add((name, await _decode(bytes)));
        } on Object {
          // Still unreadable: leave it.
        }
      }
    } on Object {
      // Best effort.
    }
    return found;
  }

  /// True when the encrypted file was written and renamed into place; false
  /// on any error. Never throws.
  Future<bool> write(Object json) => _enqueue(() async {
    try {
      final box = await _algorithm.encrypt(
        utf8.encode(jsonEncode(json)),
        secretKey: await _key(create: true),
      );
      await _store.write(fileName, box.concatenation());
      return true;
    } on Object {
      // Best effort: the in-memory state is unaffected.
      return false;
    }
  });

  /// Deletes a set-aside file returned by [readSetAside].
  Future<void> deleteSetAside(String name) => _store.delete(name);
}
