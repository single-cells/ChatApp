import {
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Prisma } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { randomUUID } from 'crypto';
import { RedisService } from '../common/redis.service';
import { PrismaService } from '../prisma/prisma.service';
import { DeviceAuthDto } from './dto/device-auth.dto';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';

export interface JwtPayload {
  sub: string;
  did?: string;
  typ?: 'access' | 'refresh';
  jti?: string;
}

export type DeviceAuthResponse =
  | { needsNickname: true }
  | {
      needsNickname: false;
      accessToken: string;
      refreshToken: string;
      isNewUser: boolean;
      user: {
        id: string;
        nickname: string;
        avatarUrl: string | null;
        email: string | null;
      };
    };

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwt: JwtService,
    private config: ConfigService,
    private redis: RedisService,
  ) {}

  private refreshKey(jti: string) {
    return `refresh:jti:${jti}`;
  }

  async validateRefreshJti(jti: string, userId: string): Promise<boolean> {
    const stored = await this.redis.client.get(this.refreshKey(jti));
    return stored === userId;
  }

  async deviceAuth(dto: DeviceAuthDto): Promise<DeviceAuthResponse> {
    const deviceId = dto.deviceId.trim();
    const nickname = dto.nickname?.trim();

    const existing = await this.prisma.user.findUnique({
      where: { deviceId },
    });
    if (existing) {
      const session = await this.tokensForUser(existing.id, deviceId);
      return { needsNickname: false, isNewUser: false, ...session };
    }

    if (!nickname) {
      return { needsNickname: true };
    }

    try {
      const user = await this.prisma.user.create({
        data: { deviceId, nickname },
      });
      const session = await this.tokensForUser(user.id, deviceId);
      return { needsNickname: false, isNewUser: true, ...session };
    } catch (e) {
      if (
        e instanceof Prisma.PrismaClientKnownRequestError &&
        e.code === 'P2002'
      ) {
        const raced = await this.prisma.user.findUnique({
          where: { deviceId },
        });
        if (raced) {
          const session = await this.tokensForUser(raced.id, deviceId);
          return { needsNickname: false, isNewUser: false, ...session };
        }
      }
      throw e;
    }
  }

  async register(dto: RegisterDto) {
    const existing = await this.prisma.user.findUnique({
      where: { email: dto.email },
    });
    if (existing) {
      throw new ConflictException('Email already registered');
    }
    const passwordHash = await bcrypt.hash(dto.password, 10);
    const user = await this.prisma.user.create({
      data: {
        email: dto.email,
        passwordHash,
        nickname: dto.nickname ?? dto.email.split('@')[0],
      },
    });
    const session = await this.tokensForUser(user.id);
    return { ...session, isNewUser: true, needsNickname: false };
  }

  async login(dto: LoginDto) {
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email },
    });
    if (!user?.passwordHash) {
      throw new UnauthorizedException('Invalid credentials');
    }
    const ok = await bcrypt.compare(dto.password, user.passwordHash);
    if (!ok) {
      throw new UnauthorizedException('Invalid credentials');
    }
    const session = await this.tokensForUser(user.id);
    return { ...session, isNewUser: false, needsNickname: false };
  }

  async refresh(userId: string, oldJti: string, deviceId?: string) {
    await this.redis.client.del(this.refreshKey(oldJti));
    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: { deviceId: true },
    });
    const did = deviceId ?? user.deviceId ?? undefined;
    const session = await this.tokensForUser(userId, did);
    return { ...session, isNewUser: false, needsNickname: false };
  }

  private async tokensForUser(userId: string, deviceId?: string) {
    const accessPayload: JwtPayload = {
      sub: userId,
      typ: 'access',
      ...(deviceId ? { did: deviceId } : {}),
    };
    const jti = randomUUID();
    const refreshPayload: JwtPayload = {
      sub: userId,
      typ: 'refresh',
      jti,
      ...(deviceId ? { did: deviceId } : {}),
    };

    const accessToken = await this.jwt.signAsync(accessPayload);
    const refreshExpiresIn = this.config.get('JWT_REFRESH_EXPIRES_IN', '7d');
    const refreshToken = await this.jwt.signAsync(refreshPayload, {
      secret: this.config.get('JWT_REFRESH_SECRET', 'dev-refresh-secret'),
      expiresIn: refreshExpiresIn,
    });

    const refreshTtlSec = this.parseDurationSeconds(refreshExpiresIn);
    await this.redis.client.set(
      this.refreshKey(jti),
      userId,
      'EX',
      refreshTtlSec,
    );

    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        nickname: true,
        avatarUrl: true,
      },
    });
    return { accessToken, refreshToken, user };
  }

  private parseDurationSeconds(raw: string): number {
    const m = /^(\d+)([smhd])$/.exec(raw.trim());
    if (!m) return 7 * 24 * 3600;
    const n = Number(m[1]);
    switch (m[2]) {
      case 's':
        return n;
      case 'm':
        return n * 60;
      case 'h':
        return n * 3600;
      default:
        return n * 86400;
    }
  }

  validatePayload(payload: JwtPayload) {
    if (payload.typ === 'refresh') {
      throw new UnauthorizedException('Invalid token type');
    }
    return {
      userId: payload.sub,
      deviceId: payload.did,
    };
  }
}
