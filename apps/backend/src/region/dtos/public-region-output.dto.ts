import { ApiProperty } from '@nestjs/swagger';
import { Expose } from 'class-transformer';

/** What the unauthenticated Register screen may see. */
export class PublicRegionOutput {
  @Expose()
  @ApiProperty()
  id: number;

  @Expose()
  @ApiProperty()
  name: string;
}
