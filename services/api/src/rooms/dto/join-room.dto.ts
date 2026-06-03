import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class JoinRoomDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(64)
  password?: string;
}
