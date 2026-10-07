import { Module } from '@nestjs/common';

import { SharedModule } from '../shared/shared.module';
import { AppReleaseController } from './app-release.controller';
import { AppReleaseService } from './app-release.service';
import { DownloadController } from './download.controller';

@Module({
  imports: [SharedModule],
  controllers: [AppReleaseController, DownloadController],
  providers: [AppReleaseService],
})
export class AppReleaseModule {}
