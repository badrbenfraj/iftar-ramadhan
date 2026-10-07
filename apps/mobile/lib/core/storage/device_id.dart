import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_controller.dart';
import '../utils/uuid.dart';

const _deviceIdKey = 'device_id';

/// This installation's ID, sent with each confirm for the audit trail
/// (spec 2A §5.1). Generated once and kept with the settings, so it survives
/// logout. Best effort: when the keystore fails, confirms go without it.
final deviceIdProvider = FutureProvider<String?>((ref) async {
  final storage = ref.read(settingsStorageProvider);
  try {
    final existing = await storage.read(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = 'inst-${newUuidV4()}';
    await storage.write(_deviceIdKey, id);
    return id;
  } on Object {
    return null;
  }
});
