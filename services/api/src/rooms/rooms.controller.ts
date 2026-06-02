import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { CreateRoomDto } from './dto/create-room.dto';
import { RoomsService } from './rooms.service';

@Controller('rooms')
@UseGuards(AuthGuard('jwt'))
export class RoomsController {
  constructor(private rooms: RoomsService) {}

  @Post()
  create(
    @Req() req: { user: { userId: string } },
    @Body() dto: CreateRoomDto,
  ) {
    return this.rooms.create(req.user.userId, dto);
  }

  @Get('recent')
  recent(@Req() req: { user: { userId: string } }) {
    return this.rooms.recent(req.user.userId);
  }

  @Get(':roomId')
  findOne(@Param('roomId') roomId: string) {
    return this.rooms.findOne(roomId);
  }

  @Post(':roomId/join')
  join(
    @Param('roomId') roomId: string,
    @Req() req: { user: { userId: string } },
  ) {
    return this.rooms.join(roomId, req.user.userId);
  }
}
