import 'package:iftar_mobile/core/settings/settings_storage.dart';

/// A keychain that reads fine but refuses every write, so a settings choice
/// stays in effect for the run without being saved.
class ThrowingWriteStorage extends MemorySettingsStorage {
  @override
  Future<void> write(String key, String? value) async =>
      throw StateError('keychain unavailable');
}
