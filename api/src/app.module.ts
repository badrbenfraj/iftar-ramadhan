import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
// import { ThrottlerModule, ThrottlerModuleOptions } from '@nestjs/throttler';
import { LoggerModule } from 'nestjs-pino';

import { AppController } from './app.controller';
import { AppService } from './app.service';
import { AuthModule } from './auth/auth.module';
import { FastingModule } from './fasting/fasting.module';
import { HealthModule } from './health/health.module';
import { SharedModule } from './shared/shared.module';
import { UserModule } from './user/user.module';

@Module({
  imports: [
    SharedModule,
    UserModule,
    AuthModule,
    FastingModule,
    HealthModule,
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
    // ThrottlerModule.forRootAsync({
    //   imports: [ConfigModule],
    //   inject: [ConfigService],
    //   useFactory: (config: ConfigService): ThrottlerModuleOptions => ({
    //     ttl: config.get<number>('RATE_LIMIT_DURATION', 60),
    //     limit: config.get<number>('RATE_LIMIT_POINTS', 10),
    //   }),
    // }),
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
