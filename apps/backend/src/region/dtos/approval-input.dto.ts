import { ApiProperty } from '@nestjs/swagger';
import { IsBoolean } from 'class-validator';

/** Body of `POST /regions/:id/approval`. */
export class ApprovalInput {
  @ApiProperty()
  @IsBoolean()
  approveNewVolunteers: boolean;
}
