import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'byte_store.dart';

ByteStore createAppByteStore() => IndexedDbByteStore();

/// One IndexedDB record per name. Each operation is a single transaction,
/// so a write or rename lands whole or not at all.
class IndexedDbByteStore implements ByteStore {
  static const _database = 'iftar';
  static const _store = 'files';

  Future<web.IDBDatabase>? _db;

  Future<web.IDBDatabase> _open() => _db ??= () {
    final request = web.window.indexedDB.open(_database, 1);
    request.onupgradeneeded = ((web.Event _) {
      (request.result! as web.IDBDatabase).createObjectStore(_store);
    }).toJS;
    return _result(request).then((db) => db! as web.IDBDatabase).catchError((
      Object e,
    ) {
      _db = null; // Try again on the next call.
      throw e;
    });
  }();

  static Future<JSAny?> _result(web.IDBRequest request) {
    final done = Completer<JSAny?>();
    request.onsuccess = ((web.Event _) => done.complete(request.result)).toJS;
    request.onerror = ((web.Event _) => done.completeError(
      StateError('IndexedDB: ${request.error?.message}'),
    )).toJS;
    return done.future;
  }

  Future<web.IDBObjectStore> _reading() async =>
      (await _open()).transaction(_store.toJS, 'readonly').objectStore(_store);

  /// Runs [body] in one read-write transaction; completes once it committed.
  Future<void> _writing(void Function(web.IDBObjectStore store) body) async {
    final tx = (await _open()).transaction(_store.toJS, 'readwrite');
    final done = Completer<void>();
    void fail(web.Event _) {
      if (!done.isCompleted) {
        done.completeError(StateError('IndexedDB: ${tx.error?.message}'));
      }
    }

    tx.oncomplete = ((web.Event _) {
      if (!done.isCompleted) done.complete();
    }).toJS;
    tx.onerror = fail.toJS;
    tx.onabort = fail.toJS;
    body(tx.objectStore(_store));
    return done.future;
  }

  @override
  Future<Uint8List?> read(String name) async {
    final value = await _result((await _reading()).get(name.toJS));
    if (value.isUndefinedOrNull) return null;
    return (value! as JSUint8Array).toDart;
  }

  @override
  Future<void> write(String name, List<int> bytes) =>
      _writing((store) => store.put(Uint8List.fromList(bytes).toJS, name.toJS));

  @override
  Future<void> rename(String from, String to) => _writing((store) {
    final get = store.get(from.toJS);
    get.onsuccess = ((web.Event _) {
      final value = get.result;
      if (value.isUndefinedOrNull) return;
      store.put(value, to.toJS);
      store.delete(from.toJS);
    }).toJS;
  });

  @override
  Future<void> delete(String name) =>
      _writing((store) => store.delete(name.toJS));

  @override
  Future<List<String>> names() async {
    final keys = await _result((await _reading()).getAllKeys());
    return [
      for (final key in (keys! as JSArray<JSAny?>).toDart)
        if (key.isA<JSString>()) (key! as JSString).toDart,
    ];
  }
}
