import { Body, Controller, Get, Post, Req, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { Request } from 'express';
import {
  ClientSignChallengeService,
  ClientChallenge,
} from '../client-sign/client-sign-challenge.service';
import { ClientSignGuard } from '../client-sign/client-sign.guard';
import { Public } from '../client-sign/public.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { AuthService } from './auth.service';
import { DeviceAuthDto } from './dto/device-auth.dto';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { RefreshJwtGuard } from './refresh-jwt.guard';

@Controller('auth')
export class AuthController {
  constructor(
    private auth: AuthService,
    private prisma: PrismaService,
    private challengeService: ClientSignChallengeService,
  ) {}

  @Public()
  @Get('challenge')
  getChallenge(): Promise<ClientChallenge> {
    return this.challengeService.create();
  }

  @Public()
  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.auth.register(dto);
  }

  @Public()
  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.auth.login(dto);
  }

  @Public()
  @UseGuards(ClientSignGuard)
  @Post('device')
  device(@Body() dto: DeviceAuthDto) {
    return this.auth.deviceAuth(dto);
  }

  @Public()
  @UseGuards(RefreshJwtGuard)
  @Post('refresh')
  refresh(
    @Req()
    req: Request & {
      user: { userId: string; deviceId?: string };
      refreshJti: string;
    },
  ) {
    return this.auth.refresh(
      req.user.userId,
      req.refreshJti,
      req.user.deviceId,
    );
  }

  @Get('me')
  @UseGuards(AuthGuard('jwt'))
  async me(@Req() req: { user: { userId: string } }) {
    return this.prisma.user.findUniqueOrThrow({
      where: { id: req.user.userId },
      select: {
        id: true,
        nickname: true,
        avatarUrl: true,
        email: true,
      },
    });
  }
}
