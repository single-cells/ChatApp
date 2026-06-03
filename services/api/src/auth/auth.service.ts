import {
  BadRequestException,
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
import { GeoIpService } from './geo-ip.service';
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
    private geoIp: GeoIpService,
  ) {}

  private async recordLoginAudit(userId: string, clientIp?: string) {
    if (!clientIp) return;
    const geo = await this.geoIp.resolveLocation(clientIp);
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        lastLoginIp: clientIp,
        ...(geo ? { lastLoginGeo: geo } : {}),
      },
    });
  }

  private refreshKey(jti: string) {
    return `refresh:jti:${jti}`;
  }

  async validateRefreshJti(jti: string, userId: string): Promise<boolean> {
    const stored = await this.redis.client.get(this.refreshKey(jti));
    return stored === userId;
  }

  async deviceAuth(
    dto: DeviceAuthDto,
    clientIp?: string,
  ): Promise<DeviceAuthResponse> {
    const deviceId = dto.deviceId.trim();
    const nickname = dto.nickname?.trim();

    const existing = await this.prisma.user.findUnique({
      where: { deviceId },
    });
    if (existing) {
      const session = await this.tokensForUser(existing.id, deviceId);
      await this.recordLoginAudit(existing.id, clientIp);
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
      await this.recordLoginAudit(user.id, clientIp);
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
          await this.recordLoginAudit(raced.id, clientIp);
          return { needsNickname: false, isNewUser: false, ...session };
        }
      }
      throw e;
    }
  }

  async register(dto: RegisterDto, clientIp?: string) {
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
    await this.recordLoginAudit(user.id, clientIp);
    return { ...session, isNewUser: true, needsNickname: false };
  }

  async login(dto: LoginDto, clientIp?: string) {
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
    await this.recordLoginAudit(user.id, clientIp);
    return { ...session, isNewUser: false, needsNickname: false };
  }

  async refresh(
    userId: string,
    oldJti: string,
    deviceId?: string,
    clientIp?: string,
  ) {
    await this.redis.client.del(this.refreshKey(oldJti));
    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: { deviceId: true },
    });
    const did = deviceId ?? user.deviceId ?? undefined;
    const session = await this.tokensForUser(userId, did);
    await this.recordLoginAudit(userId, clientIp);
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

  canChangeNicknameToday(nicknameChangedAt: Date | null | undefined): boolean {
    if (!nicknameChangedAt) return true;
    const day = (d: Date) => d.toISOString().slice(0, 10);
    return day(nicknameChangedAt) !== day(new Date());
  }

  toMeProfile(user: {
    id: string;
    nickname: string;
    avatarUrl: string | null;
    email: string | null;
    nicknameChangedAt: Date | null;
  }) {
    return {
      id: user.id,
      nickname: user.nickname,
      avatarUrl: user.avatarUrl,
      email: user.email,
      canChangeNicknameToday: this.canChangeNicknameToday(user.nicknameChangedAt),
    };
  }

  async updateNickname(userId: string, rawNickname: string) {
    const nickname = rawNickname.trim();
    if (!nickname) {
      throw new BadRequestException('昵称不能为空');
    }

    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: {
        id: true,
        nickname: true,
        avatarUrl: true,
        email: true,
        nicknameChangedAt: true,
      },
    });

    if (user.nickname === nickname) {
      return this.toMeProfile(user);
    }

    if (!this.canChangeNicknameToday(user.nicknameChangedAt)) {
      throw new BadRequestException('今日已修改过昵称，请明天再试');
    }

    const updated = await this.prisma.user.update({
      where: { id: userId },
      data: { nickname, nicknameChangedAt: new Date() },
      select: {
        id: true,
        nickname: true,
        avatarUrl: true,
        email: true,
        nicknameChangedAt: true,
      },
    });

    return this.toMeProfile(updated);
  }

  async deleteAccount(userId: string) {
    const createdCount = await this.prisma.room.count({
      where: { createdBy: userId },
    });
    if (createdCount > 0) {
      throw new BadRequestException(
        `您创建了 ${createdCount} 个聊天室，请先删除全部创建的聊天室后再注销账号`,
      );
    }

    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: { deviceId: true },
    });

    await this.prisma.$transaction(async (tx) => {
      await tx.message.deleteMany({ where: { senderId: userId } });
      await tx.roomMember.deleteMany({ where: { userId } });
      if (user.deviceId) {
        await tx.deviceCredential.deleteMany({
          where: { deviceId: user.deviceId },
        });
      }
      await tx.user.delete({ where: { id: userId } });
    });

    return { deleted: true };
  }
}
