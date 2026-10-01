import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  SettingsStorage get _storage => ref.read(settingsStorageProvider);

  @override
  Future<AppSettings> build() async {
    final code = await _storage.read(localeKey);
    final mode = await _storage.read(themeModeKey);
    return AppSettings(
      locale: code == null ? null : Locale(code),
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == mode,
        orElse: () => ThemeMode.system,
      ),
    );
  }

  AppSettings get _current => state.value ?? const AppSettings();

  Future<void> setLocale(Locale? locale) async {
    state = AsyncData(_current.copyWith(locale: () => locale));
    await _storage.write(localeKey, locale?.languageCode);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = AsyncData(_current.copyWith(themeMode: mode));
    await _storage.write(themeModeKey, mode.name);
  }
}

final settingsStorageProvider = Provider<SettingsStorage>(
  (_) => SecureSettingsStorage(),
);

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
      SettingsController.new,
    );
