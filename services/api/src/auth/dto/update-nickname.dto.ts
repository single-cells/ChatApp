import { IsString, MaxLength, MinLength } from 'class-validator';

export class UpdateNicknameDto {
  @IsString()
  @MinLength(1)
  @MaxLength(64)
  nickname!: string;
}
