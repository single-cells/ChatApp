import {
  Body,
  Controller,
  Delete,
  Get,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { Request } from 'express';
import { extractClientIp } from './client-ip';
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
import { UpdateNicknameDto } from './dto/update-nickname.dto';
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
  register(@Body() dto: RegisterDto, @Req() req: Request) {
    return this.auth.register(dto, extractClientIp(req));
  }

  @Public()
  @Post('login')
  login(@Body() dto: LoginDto, @Req() req: Request) {
    return this.auth.login(dto, extractClientIp(req));
  }

  @Public()
  @UseGuards(ClientSignGuard)
  @Post('device')
  device(@Body() dto: DeviceAuthDto, @Req() req: Request) {
    return this.auth.deviceAuth(dto, extractClientIp(req));
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
      extractClientIp(req),
    );
  }

  @Get('me')
  @UseGuards(AuthGuard('jwt'))
  async me(@Req() req: { user: { userId: string } }) {
    const user = await this.prisma.user.findUniqueOrThrow({
      where: { id: req.user.userId },
      select: {
        id: true,
        nickname: true,
        avatarUrl: true,
        email: true,
        nicknameChangedAt: true,
      },
    });
    return this.auth.toMeProfile(user);
  }

  @Patch('nickname')
  @UseGuards(AuthGuard('jwt'))
  updateNickname(
    @Req() req: { user: { userId: string } },
    @Body() dto: UpdateNicknameDto,
  ) {
    return this.auth.updateNickname(req.user.userId, dto.nickname);
  }

  @Delete('account')
  @UseGuards(AuthGuard('jwt'))
  deleteAccount(@Req() req: { user: { userId: string } }) {
    return this.auth.deleteAccount(req.user.userId);
  }
}
