import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { CreateRoomDto } from './dto/create-room.dto';
import { JoinRoomDto } from './dto/join-room.dto';
import { UpdateRoomPasswordDto } from './dto/update-room-password.dto';
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

  @Get('all')
  listAll() {
    return this.rooms.listAll();
  }

  @Get('created-quota')
  createdQuota(@Req() req: { user: { userId: string } }) {
    return this.rooms.createdQuota(req.user.userId);
  }

  @Delete('purge-all')
  purgeAll() {
    return this.rooms.purgeAllRooms();
  }

  @Get(':roomId')
  findOne(@Param('roomId') roomId: string) {
    return this.rooms.findOne(roomId);
  }

  @Post(':roomId/join')
  join(
    @Param('roomId') roomId: string,
    @Req() req: { user: { userId: string } },
    @Body() dto: JoinRoomDto,
  ) {
    return this.rooms.join(roomId, req.user.userId, dto.password);
  }

  @Patch(':roomId/password')
  updatePassword(
    @Param('roomId') roomId: string,
    @Req() req: { user: { userId: string } },
    @Body() dto: UpdateRoomPasswordDto,
  ) {
    return this.rooms.updatePassword(roomId, req.user.userId, dto.password);
  }

  @Post(':roomId/leave')
  leave(
    @Param('roomId') roomId: string,
    @Req() req: { user: { userId: string } },
  ) {
    return this.rooms.leaveRoom(roomId, req.user.userId);
  }

  @Delete(':roomId/membership')
  dismissMembership(
    @Param('roomId') roomId: string,
    @Req() req: { user: { userId: string } },
  ) {
    return this.rooms.dismissMembership(roomId, req.user.userId);
  }

  @Delete(':roomId')
  remove(
    @Param('roomId') roomId: string,
    @Req() req: { user: { userId: string } },
  ) {
    return this.rooms.deleteRoom(roomId, req.user.userId);
  }
}
