import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Reflector } from '@nestjs/core';
import { Request } from 'express';
import { IS_PUBLIC_KEY } from './public.decorator';

@Injectable()
export class DeviceBindingGuard implements CanActivate {
  constructor(
    private config: ConfigService,
    private reflector: Reflector,
  ) {}

  canActivate(context: ExecutionContext): boolean {
    if (this.config.get('CLIENT_SIGN_SKIP', 'false') === 'true') {
      return true;
    }

    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) {
      return true;
    }

    const req = context.switchToHttp().getRequest<
      Request & { user?: { userId: string; deviceId?: string } }
    >();
    const user = req.user;
    if (!user?.deviceId) {
      return true;
    }

    const headerDeviceId = req.header('x-device-id')?.trim();
    if (!headerDeviceId || headerDeviceId !== user.deviceId) {
      throw new UnauthorizedException('Device binding mismatch');
    }
    return true;
  }
}
