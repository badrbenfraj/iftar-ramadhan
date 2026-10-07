/// A `major.minor.patch` version, compared number by number, so that
/// 1.9.0 < 1.10.0 (a string comparison gets this wrong).
///
/// A build suffix (`+7`) is ignored. A pre-release suffix (`-beta`) sorts
/// before the plain release, as in semver; pre-releases compare as text.
class SemVer implements Comparable<SemVer> {
  const SemVer(this.major, this.minor, this.patch, [this.preRelease = '']);

  final int major;
  final int minor;
  final int patch;
  final String preRelease;

  static final _pattern = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$');

  /// Parses `1.5.0`, `v1.5.0`, `1.5.0+12` or `1.5.0-beta`; null otherwise.
  static SemVer? tryParse(String? input) {
    final m = _pattern.firstMatch(input?.trim() ?? '');
    if (m == null) return null;
    return SemVer(
      int.parse(m[1]!),
      int.parse(m[2]!),
      int.parse(m[3]!),
      m[4] ?? '',
    );
  }

  @override
  int compareTo(SemVer other) {
    for (final (a, b) in [(major, other.major), (minor, other.minor), (patch, other.patch)]) {
      if (a != b) return a.compareTo(b);
    }
    if (preRelease == other.preRelease) return 0;
    if (preRelease.isEmpty) return 1;
    if (other.preRelease.isEmpty) return -1;
    return preRelease.compareTo(other.preRelease);
  }

  bool operator <(SemVer other) => compareTo(other) < 0;
  bool operator >(SemVer other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) => other is SemVer && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, preRelease);

  @override
  String toString() => preRelease.isEmpty ? '$major.$minor.$patch' : '$major.$minor.$patch-$preRelease';
}
