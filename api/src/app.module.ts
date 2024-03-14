import { Module } from '@nestjs/common';

import { AppController } from './app.controller';
import { AppService } from './app.service';
import { AuthModule } from './auth/auth.module';
import { SharedModule } from './shared/shared.module';
import { UserModule } from './user/user.module';
import { FastingModule } from './fasting/fasting.module';

@Module({
  imports: [
    SharedModule, 
    UserModule, 
    AuthModule, 
    FastingModule
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
