import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/features/update/domain/app_version_info.dart';
import 'package:iftar_mobile/features/update/domain/semver.dart';

SemVer v(String s) => SemVer.tryParse(s)!;

void main() {
  group('SemVer', () {
    test('compares numerically, not as text', () {
      expect(v('1.9.0') < v('1.10.0'), isTrue);
      expect(v('1.10.0') > v('1.9.0'), isTrue);
      expect(v('2.0.0') > v('1.99.99'), isTrue);
      expect(v('1.0.10') > v('1.0.9'), isTrue);
    });

    test('equal versions, with or without v prefix and build suffix', () {
      expect(v('1.5.0'), v('v1.5.0'));
      expect(v('1.5.0+12'), v('1.5.0'));
      expect(v('1.5.0').compareTo(v('1.5.0+3')), 0);
    });

    test('a pre-release sorts before its release', () {
      expect(v('1.5.0-beta') < v('1.5.0'), isTrue);
      expect(v('1.5.0-beta') > v('1.4.9'), isTrue);
    });

    test('rejects malformed input', () {
      for (final bad in ['', '1', '1.2', '1.2.x', 'latest', '1.2.3.4', ' . . ']) {
        expect(SemVer.tryParse(bad), isNull, reason: bad);
      }
      expect(SemVer.tryParse(null), isNull);
    });

    test('toString drops the v and the build number', () {
      expect(v('v1.5.0+7').toString(), '1.5.0');
    });
  });

  group('decideUpdate', () {
    UpdateStatus decide(String installed, {String? latest, String? minimum}) =>
        decideUpdate(
          installedVersion: installed,
          info: AppVersionInfo(latestVersion: latest, minimumVersion: minimum),
        );

    test('optional when newer exists and installed meets the minimum', () {
      expect(decide('1.4.0', latest: '1.5.0', minimum: '1.4.0'), UpdateStatus.optional);
    });

    test('required when installed is below the minimum', () {
      expect(decide('1.3.0', latest: '1.5.0', minimum: '1.4.0'), UpdateStatus.required);
    });

    test('up to date on the latest version', () {
      expect(decide('1.5.0', latest: '1.5.0', minimum: '1.4.0'), UpdateStatus.upToDate);
    });

    test('a build newer than the server (dev build) is up to date', () {
      expect(decide('1.6.0', latest: '1.5.0', minimum: '1.4.0'), UpdateStatus.upToDate);
    });

    test('1.9.0 installed, 1.10.0 published: optional', () {
      expect(decide('1.9.0', latest: '1.10.0'), UpdateStatus.optional);
    });

    test('no release published yet: up to date', () {
      expect(decide('1.0.0'), UpdateStatus.upToDate);
    });

    test('garbage from the server never blocks', () {
      expect(decide('1.0.0', latest: 'soon', minimum: 'x'), UpdateStatus.upToDate);
    });

    test('an unreadable installed version never blocks', () {
      expect(decide('unknown', latest: '2.0.0', minimum: '2.0.0'), UpdateStatus.upToDate);
    });

    test('a required minimum wins even without a latest version', () {
      expect(decide('1.0.0', minimum: '1.2.0'), UpdateStatus.required);
    });
  });

  test('AppVersionInfo.fromJson fills defaults for missing paths', () {
    final info = AppVersionInfo.fromJson({'latestVersion': '1.5.0', 'minimumVersion': null});
    expect(info.latestVersion, '1.5.0');
    expect(info.minimumVersion, isNull);
    expect(info.downloadUrl, '/releases/latest.apk');
    expect(info.downloadPageUrl, '/download');
  });
}
