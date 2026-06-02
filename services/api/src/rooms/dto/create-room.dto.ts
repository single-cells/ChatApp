import { IsString, MaxLength, MinLength } from 'class-validator';

export class CreateRoomDto {
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  title!: string;
}
