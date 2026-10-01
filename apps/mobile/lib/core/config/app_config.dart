/// Build-time configuration, injected with
/// `--dart-define-from-file=config/<env>.json` (see `config/`).
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.environment,
    this.ramadanStart,
  });

  factory AppConfig.fromEnvironment() {
    const ramadan = String.fromEnvironment('RAMADAN_START');
    return AppConfig(
      apiBaseUrl: const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'https://vps-ca2a6790.vps.ovh.net/api/v1',
      ),
      environment: const String.fromEnvironment(
        'APP_ENV',
        defaultValue: 'production',
      ),
      ramadanStart: ramadan.isEmpty ? null : DateTime.tryParse(ramadan),
    );
  }

  /// Base URL including the `/api/v1` prefix, without a trailing slash.
  final String apiBaseUrl;

  /// `development` or `production`.
  final String environment;

  /// Official first day of this season's Ramadan (release checklist).
  final DateTime? ramadanStart;

  bool get isProduction => environment == 'production';
}
