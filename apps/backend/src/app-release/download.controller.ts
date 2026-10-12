import { createReadStream } from 'node:fs';
import { join } from 'node:path';

import { Controller, Get, Header, StreamableFile } from '@nestjs/common';
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

  /** The printable cards: the same numbers serve every region. */
  @Get('cards.pdf')
  @Header('Content-Type', 'application/pdf')
  @Header('Content-Disposition', 'inline; filename="iftar-cards-1-2000.pdf"')
  @Header('Cache-Control', 'public, max-age=86400')
  cards(): StreamableFile {
    return new StreamableFile(
      createReadStream(
        join(process.cwd(), 'assets/cards/iftar-cards-1-2000.pdf'),
      ),
    );
  }
}
