import { IsOptional, IsString, IsUUID, MaxLength, MinLength } from 'class-validator';

export class DeviceAuthDto {
  @IsUUID('4')
  deviceId!: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(64)
  nickname?: string;

  @IsOptional()
  @IsString()
  publicKey?: string;

  @IsOptional()
  @IsString()
  deviceSignature?: string;

  @IsOptional()
  @IsString()
  challengeId?: string;
}
