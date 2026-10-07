import { ApiProperty } from '@nestjs/swagger';

export class AppVersionOutput {
  @ApiProperty({
    type: String,
    nullable: true,
    example: '1.5.0',
    description: 'Newest published app version; null before the first release.',
  })
  latestVersion: string | null;

  @ApiProperty({
    type: String,
    nullable: true,
    example: '1.4.0',
    description: 'Installed versions below this must update before use.',
  })
  minimumVersion: string | null;

  @ApiProperty({ example: '/releases/latest.apk' })
  downloadUrl: string;

  @ApiProperty({ example: '/download' })
  downloadPageUrl: string;

  @ApiProperty({
    type: String,
    nullable: true,
    description: 'SHA-256 of the latest APK',
  })
  sha256: string | null;

  @ApiProperty({
    type: String,
    nullable: true,
    example: '2027-02-10T12:00:00Z',
  })
  releasedAt: string | null;
}
