import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AuthModule } from './auth/auth.module';
import { ClientSignModule } from './client-sign/client-sign.module';
import { HealthController } from './health.controller';
import { MessagesModule } from './messages/messages.module';
import { PrismaModule } from './prisma/prisma.module';
import { RealtimeModule } from './realtime/realtime.module';
import { RoomsModule } from './rooms/rooms.module';
import { UploadsModule } from './uploads/uploads.module';
import { UsersModule } from './users/users.module';
import { VoiceModule } from './voice/voice.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    ClientSignModule,
    AuthModule,
    UsersModule,
    RoomsModule,
    MessagesModule,
    UploadsModule,
    RealtimeModule,
    VoiceModule,
  ],
  controllers: [HealthController],
})
export class AppModule {}
