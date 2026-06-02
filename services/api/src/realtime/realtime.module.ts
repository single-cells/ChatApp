import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { RoomEventsModule } from '../common/room-events.module';
import { RedisService } from '../common/redis.service';
import { MessagesModule } from '../messages/messages.module';
import { RoomsModule } from '../rooms/rooms.module';
import { ChatGateway } from './chat.gateway';

@Module({
  imports: [AuthModule, RoomEventsModule, MessagesModule, RoomsModule],
  providers: [ChatGateway, RedisService],
})
export class RealtimeModule {}
