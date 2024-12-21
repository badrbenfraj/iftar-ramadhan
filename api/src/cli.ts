import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';

import { AppModule } from './app.module';
import { ROLE } from './auth/constants/role.constant';
import { CreateRegionInput } from './region/dtos/region-input.dto';
import { RegionRepository } from './region/repositories/region.repository';
import { RegionService } from './region/services/region.service';
import { RequestContext } from './shared/request-context/request-context.dto';
import { CreateUserInput } from './user/dtos/user-create-input.dto';
import { UserService } from './user/services/user.service';

async function bootstrap() {
  const app = await NestFactory.createApplicationContext(AppModule);

  const configService = app.get(ConfigService);
  const defaultAdminUserPassword = configService.get<string>(
    'defaultAdminUserPassword',
  );

  const userService = app.get(UserService);
  const regionService = app.get(RegionService);
  const regionRepository = app.get(RegionRepository);
  const ctx = new RequestContext();

  const regionDefault: CreateRegionInput = {
    name: 'Dar Sokra',
    active: true,
  };
  const region = await regionRepository.findOne({
    where: { name: regionDefault.name },
  });
  let createdRegion = null;
  if (!region) {
    createdRegion = await regionService.createRegion(ctx, regionDefault);
  }

  const defaultAdmin: CreateUserInput = {
    name: 'Admin User',
    username: 'admin',
    password: defaultAdminUserPassword,
    roles: [ROLE.ADMIN],
    region: createdRegion,
    isAccountDisabled: false,
    email: 'default-admin@example.com',
  };

  // Create the default admin user if it doesn't already exist.
  const user = await userService.findByUsername(ctx, defaultAdmin.username);
  if (!user) {
    await userService.createUser(ctx, defaultAdmin);
  }

  await app.close();
}
bootstrap();
