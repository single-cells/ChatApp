import { Controller, Param, Post, Req, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { PrismaService } from '../prisma/prisma.service';
import { RoomsService } from '../rooms/rooms.service';
import { VoiceService } from './voice.service';

@Controller('rooms/:roomId/voice')
@UseGuards(AuthGuard('jwt'))
export class VoiceController {
  constructor(
    private voice: VoiceService,
    private rooms: RoomsService,
    private prisma: PrismaService,
  ) {}

  @Post('token')
  async token(
    @Param('roomId') roomId: string,
    @Req() req: { user: { userId: string } },
  ) {
    await this.rooms.ensureMember(roomId, req.user.userId);
    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: req.user.userId },
      select: { nickname: true },
    });
    return this.voice.createToken(roomId, req.user.userId, user.nickname);
  }
}
