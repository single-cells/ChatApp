import {
  BadRequestException,
  Body,
  Controller,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
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
