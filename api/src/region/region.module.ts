import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { JwtAuthStrategy } from '../auth/strategies/jwt-auth.strategy';
import { SharedModule } from '../shared/shared.module';
import { UserModule } from '../user/user.module';
import { RegionController } from './controllers/region.controller';
import { Region } from './entities/region.entity';
import { RegionRepository } from './repositories/region.repository';
import { RegionService } from './services/region.service';
import { RegionAclService } from './services/region-acl.service';

@Module({
  imports: [SharedModule, TypeOrmModule.forFeature([Region]), UserModule],
  providers: [
    RegionService,
    JwtAuthStrategy,
    RegionAclService,
    RegionRepository,
  ],
  controllers: [RegionController],
  exports: [RegionService],
})
export class RegionModule {}
