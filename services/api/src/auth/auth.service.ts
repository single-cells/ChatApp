import {
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Prisma } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { DeviceAuthDto } from './dto/device-auth.dto';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';

export interface JwtPayload {
  sub: string;
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
  ) {}

  async deviceAuth(dto: DeviceAuthDto): Promise<DeviceAuthResponse> {
    const deviceId = dto.deviceId.trim();
    const nickname = dto.nickname?.trim();

    const existing = await this.prisma.user.findUnique({
      where: { deviceId },
    });
    if (existing) {
      const session = await this.tokensForUser(existing.id);
      return { needsNickname: false, isNewUser: false, ...session };
    }

    if (!nickname) {
      return { needsNickname: true };
    }

    try {
      const user = await this.prisma.user.create({
        data: { deviceId, nickname },
      });
      const session = await this.tokensForUser(user.id);
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
          const session = await this.tokensForUser(raced.id);
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

  async refresh(userId: string) {
    const session = await this.tokensForUser(userId);
    return { ...session, isNewUser: false, needsNickname: false };
  }

  private async tokensForUser(userId: string) {
    const payload: JwtPayload = { sub: userId };
    const accessToken = await this.jwt.signAsync(payload);
    const refreshToken = await this.jwt.signAsync(payload, {
      expiresIn: this.config.get('JWT_REFRESH_EXPIRES_IN', '7d'),
    });
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

  validatePayload(payload: JwtPayload) {
    return { userId: payload.sub };
  }
}
