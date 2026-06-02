import {
  CanActivate,
  ExecutionContext,
  HttpException,
  HttpStatus,
  Injectable,
} from '@nestjs/common';
import { RedisService } from './redis.service';

/** Simple per-user message rate limit for Phase 6 */
@Injectable()
export class MessageRateLimitGuard implements CanActivate {
  constructor(private redis: RedisService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<{
      user?: { userId: string };
      params?: { roomId?: string };
    }>();
    const userId = req.user?.userId;
    const roomId = req.params?.roomId;
    if (!userId || !roomId) return true;

    const key = `ratelimit:msg:${roomId}:${userId}`;
    const count = await this.redis.client.incr(key);
    if (count === 1) {
      await this.redis.client.expire(key, 1);
    }
    if (count > 10) {
      throw new HttpException('Too many requests', HttpStatus.TOO_MANY_REQUESTS);
    }
    return true;
  }
}
