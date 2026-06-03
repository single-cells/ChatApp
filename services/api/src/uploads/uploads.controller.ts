import {
  BadRequestException,
  Body,
  Controller,
  Param,
  Post,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { FileInterceptor } from '@nestjs/platform-express';
import { StorageService } from '../common/storage.service';
import { RoomsService } from '../rooms/rooms.service';
import { PresignDto } from './dto/presign.dto';

@Controller('rooms/:roomId/uploads')
@UseGuards(AuthGuard('jwt'))
export class UploadsController {
  constructor(
    private storage: StorageService,
    private rooms: RoomsService,
  ) {}

  @Post()
  @UseInterceptors(
    FileInterceptor('file', { limits: { fileSize: 20 * 1024 * 1024 } }),
  )
  async upload(
    @Param('roomId') roomId: string,
    @Req() req: { user: { userId: string } },
    @Body() dto: PresignDto,
    @UploadedFile() file?: { buffer: Buffer; originalname?: string },
  ) {
    await this.rooms.ensureMember(roomId, req.user.userId);
    if (!file?.buffer?.length) {
      throw new BadRequestException('Missing file');
    }
    try {
      return await this.storage.uploadObject(
        roomId,
        req.user.userId,
        dto.kind,
        dto.mime,
        file.buffer,
        dto.filename ?? file.originalname,
      );
    } catch (e) {
      throw new BadRequestException(
        e instanceof Error ? e.message : 'Upload failed',
      );
    }
  }

  @Post('presign')
  async presign(
    @Param('roomId') roomId: string,
    @Req() req: { user: { userId: string } },
    @Body() dto: PresignDto,
  ) {
    await this.rooms.ensureMember(roomId, req.user.userId);
    try {
      return await this.storage.presign(
        roomId,
        req.user.userId,
        dto.kind,
        dto.mime,
        dto.filename,
      );
    } catch (e) {
      throw new BadRequestException(
        e instanceof Error ? e.message : 'Presign failed',
      );
    }
  }
}
