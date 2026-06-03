import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { RedisService } from '../common/redis.service';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { GeoIpService } from './geo-ip.service';
import { JwtStrategy } from './jwt.strategy';
import { RefreshJwtGuard } from './refresh-jwt.guard';
import { WsJwtGuard } from './ws-jwt.guard';

@Module({
  imports: [
    PassportModule.register({ defaultStrategy: 'jwt' }),
    JwtModule.registerAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.get<string>('JWT_SECRET', 'dev-secret'),
        signOptions: {
          expiresIn: config.get<string>('JWT_EXPIRES_IN', '15m'),
        },
      }),
    }),
  ],
  controllers: [AuthController],
  providers: [
    AuthService,
    GeoIpService,
    JwtStrategy,
    WsJwtGuard,
    RefreshJwtGuard,
    RedisService,
  ],
  exports: [AuthService, JwtModule, WsJwtGuard],
})
export class AuthModule {}
