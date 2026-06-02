import { IsOptional, IsString, IsUUID, MaxLength, MinLength } from 'class-validator';

export class DeviceAuthDto {
  @IsUUID('4')
  deviceId!: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(32)
  nickname?: string;
}
