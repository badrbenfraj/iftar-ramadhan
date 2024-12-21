import { Module } from '@nestjs/common';

import { AppController } from './app.controller';
import { AppService } from './app.service';
import { AuthModule } from './auth/auth.module';
import { FastingModule } from './fasting/fasting.module';
import { RegionModule } from './region/region.module';
import { SharedModule } from './shared/shared.module';
import { UserModule } from './user/user.module';

@Module({
  imports: [SharedModule, UserModule, AuthModule, FastingModule, RegionModule],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
