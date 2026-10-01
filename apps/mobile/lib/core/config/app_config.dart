/// Build-time configuration, injected with
/// `--dart-define-from-file=config/<env>.json` (see `config/`).
class AppConfig {
  const AppConfig({required this.apiBaseUrl, required this.environment});

  factory AppConfig.fromEnvironment() => const AppConfig(
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://vps-ca2a6790.vps.ovh.net/api/v1',
    ),
    environment: String.fromEnvironment('APP_ENV', defaultValue: 'production'),
  );

  /// Base URL including the `/api/v1` prefix, without a trailing slash.
  final String apiBaseUrl;

  /// `development` or `production`.
  final String environment;

  bool get isProduction => environment == 'production';
}
