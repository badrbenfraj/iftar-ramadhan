import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { LoggerModule } from 'nestjs-pino';

import { AppController } from './app.controller';
import { AppService } from './app.service';
import { AppReleaseModule } from './app-release/app-release.module';
import { AuthModule } from './auth/auth.module';
import { FastingModule } from './fasting/fasting.module';
import { HealthModule } from './health/health.module';
import { RegionModule } from './region/region.module';
import { SharedModule } from './shared/shared.module';
import { UserModule } from './user/user.module';

@Module({
  imports: [
    SharedModule,
    UserModule,
    AuthModule,
    FastingModule,
    HealthModule,
    RegionModule,
    AppReleaseModule,
    LoggerModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => {
        return {
          pinoHttp: {
            level:
              configService.get('NODE_ENV') === 'development'
                ? 'debug'
                : 'info',
            transport:
              configService.get('NODE_ENV') === 'development'
                ? { target: 'pino-pretty' }
                : undefined,
          },
        };
      },
    }),
    // Volunteers often share one Wi-Fi/carrier IP: a high backstop only;
    // the strict limits are on the auth routes (security spec §5.1).
    ThrottlerModule.forRoot([{ name: 'default', ttl: 60_000, limit: 600 }]),
  ],
  controllers: [AppController],
  providers: [AppService, { provide: APP_GUARD, useClass: ThrottlerGuard }],
})
export class AppModule {}
