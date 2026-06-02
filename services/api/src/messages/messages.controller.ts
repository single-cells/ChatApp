import {
  Controller,
  Get,
  Param,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { MessagesService } from './messages.service';

@Controller('rooms/:roomId/messages')
@UseGuards(AuthGuard('jwt'))
export class MessagesController {
  constructor(private messages: MessagesService) {}

  @Get()
  list(
    @Param('roomId') roomId: string,
    @Req() req: { user: { userId: string } },
    @Query('before') before?: string,
    @Query('after') after?: string,
    @Query('limit') limit?: string,
  ) {
    return this.messages.list(roomId, req.user.userId, {
      before: before ? parseInt(before, 10) : undefined,
      after: after ? parseInt(after, 10) : undefined,
      limit: limit ? parseInt(limit, 10) : undefined,
    });
  }
}
