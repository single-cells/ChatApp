import { Injectable, UnauthorizedException } from '@nestjs/common';
import { randomBytes, randomUUID } from 'crypto';
import { RedisService } from '../common/redis.service';

export interface ClientChallenge {
  challengeId: string;
  nonce: string;
  expiresAt: string;
}

@Injectable()
export class ClientSignChallengeService {
  private readonly ttlSeconds = 300;

  constructor(private redis: RedisService) {}

  private key(challengeId: string) {
    return `client-sign:nonce:${challengeId}`;
  }

  async create(): Promise<ClientChallenge> {
    const challengeId = randomUUID();
    const nonce = randomBytes(32).toString('base64url');
    const expiresAt = new Date(Date.now() + this.ttlSeconds * 1000).toISOString();
    await this.redis.client.set(
      this.key(challengeId),
      nonce,
      'EX',
      this.ttlSeconds,
    );
    return { challengeId, nonce, expiresAt };
  }

  async consume(challengeId: string, nonce: string): Promise<void> {
    const stored = await this.redis.client.get(this.key(challengeId));
    if (!stored || stored !== nonce) {
      throw new UnauthorizedException('Invalid or expired challenge');
    }
    await this.redis.client.del(this.key(challengeId));
  }
}
