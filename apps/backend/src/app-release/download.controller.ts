import { Controller, Get, Header } from '@nestjs/common';
import { ApiExcludeController } from '@nestjs/swagger';

import { AppReleaseService } from './app-release.service';
import { renderDownloadPage } from './download-page';

/**
 * `GET /download` (outside the `/api/v1` prefix, see main.ts): the one link
 * volunteers receive at the start of Ramadan.
 */
@ApiExcludeController()
@Controller('download')
export class DownloadController {
  constructor(private readonly releases: AppReleaseService) {}

  @Get()
  @Header('Content-Type', 'text/html; charset=utf-8')
  @Header('Cache-Control', 'no-store')
  async page(): Promise<string> {
    return renderDownloadPage(await this.releases.getVersionInfo());
  }
}
