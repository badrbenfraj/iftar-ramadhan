import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import compression from 'compression';
import helmet from 'helmet';
import { Logger } from 'nestjs-pino';

import { AppModule } from './app.module';
import { VALIDATION_PIPE_OPTIONS } from './shared/constants';
import { RequestIdMiddleware } from './shared/middlewares/request-id/request-id.middleware';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { bufferLogs: true });

  // Use Pino Logger
  app.useLogger(app.get(Logger));

  // Security middlewares
  app.use(helmet());
  app.use(compression());

  app.setGlobalPrefix('api/v1');

  app.useGlobalPipes(new ValidationPipe(VALIDATION_PIPE_OPTIONS));
  app.use(RequestIdMiddleware);

  // CORS configuration
  app.enableCors();

  const configService = app.get(ConfigService);
  const port = configService.get<number>('port');
  await app.listen(port);
}

bootstrap();
