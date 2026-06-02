import { Injectable, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

@Injectable()
export class RedisService implements OnModuleDestroy {
  readonly client: Redis;

  constructor(config: ConfigService) {
    const url = config.get('REDIS_URL', 'redis://localhost:6379');
    this.client = new Redis(url, { maxRetriesPerRequest: null });
  }

  async onModuleDestroy() {
    await this.client.quit();
  }

  roomOnlineKey(roomId: string) {
    return `room:${roomId}:online`;
  }

  voiceParticipantsKey(roomId: string) {
    return `room:${roomId}:voice:participants`;
  }
}
