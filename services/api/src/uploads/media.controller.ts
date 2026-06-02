import {
  BadRequestException,
  Controller,
  Get,
  Query,
  Req,
  Res,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import type { Response } from 'express';
import { StorageService } from '../common/storage.service';
import { RoomsService } from '../rooms/rooms.service';

@Controller('media')
@UseGuards(AuthGuard('jwt'))
export class MediaController {
  constructor(
    private storage: StorageService,
    private rooms: RoomsService,
  ) {}

  @Get('object')
  async getObject(
    @Query('key') key: string,
    @Req() req: { user: { userId: string } },
    @Res() res: Response,
  ) {
    if (!key?.startsWith('rooms/')) {
      throw new BadRequestException('Invalid media key');
    }
    const roomId = key.split('/')[1];
    if (!roomId) {
      throw new BadRequestException('Invalid media key');
    }
    await this.rooms.ensureMember(roomId, req.user.userId);
    try {
      const obj = await this.storage.getObject(key);
      const body = obj.Body;
      if (!body) {
        res.status(404).end();
        return;
      }
      const bytes = await body.transformToByteArray();
      if (!bytes?.length) {
        res.status(404).end();
        return;
      }
      if (obj.ContentType) {
        res.setHeader('Content-Type', obj.ContentType);
      }
      res.setHeader('Content-Length', String(bytes.byteLength));
      res.setHeader('Cache-Control', 'private, max-age=3600');
      res.send(Buffer.from(bytes));
    } catch {
      res.status(404).end();
    }
  }
}
