import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/app_failure.dart';
import 'settings_storage.dart';

class AppSettings {
  const AppSettings({this.locale, this.themeMode = ThemeMode.system});

  /// Null = follow the device (Arabic if unsupported).
  final Locale? locale;
  final ThemeMode themeMode;

  AppSettings copyWith({Locale? Function()? locale, ThemeMode? themeMode}) =>
      AppSettings(
        locale: locale == null ? this.locale : locale(),
        themeMode: themeMode ?? this.themeMode,
      );
}

class SettingsController extends AsyncNotifier<AppSettings> {
  static const localeKey = 'settings.locale';
  static const themeModeKey = 'settings.themeMode';

  @override
  Future<AppSettings> build() async {
    // Read the provider before the first await; a dependency read after an
    // await can see a disposed ref.
    final storage = ref.read(settingsStorageProvider);
    final code = await storage.read(localeKey);
    final mode = await storage.read(themeModeKey);
    return AppSettings(
      locale: code == null ? null : Locale(code),
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == mode,
        orElse: () => ThemeMode.system,
      ),
    );
  }

  /// Waits for the stored settings, so a choice made while they are still
  /// loading is not overwritten by the late load. A failed load falls back to
  /// the defaults.
  Future<AppSettings> _loaded() async {
    try {
      return await future;
    } catch (_) {
      return const AppSettings();
    }
  }

  /// Applies [locale] now; null returns to the device language. The choice
  /// stays in effect for this run even if it cannot be saved, in which case
  /// the failure is returned (never thrown) for the caller to report.
  Future<AppFailure?> setLocale(Locale? locale) async {
    final storage = ref.read(settingsStorageProvider);
    final loaded = await _loaded();
    if (!ref.mounted) return null;
    // Newer than [loaded] when another choice landed while this one waited.
    final current = state.value ?? loaded;
    state = AsyncData(current.copyWith(locale: () => locale));
    return _persist(storage, localeKey, locale?.languageCode);
  }

  /// Like [setLocale], for the appearance.
  Future<AppFailure?> setThemeMode(ThemeMode mode) async {
    final storage = ref.read(settingsStorageProvider);
    final loaded = await _loaded();
    if (!ref.mounted) return null;
    // Newer than [loaded] when another choice landed while this one waited.
    final current = state.value ?? loaded;
    state = AsyncData(current.copyWith(themeMode: mode));
    return _persist(storage, themeModeKey, mode.name);
  }

  Future<AppFailure?> _persist(
    SettingsStorage storage,
    String key,
    String? value,
  ) async {
    try {
      await storage.write(key, value);
      return null;
    } catch (_) {
      return const UnknownFailure();
    }
  }
}

final settingsStorageProvider = Provider<SettingsStorage>(
  (_) => SecureSettingsStorage(),
);

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
      SettingsController.new,
    );
