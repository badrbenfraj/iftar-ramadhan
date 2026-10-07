import { ApiProperty } from '@nestjs/swagger';
import { Expose } from 'class-transformer';

export class MealServedByOutput {
  @Expose()
  @ApiProperty()
  id: number;

  @Expose()
  @ApiProperty()
  name: string;
}

/** One meal as the apps see it (spec 2A §4). */
export class MealEventOutput {
  @Expose()
  @ApiProperty({ format: 'uuid' })
  eventId: string;

  @Expose()
  @ApiProperty({ description: 'ISO instant' })
  servedAt: string;

  @Expose()
  @ApiProperty({
    type: MealServedByOutput,
    nullable: true,
    description: 'Null for history recorded before served-by existed',
  })
  servedBy: MealServedByOutput | null;

  @Expose()
  @ApiProperty({ nullable: true, description: 'ISO instant, set once undone' })
  revokedAt: string | null;
}
