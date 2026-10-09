import { ApiProperty } from '@nestjs/swagger';

export class JoinCodeOutput {
  @ApiProperty({ nullable: true, example: 'NOUR-4821' })
  joinCode: string | null;
}
