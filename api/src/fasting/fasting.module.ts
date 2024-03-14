import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

import { JwtAuthStrategy } from '../auth/strategies/jwt-auth.strategy';
import { SharedModule } from '../shared/shared.module';
import { UserModule } from '../user/user.module';
import { FastingController } from './controllers/fasting.controller';
import { Fasting } from './entities/fasting.entity';
import { FastingRepository } from './repositories/fasting.repository';
import { FastingService } from './services/fasting.service';
import { FastingAclService } from './services/fasting-acl.service';

@Module({
  imports: [SharedModule, TypeOrmModule.forFeature([Fasting]), UserModule],
  providers: [
    FastingService,
    JwtAuthStrategy,
    FastingAclService,
    FastingRepository,
  ],
  controllers: [FastingController],
  exports: [FastingService],
})
export class FastingModule {}
