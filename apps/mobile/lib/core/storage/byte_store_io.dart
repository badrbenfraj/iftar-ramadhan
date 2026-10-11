import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'byte_store.dart';

ByteStore createAppByteStore() =>
    FileByteStore(getApplicationDocumentsDirectory);

/// One file per name in [_directory].
class FileByteStore implements ByteStore {
  FileByteStore(this._directory);

  final Future<Directory> Function() _directory;

  Future<File> _file(String name) async =>
      File('${(await _directory()).path}/$name');

  @override
  Future<Uint8List?> read(String name) async {
    final file = await _file(name);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  Future<void> write(String name, List<int> bytes) async {
    final file = await _file(name);
    // Write then rename, so a crash never leaves half a file.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(file.path);
  }

  @override
  Future<void> rename(String from, String to) async {
    await (await _file(from)).rename((await _file(to)).path);
  }

  @override
  Future<void> delete(String name) async {
    final file = await _file(name);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<List<String>> names() async {
    final found = <String>[];
    await for (final entity in (await _directory()).list()) {
      if (entity is File) found.add(entity.uri.pathSegments.last);
    }
    return found;
  }
}
