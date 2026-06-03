import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Request } from 'express';
import { AuthService, JwtPayload } from './auth.service';

@Injectable()
export class RefreshJwtGuard implements CanActivate {
  constructor(
    private jwt: JwtService,
    private config: ConfigService,
    private auth: AuthService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<Request>();
    const fromBody =
      typeof (req.body as { refreshToken?: string })?.refreshToken === 'string'
        ? (req.body as { refreshToken: string }).refreshToken
        : undefined;
    const fromHeader = req.header('authorization')?.replace(/^Bearer\s+/i, '');
    const token = fromBody ?? fromHeader;
    if (!token) {
      throw new UnauthorizedException('Refresh token required');
    }
    try {
      const payload = await this.jwt.verifyAsync<JwtPayload>(token, {
        secret: this.config.get('JWT_REFRESH_SECRET', 'dev-refresh-secret'),
      });
      if (payload.typ !== 'refresh' || !payload.jti) {
        throw new UnauthorizedException('Invalid refresh token');
      }
      const valid = await this.auth.validateRefreshJti(payload.jti, payload.sub);
      if (!valid) {
        throw new UnauthorizedException('Refresh token revoked');
      }
      req.user = {
        userId: payload.sub,
        deviceId: payload.did,
      };
      (req as Request & { refreshJti: string }).refreshJti = payload.jti;
      return true;
    } catch {
      throw new UnauthorizedException('Invalid refresh token');
    }
  }
}
