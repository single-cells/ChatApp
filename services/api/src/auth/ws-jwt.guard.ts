import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { WsException } from '@nestjs/websockets';
import { Socket } from 'socket.io';
import { JwtPayload } from './auth.service';

@Injectable()
export class WsJwtGuard implements CanActivate {
  constructor(
    private jwt: JwtService,
    private config: ConfigService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const client = context.switchToWs().getClient<Socket>();
    const token =
      client.handshake.auth?.token ??
      client.handshake.headers?.authorization?.replace('Bearer ', '');
    if (!token) {
      throw new WsException('Unauthorized');
    }
    try {
      const payload = await this.jwt.verifyAsync<JwtPayload>(token, {
        secret: this.config.get('JWT_SECRET', 'dev-secret'),
      });
      client.data.userId = payload.sub;
      client.data.deviceId = payload.did;
      const handshakeDeviceId = client.handshake.auth?.deviceId as
        | string
        | undefined;
      if (
        payload.did &&
        handshakeDeviceId &&
        handshakeDeviceId !== payload.did
      ) {
        throw new WsException('Device binding mismatch');
      }
      return true;
    } catch {
      throw new WsException('Unauthorized');
    }
  }
}
