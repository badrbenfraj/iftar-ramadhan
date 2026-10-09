import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { hash } from 'bcrypt';

import { AppModule } from './app.module';
import { ROLE } from './auth/constants/role.constant';
import { CreateRegionInput } from './region/dtos/region-input.dto';
import { RegionRepository } from './region/repositories/region.repository';
import { RegionService } from './region/services/region.service';
import { RequestContext } from './shared/request-context/request-context.dto';
import { USER_STATUS } from './user/constants/user-status.constant';
import { CreateUserInput } from './user/dtos/user-create-input.dto';
import { UserRepository } from './user/repositories/user.repository';
import { UserService } from './user/services/user.service';

async function bootstrap() {
  const logger = new Logger('CLI');
  try {
    const app = await NestFactory.createApplicationContext(AppModule);

    const configService = app.get(ConfigService);
    const defaultAdminUserPassword = configService.get<string>(
      'defaultAdminUserPassword',
    );
    if (!defaultAdminUserPassword) {
      throw new Error('Default admin password not configured');
    }

    // `reset-admin-password`: set the existing admin's password from
    // DEFAULT_ADMIN_USER_PASSWORD (secret rotation on a running server).
    if (process.argv.includes('reset-admin-password')) {
      const users = app.get(UserRepository);
      const admin = await users.findOne({ where: { username: 'admin' } });
      if (!admin) {
        throw new Error('No "admin" user to reset');
      }
      admin.password = await hash(defaultAdminUserPassword, 10);
      await users.save(admin);
      logger.log('Admin password reset from DEFAULT_ADMIN_USER_PASSWORD');
      await app.close();
      return;
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
      status: USER_STATUS.ACTIVE,
      email: 'default-admin@example.com',
    };

    let adminUser = await userService.findByUsername(
      ctx,
      initialAdmin.username,
    );
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

    // Now create default regions with proper admin user as creator
    logger.log('Setting up default regions...');
    const defaultRegions: CreateRegionInput[] = [
      {
        name: 'Dar Sokra',
        active: true,
      },
      {
        name: 'Dar Sousse',
        active: true,
      },
    ];

    for (const defaultRegion of defaultRegions) {
      let existingRegion = await regionRepository.findOne({
        where: { name: defaultRegion.name },
        relations: { createdBy: true },
      });

      if (!existingRegion) {
        const createdRegion = await regionService.createRegion(
          ctx,
          defaultRegion,
        );
        existingRegion = await regionRepository.findOne({
          where: { id: createdRegion.id },
          relations: { createdBy: true },
        });
        logger.log(
          `Default region ${defaultRegion.name} created with ID: ${existingRegion.id}`,
        );
      }
    }

    const region = await regionRepository.findOne({
      where: { name: 'Dar Sokra' },
      relations: { createdBy: true },
    });

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
