import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import * as path from 'path';

import { AppModule } from './app.module';
import { VALIDATION_PIPE_OPTIONS } from './shared/constants';
import { RequestIdMiddleware } from './shared/middlewares/request-id/request-id.middleware';

async function bootstrap() {
  try {
    // Load SSL/TLS certificates
    const key = path.resolve('privkey.pem');
    const cert = path.resolve('fullchain.pem');

    // Create HTTPS server
    const httpsOptions = {
      key,
      cert,
    };
    const app = await NestFactory.create(AppModule, {
      httpsOptions,
    });
    app.setGlobalPrefix('api/v1');

    app.useGlobalPipes(new ValidationPipe(VALIDATION_PIPE_OPTIONS));
    app.use(RequestIdMiddleware);
    app.enableCors();

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
  } catch (error) {
    console.error('Failed to bootstrap application:', error);
  }
}

bootstrap();
