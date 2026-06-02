import { Body, Controller, Get, Post, Req, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { PrismaService } from '../prisma/prisma.service';
import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';

@Controller('auth')
export class AuthController {
  constructor(
    private auth: AuthService,
    private prisma: PrismaService,
  ) {}

  @Post('register')
  register(@Body() dto: RegisterDto) {
    return this.auth.register(dto);
  }

  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.auth.login(dto);
  }

  @Post('refresh')
  @UseGuards(AuthGuard('jwt'))
  refresh(@Req() req: { user: { userId: string; email: string } }) {
    return this.auth.refresh(req.user.userId, req.user.email);
  }

  @Get('me')
  @UseGuards(AuthGuard('jwt'))
  async me(@Req() req: { user: { userId: string } }) {
    return this.prisma.user.findUniqueOrThrow({
      where: { id: req.user.userId },
      select: { id: true, email: true, nickname: true, avatarUrl: true },
    });
  }
}
