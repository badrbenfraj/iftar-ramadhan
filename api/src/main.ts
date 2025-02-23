import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { Reflector } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { ThrottlerGuard } from '@nestjs/throttler';
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

  // Add ThrottlerGuard globally
  // const throttlerGuard = new ThrottlerGuard(
  //   app.get(ConfigService),
  //   app.get('ThrottlerStorage'),
  //   app.get(Reflector),
  // );

  // app.useGlobalGuards(throttlerGuard);

  app.setGlobalPrefix('api/v1');

  app.useGlobalPipes(new ValidationPipe(VALIDATION_PIPE_OPTIONS));
  app.use(RequestIdMiddleware);

  // CORS configuration
  app.enableCors({
    origin: process.env.ALLOWED_ORIGINS?.split(',') || '*',
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS',
    credentials: true,
  });

  /** Swagger configuration*/
  const options = new DocumentBuilder()
    .setTitle('Nestjs API starter')
    .setDescription('Nestjs API description')
    .setVersion('1.0')
    .addBearerAuth()
    .build();

  const document = SwaggerModule.createDocument(app, options);
  SwaggerModule.setup('swagger', app, document);

  const configService = app.get(ConfigService);
  const port = configService.get<number>('port');
  await app.listen(port);
}

bootstrap();
