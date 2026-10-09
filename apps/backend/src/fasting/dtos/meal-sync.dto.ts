import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsInt,
  IsISO8601,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  ValidateNested,
} from 'class-validator';

import { MealServedByOutput } from './meal-event-output.dto';

/** One meal served with no network, as the phone recorded it. */
export class SyncMealEventInput {
  @IsUUID('4')
  @ApiProperty({ format: 'uuid' })
  clientEventId: string;

  @IsInt()
  @ApiProperty()
  fastingId: number;

  @IsInt()
  @ApiProperty()
  regionId: number;

  /** Device time of the hand-over. */
  @IsISO8601()
  @ApiProperty()
  servedAt: string;

  @IsString()
  @MaxLength(64)
  @IsOptional()
  @ApiProperty({ required: false, maxLength: 64 })
  deviceId?: string;
}

export class SyncMealsInput {
  @IsArray()
  @ArrayMaxSize(200)
  @ValidateNested({ each: true })
  @Type(() => SyncMealEventInput)
  @ApiProperty({ type: [SyncMealEventInput], maxItems: 200 })
  events: SyncMealEventInput[];
}

export type MealSyncStatus = 'applied' | 'duplicate' | 'conflict' | 'rejected';

export class MealSyncOtherOutput {
  @ApiProperty()
  servedAt: string;

  @ApiProperty({ type: MealServedByOutput, nullable: true })
  servedBy: MealServedByOutput | null;
}

/** What happened to one synced event (spec 2B §4.1). */
export class MealSyncResultOutput {
  @ApiProperty({ format: 'uuid' })
  clientEventId: string;

  @ApiProperty({ enum: ['applied', 'duplicate', 'conflict', 'rejected'] })
  status: MealSyncStatus;

  @ApiProperty({ required: false, description: 'Set when rejected' })
  code?: string;

  @ApiProperty({
    required: false,
    description: 'Admin-review marker on an applied event',
  })
  flag?: string | null;

  @ApiProperty({
    type: MealSyncOtherOutput,
    required: false,
    description: 'Set on conflict',
  })
  other?: MealSyncOtherOutput;
}
