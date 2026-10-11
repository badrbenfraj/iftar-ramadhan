import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'byte_store_io.dart' if (dart.library.js_interop) 'byte_store_web.dart';

/// Named blobs of bytes kept on the device: files in the app's documents
/// directory on Android, IndexedDB in the browser.
abstract interface class ByteStore {
  /// The bytes saved under [name]; null when there are none.
  Future<Uint8List?> read(String name);

  /// Replaces [name] whole: a crash never leaves half of it.
  Future<void> write(String name, List<int> bytes);

  /// Moves [from] to [to], replacing [to].
  Future<void> rename(String from, String to);

  /// Does nothing when [name] doesn't exist.
  Future<void> delete(String name);

  /// Every saved name.
  Future<List<String>> names();
}

final byteStoreProvider = Provider<ByteStore>((_) => createAppByteStore());
