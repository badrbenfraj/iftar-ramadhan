import 'semver.dart';

/// What the backend says about releases (`GET /app/version`).
class AppVersionInfo {
  const AppVersionInfo({
    this.latestVersion,
    this.minimumVersion,
    this.downloadUrl = '/releases/latest.apk',
    this.downloadPageUrl = '/download',
    this.sha256,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) => AppVersionInfo(
    latestVersion: json['latestVersion'] as String?,
    minimumVersion: json['minimumVersion'] as String?,
    downloadUrl: json['downloadUrl'] as String? ?? '/releases/latest.apk',
    downloadPageUrl: json['downloadPageUrl'] as String? ?? '/download',
    sha256: json['sha256'] as String?,
  );

  /// Null until the first APK has been published on this server.
  final String? latestVersion;

  /// Installed versions below this one must update before use.
  final String? minimumVersion;

  /// Stable path of the newest APK, relative to the server.
  final String downloadUrl;

  /// Human download page, relative to the server.
  final String downloadPageUrl;

  final String? sha256;
}

enum UpdateStatus {
  /// Nothing to do, or the check could not be made (offline, bad data).
  upToDate,

  /// A newer version exists; the volunteer may keep working.
  optional,

  /// The installed version is below the minimum; the app is blocked.
  required,
}

/// The update rule, kept pure for unit tests.
///
/// Anything unparseable counts as "no information" rather than blocking the
/// volunteer, except an explicit minimum above the installed version.
UpdateStatus decideUpdate({
  required String installedVersion,
  required AppVersionInfo info,
}) {
  final installed = SemVer.tryParse(installedVersion);
  if (installed == null) return UpdateStatus.upToDate;
  final minimum = SemVer.tryParse(info.minimumVersion);
  if (minimum != null && installed < minimum) return UpdateStatus.required;
  final latest = SemVer.tryParse(info.latestVersion);
  if (latest != null && installed < latest) return UpdateStatus.optional;
  return UpdateStatus.upToDate;
}
