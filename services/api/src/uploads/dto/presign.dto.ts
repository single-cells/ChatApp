import { IsIn, IsOptional, IsString } from 'class-validator';

export class PresignDto {
  @IsIn(['image', 'file', 'voice'])
  kind!: 'image' | 'file' | 'voice';

  @IsString()
  mime!: string;

  @IsOptional()
  @IsString()
  filename?: string;
}
