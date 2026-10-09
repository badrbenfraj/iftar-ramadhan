import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { IsIn, IsInt, IsOptional, Min } from 'class-validator';

import { ROLE } from '../../auth/constants/role.constant';
import { PaginationParamsDto } from '../../shared/dtos/pagination-params.dto';
import { USER_STATUS, type UserStatus } from '../constants/user-status.constant';

export class UsersQueryDto extends PaginationParamsDto {
  @ApiPropertyOptional({ enum: Object.values(USER_STATUS) })
  @IsOptional()
  @IsIn(Object.values(USER_STATUS))
  status?: UserStatus;

  /** Global admins only; regional admins always see their own region. */
  @ApiPropertyOptional()
  @IsOptional()
  @IsInt()
  @Min(1)
  @Transform(({ value }) => parseInt(value, 10), { toClassOnly: true })
  regionId?: number;
}

export class ChangeRoleInput {
  @ApiProperty({ enum: [ROLE.USER, ROLE.REGION_ADMIN] })
  @IsIn([ROLE.USER, ROLE.REGION_ADMIN])
  role: ROLE.USER | ROLE.REGION_ADMIN;

  @ApiProperty()
  @IsInt()
  @Min(1)
  regionId: number;
}
