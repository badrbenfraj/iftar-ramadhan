import { ApiProperty } from '@nestjs/swagger';

/** What still points to a region: shown before closing or deleting it. */
export class RegionUsageOutput {
  @ApiProperty({ description: 'Volunteers and coordinators' })
  users: number;

  @ApiProperty({ description: 'Registered fasting people' })
  people: number;

  @ApiProperty({ description: 'Meals recorded, undone ones included' })
  meals: number;
}
