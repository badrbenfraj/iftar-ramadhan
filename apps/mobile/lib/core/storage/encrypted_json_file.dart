import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

import '../settings/settings_storage.dart';

/// One JSON document kept AES-GCM encrypted in a file, with its 256-bit key
/// in the platform keystore. Writes run one after another. Best effort: a
/// storage error never throws.
class EncryptedJsonFile {
  EncryptedJsonFile({
    required this._directory,
    required this._keys,
    required this.fileName,
    required this.keyName,
  });

  final Future<Directory> Function() _directory;
  final SettingsStorage _keys;
  final String fileName;
  final String keyName;
  final AesGcm _algorithm = AesGcm.with256bits();
  Future<void> _queue = Future.value();

  Future<void> _enqueue(Future<void> Function() op) {
    final next = _queue.then((_) => op());
    _queue = next.catchError((_) {});
    return next;
  }

  Future<File> _file() async => File('${(await _directory()).path}/$fileName');

  Future<SecretKey> _key({required bool create}) async {
    final stored = await _keys.read(keyName);
    if (stored != null) return SecretKey(base64Decode(stored));
    if (!create) throw StateError('No key for $fileName');
    final key = await _algorithm.newSecretKey();
    await _keys.write(keyName, base64Encode(await key.extractBytes()));
    return key;
  }

  Future<Object?> _decode(File file) async {
    final box = SecretBox.fromConcatenation(
      await file.readAsBytes(),
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
    File? file;
    try {
      file = await _file();
      if (!await file.exists()) return null;
      return await _decode(file);
    } on Object {
      try {
        await file?.rename(
          '${file.path}.unreadable-${DateTime.now().millisecondsSinceEpoch}',
        );
      } on Object {
        // Nothing more to do.
      }
      return null;
    }
  }

  /// The set-aside files that can be read now, with their documents. The
  /// files stay where they are; the caller deletes them once it has kept
  /// their content. Never throws.
  Future<List<(File, Object?)>> readSetAside() async {
    final found = <(File, Object?)>[];
    try {
      final dir = await _directory();
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (!name.startsWith('$fileName.unreadable')) continue;
        try {
          found.add((entity, await _decode(entity)));
        } on Object {
          // Still unreadable: leave it.
        }
      }
    } on Object {
      // Best effort.
    }
    return found;
  }

  Future<void> write(Object json) => _enqueue(() async {
    try {
      final box = await _algorithm.encrypt(
        utf8.encode(jsonEncode(json)),
        secretKey: await _key(create: true),
      );
      final file = await _file();
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsBytes(box.concatenation(), flush: true);
      await tmp.rename(file.path);
    } on Object {
      // Best effort: the in-memory state is unaffected.
    }
  });
}
