/// Build-time configuration, injected with `--dart-define` /
/// `--dart-define-from-file=config/<env>.json` (see `config/`).
///
/// No server address is hard-coded: production builds get `API_URL` from the
/// GitHub repository variable of the same name (see docs/DEPLOYMENT.md).
class AppConfig {
  const AppConfig({
    required this.apiUrl,
    required this.environment,
    this.ramadanStart,
  });

  factory AppConfig.fromEnvironment() {
    const ramadan = String.fromEnvironment('RAMADAN_START');
    return AppConfig(
      apiUrl: const String.fromEnvironment(
        'API_URL',
        defaultValue: 'http://localhost:3000',
      ),
      environment: const String.fromEnvironment(
        'APP_ENV',
        defaultValue: 'production',
      ),
      ramadanStart: ramadan.isEmpty ? null : DateTime.tryParse(ramadan),
    );
  }

  /// Server origin, e.g. `https://vps-xxxx.vps.ovh.net` (no `/api/v1`).
  final String apiUrl;

  /// `development` or `production`.
  final String environment;

  /// Official first day of this season's Ramadan (release checklist).
  final DateTime? ramadanStart;

  /// REST base URL, without a trailing slash.
  String get apiBaseUrl =>
      '${apiUrl.replaceFirst(RegExp(r'/+$'), '')}/api/v1';

  bool get isProduction => environment == 'production';
}
