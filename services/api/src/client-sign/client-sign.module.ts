import { Global, Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { RedisService } from '../common/redis.service';
import { PrismaModule } from '../prisma/prisma.module';
import { ClientSignChallengeService } from './client-sign-challenge.service';
import { ClientSignService } from './client-sign.service';
import { ClientSignGuard } from './client-sign.guard';
import { DeviceBindingGuard } from './device-binding.guard';
import { DeviceCredentialService } from './device-credential.service';

@Global()
@Module({
  imports: [PrismaModule],
  providers: [
    RedisService,
    ClientSignChallengeService,
    ClientSignService,
    DeviceCredentialService,
    ClientSignGuard,
    DeviceBindingGuard,
    {
      provide: APP_GUARD,
      useClass: DeviceBindingGuard,
    },
  ],
  exports: [
    ClientSignChallengeService,
    ClientSignService,
    DeviceCredentialService,
    ClientSignGuard,
  ],
})
export class ClientSignModule {}
