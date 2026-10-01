import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Small key-value store for preferences. Separate keys from the session,
/// so logging out keeps the volunteer's language.
abstract interface class SettingsStorage {
  Future<String?> read(String key);

  /// A null [value] deletes the key.
  Future<void> write(String key, String? value);
}

class SecureSettingsStorage implements SettingsStorage {
  SecureSettingsStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String? value) => value == null
      ? _storage.delete(key: key)
      : _storage.write(key: key, value: value);
}

class MemorySettingsStorage implements SettingsStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}
