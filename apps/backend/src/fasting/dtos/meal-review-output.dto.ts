import { ApiProperty } from '@nestjs/swagger';

import { MealServedByOutput } from './meal-event-output.dto';

/** A meal an admin should look at: a double serve, or a flagged meal. */
export class MealReviewItemOutput {
  @ApiProperty({ format: 'uuid' })
  eventId: string;

  @ApiProperty()
  fastingId: number;

  @ApiProperty()
  personName: string;

  @ApiProperty()
  servedAt: string;

  @ApiProperty({ type: MealServedByOutput, nullable: true })
  servedBy: MealServedByOutput | null;

  @ApiProperty({ enum: ['online', 'offline', 'backfill'] })
  source: string;

  @ApiProperty({ description: 'A second meal the same day' })
  conflict: boolean;

  @ApiProperty({ nullable: true, description: 'e.g. OFFLINE_NOT_ALLOWED' })
  flag: string | null;

  @ApiProperty({ nullable: true })
  revokedAt: string | null;
}
