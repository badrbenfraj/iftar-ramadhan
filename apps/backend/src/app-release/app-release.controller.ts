import { Controller, Get, Header, HttpStatus } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';

import {
  BaseApiResponse,
  SwaggerBaseApiResponse,
} from '../shared/dtos/base-api-response.dto';
import { AppReleaseService } from './app-release.service';
import { AppVersionOutput } from './app-version-output.dto';

/** Public: the app checks it at startup, before anyone signs in. */
@ApiTags('app')
@Controller('app')
export class AppReleaseController {
  constructor(private readonly releases: AppReleaseService) {}

  @Get('version')
  @Header('Cache-Control', 'no-store')
  @ApiOperation({ summary: 'Latest and minimum supported app versions' })
  @ApiResponse({
    status: HttpStatus.OK,
    type: SwaggerBaseApiResponse(AppVersionOutput),
  })
  async getVersion(): Promise<BaseApiResponse<AppVersionOutput>> {
    return { data: await this.releases.getVersionInfo(), meta: {} };
  }
}
