import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

import { ConfigService } from '@nestjs/config';

import { AppReleaseService } from './app-release.service';
import { renderDownloadPage } from './download-page';

const SHA = 'a'.repeat(64);

describe('AppReleaseService', () => {
  let dir: string;
  let service: AppReleaseService;

  beforeEach(async () => {
    dir = await mkdtemp(join(tmpdir(), 'releases-'));
    service = new AppReleaseService({
      get: () => dir,
    } as unknown as ConfigService);
  });

  afterEach(() => rm(dir, { recursive: true, force: true }));

  const latest = (json: object) =>
    writeFile(join(dir, 'latest.json'), JSON.stringify(json));
  const minimum = (text: string) =>
    writeFile(join(dir, 'minimum-version'), text);

  it('reports nulls before the first release', async () => {
    expect(await service.getVersionInfo()).toEqual({
      latestVersion: null,
      minimumVersion: null,
      downloadUrl: '/releases/latest.apk',
      downloadPageUrl: '/download',
      sha256: null,
      releasedAt: null,
    });
  });

  it('reads latest.json and minimum-version', async () => {
    await latest({
      version: '1.5.0',
      sha256: SHA,
      releasedAt: '2027-02-10T12:00:00Z',
    });
    await minimum('1.4.0\n');
    expect(await service.getVersionInfo()).toMatchObject({
      latestVersion: '1.5.0',
      minimumVersion: '1.4.0',
      sha256: SHA,
      releasedAt: '2027-02-10T12:00:00Z',
    });
  });

  it('caps a minimum above the latest release (1.10.0 > 1.9.0)', async () => {
    await latest({ version: '1.9.0', sha256: SHA });
    await minimum('1.10.0');
    expect((await service.getVersionInfo()).minimumVersion).toBe('1.9.0');
  });

  it('ignores malformed files instead of failing', async () => {
    await writeFile(join(dir, 'latest.json'), '{not json');
    await minimum('soon');
    expect(await service.getVersionInfo()).toMatchObject({
      latestVersion: null,
      minimumVersion: null,
    });
  });

  it('drops a checksum that is not a SHA-256', async () => {
    await latest({ version: '1.5.0', sha256: 'abc' });
    expect((await service.getVersionInfo()).sha256).toBeNull();
  });

  it('picks up a changed minimum without a restart', async () => {
    await latest({ version: '1.5.0', sha256: SHA });
    await minimum('1.4.0');
    expect((await service.getVersionInfo()).minimumVersion).toBe('1.4.0');
    await minimum('1.5.0');
    expect((await service.getVersionInfo()).minimumVersion).toBe('1.5.0');
  });
});

describe('renderDownloadPage', () => {
  const base = {
    minimumVersion: null,
    downloadUrl: '/releases/latest.apk',
    downloadPageUrl: '/download',
    releasedAt: null,
  };

  it('links the stable latest.apk and shows the version', () => {
    const html = renderDownloadPage({
      ...base,
      latestVersion: '1.5.0',
      sha256: SHA,
    });
    expect(html).toContain('href="/releases/latest.apk"');
    expect(html).toContain('Version 1.5.0');
    expect(html).toContain('Installation note');
    expect(html).toContain(SHA);
  });

  it('says so when nothing is published yet', () => {
    const html = renderDownloadPage({
      ...base,
      latestVersion: null,
      sha256: null,
    });
    expect(html).not.toContain('latest.apk');
    expect(html).toContain('No version has been published yet');
  });
});
