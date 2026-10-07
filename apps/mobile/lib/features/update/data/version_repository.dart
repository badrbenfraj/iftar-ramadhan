import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../domain/app_version_info.dart';

abstract interface class VersionRepository {
  Future<AppVersionInfo> fetch();
}

class ApiVersionRepository implements VersionRepository {
  ApiVersionRepository(this._api);

  final ApiClient _api;

  @override
  Future<AppVersionInfo> fetch() async =>
      AppVersionInfo.fromJson((await _api.get('/app/version')).object);
}

final versionRepositoryProvider = Provider<VersionRepository>(
  (ref) => ApiVersionRepository(ref.watch(apiClientProvider)),
);

/// The installed app's `versionName` (e.g. `1.5.0`), from the APK itself.
final installedVersionProvider = FutureProvider<String>(
  (_) async => (await PackageInfo.fromPlatform()).version,
);

/// Opens a URL in the phone's browser. Tests override it.
final urlOpenerProvider = Provider<Future<bool> Function(Uri)>(
  (_) => (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);
