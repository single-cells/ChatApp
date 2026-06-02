import { Module } from '@nestjs/common';
import { RoomEventsModule } from '../common/room-events.module';
import { RedisService } from '../common/redis.service';
import { RoomsController } from './rooms.controller';
import { RoomsService } from './rooms.service';

@Module({
  imports: [RoomEventsModule],
  controllers: [RoomsController],
  providers: [RoomsService, RedisService],
  exports: [RoomsService],
})
export class RoomsModule {}
