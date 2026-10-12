import { ApiProperty } from '@nestjs/swagger';
import { Expose } from 'class-transformer';

/** A region as global admins manage it, closed ones included. */
export class AdminRegionOutput {
  @Expose()
  @ApiProperty()
  id: number;

  @Expose()
  @ApiProperty()
  name: string;

  @Expose()
  @ApiProperty()
  active: boolean;

  @Expose()
  @ApiProperty()
  allowOfflineServing: boolean;

  @Expose()
  @ApiProperty({ nullable: true })
  closedAt: Date | null;
}
