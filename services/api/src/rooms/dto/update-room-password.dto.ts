import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class UpdateRoomPasswordDto {
  /** Omit or empty string to remove room password. */
  @IsOptional()
  @IsString()
  @MaxLength(64)
  password?: string;
}
