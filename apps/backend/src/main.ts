import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import compression from 'compression';
import helmet from 'helmet';
import { Logger } from 'nestjs-pino';

import { AppModule } from './app.module';
import { VALIDATION_PIPE_OPTIONS } from './shared/constants';
import { RequestIdMiddleware } from './shared/middlewares/request-id/request-id.middleware';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    bufferLogs: true,
  });
  // Caddy is the one proxy in front: trust its X-Forwarded-For so rate
  // limits count phones, not Caddy.
  app.set('trust proxy', 1);

  // Use Pino Logger
  app.useLogger(app.get(Logger));

  // Security middlewares
  app.use(helmet());
  app.use(compression());

  // /download is the human page volunteers open; everything else is the API.
  app.setGlobalPrefix('api/v1', { exclude: ['download'] });

  app.useGlobalPipes(new ValidationPipe(VALIDATION_PIPE_OPTIONS));
  app.use(RequestIdMiddleware);

  const configService = app.get(ConfigService);
  const port = configService.get<number>('port');
  await app.listen(port);
}

bootstrap();
