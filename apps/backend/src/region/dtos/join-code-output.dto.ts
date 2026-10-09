import { ApiProperty } from '@nestjs/swagger';

export class JoinCodeOutput {
  @ApiProperty({ nullable: true, example: 'NOUR-482193' })
  joinCode: string | null;
}
