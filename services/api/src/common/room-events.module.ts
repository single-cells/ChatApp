import { Module } from '@nestjs/common';
import { RedisService } from './redis.service';
import { RoomRealtimeNotifier } from './room-realtime.notifier';

@Module({
  providers: [RedisService, RoomRealtimeNotifier],
  exports: [RoomRealtimeNotifier],
})
export class RoomEventsModule {}
