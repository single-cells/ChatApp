import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AccessToken } from 'livekit-server-sdk';

@Injectable()
export class VoiceService {
  constructor(private config: ConfigService) {}

  createToken(roomId: string, userId: string, nickname: string) {
    const apiKey = this.config.get('LIVEKIT_API_KEY', 'devkey');
    const apiSecret = this.config.get('LIVEKIT_API_SECRET', 'secret');
    const livekitRoom = `room:${roomId}`;

    const at = new AccessToken(apiKey, apiSecret, {
      identity: userId,
      name: nickname,
      ttl: '10m',
    });
    at.addGrant({
      roomJoin: true,
      room: livekitRoom,
      canPublish: true,
      canSubscribe: true,
    });

    return {
      token: at.toJwt(),
      livekitUrl: this.config.get('LIVEKIT_URL', 'ws://localhost:7880'),
      roomName: livekitRoom,
    };
  }
}
