import { Logger } from '@nestjs/common';
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
  const logger = new Logger('CLI');
  try {
    const app = await NestFactory.createApplicationContext(AppModule);

    const configService = app.get(ConfigService);
    const defaultAdminUserPassword = configService.get<string>('defaultAdminUserPassword');
    console.log('defaultAdminUserPassword:', defaultAdminUserPassword)
    if (!defaultAdminUserPassword) {
      throw new Error('Default admin password not configured');
    }

    const userService = app.get(UserService);
    const regionService = app.get(RegionService);
    const regionRepository = app.get(RegionRepository);

    // Create admin context
    const ctx = new RequestContext();
    // Set admin context for initial setup
    ctx.user = {
      id: 0,
      roles: [ROLE.ADMIN],
      username: 'system',
    };

    // Create initial admin user without region
    logger.log('Creating initial admin user...');
    const initialAdmin: CreateUserInput = {
      name: 'Admin User',
      username: 'admin',
      password: defaultAdminUserPassword,
      roles: [ROLE.ADMIN],
      isAccountDisabled: false,
      email: 'default-admin@example.com',
    };

    let adminUser = await userService.findByUsername(ctx, initialAdmin.username);
    if (!adminUser) {
      adminUser = await userService.createUser(ctx, initialAdmin);
      logger.log(`Initial admin user created with ID: ${adminUser.id}`);
    }

    // Update context with real admin user
    ctx.user = {
      id: adminUser.id,
      roles: adminUser.roles,
      username: adminUser.username,
    };

    // Now create region with proper admin user as creator
    logger.log('Setting up default region...');
    const regionDefault: CreateRegionInput = {
      name: 'Dar Sokra',
      active: true,
    };

    let region = await regionRepository.findOne({
      where: { name: regionDefault.name },
      relations: ['createdBy'], // Add this line to load the relation
    });

    if (!region) {
      const createdRegion = await regionService.createRegion(ctx, regionDefault);
      region = await regionRepository.findOne({
        where: { id: createdRegion.id },
        relations: ['createdBy'],
      });
      logger.log(`Default region created with ID: ${region.id}`);
    }

    // Finally, update admin user with region
    if (adminUser && region) {
      await userService.updateUser(ctx, adminUser.id, {
        ...adminUser,
        region: region,
      });
      logger.log('Admin user updated with region assignment');
    }

    await app.close();
    logger.log('CLI setup completed successfully');
  } catch (error) {
    logger.error('Failed to run CLI setup:', error?.message || error);
    process.exit(1);
  }
}

bootstrap();
