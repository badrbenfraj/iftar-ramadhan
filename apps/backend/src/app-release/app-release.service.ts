import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import { AppVersionOutput } from './app-version-output.dto';
import { compareSemver, normalizeSemver } from './semver';

export const LATEST_APK_URL = '/releases/latest.apk';
export const DOWNLOAD_PAGE_URL = '/download';

/**
 * Release metadata lives as two small files in the releases directory, next
 * to the APKs (docs/DEPLOYMENT.md):
 *
 * - `latest.json`      written by the release workflow:
 *                      { "version": "1.5.0", "sha256": "...", "releasedAt": "..." }
 * - `minimum-version`  one line, e.g. `1.4.0`, changed by hand or by the
 *                      "Set minimum app version" workflow.
 *
 * Both are read on every request (a handful of volunteers), so a change takes
 * effect without restarting anything.
 */
@Injectable()
export class AppReleaseService {
  constructor(private readonly config: ConfigService) {}

  private get dir(): string {
    return this.config.get<string>('releasesDir');
  }

  async getVersionInfo(): Promise<AppVersionOutput> {
    const latest = await this.readLatest();
    let minimumVersion = normalizeSemver(
      await this.readText('minimum-version'),
    );
    // A minimum above the newest release would force an update that cannot
    // be satisfied; cap it to the newest release.
    if (
      minimumVersion &&
      latest.version &&
      compareSemver(minimumVersion, latest.version) > 0
    ) {
      minimumVersion = latest.version;
    }
    return {
      latestVersion: latest.version,
      minimumVersion,
      downloadUrl: LATEST_APK_URL,
      downloadPageUrl: DOWNLOAD_PAGE_URL,
      sha256: latest.sha256,
      releasedAt: latest.releasedAt,
    };
  }

  private async readLatest(): Promise<{
    version: string | null;
    sha256: string | null;
    releasedAt: string | null;
  }> {
    const empty = { version: null, sha256: null, releasedAt: null };
    const text = await this.readText('latest.json');
    if (!text) return empty;
    try {
      const json = JSON.parse(text);
      const version = normalizeSemver(json.version);
      if (!version) return empty;
      const sha256 =
        typeof json.sha256 === 'string' && /^[a-f0-9]{64}$/i.test(json.sha256)
          ? json.sha256.toLowerCase()
          : null;
      const releasedAt =
        typeof json.releasedAt === 'string' ? json.releasedAt : null;
      return { version, sha256, releasedAt };
    } catch {
      return empty;
    }
  }

  /** File contents, or null when it does not exist (yet). */
  private async readText(name: string): Promise<string | null> {
    try {
      return (await readFile(join(this.dir, name), 'utf8')).trim();
    } catch {
      return null;
    }
  }
}
