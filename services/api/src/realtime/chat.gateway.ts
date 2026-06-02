import { Logger, UseGuards } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { WsJwtGuard } from '../auth/ws-jwt.guard';
import { JwtPayload } from '../auth/auth.service';
import { RedisService } from '../common/redis.service';
import { MessagesService } from '../messages/messages.service';
import { PrismaService } from '../prisma/prisma.service';
import { RoomsService } from '../rooms/rooms.service';

interface RoomJoinPayload {
  roomId: string;
}

interface MessageSendPayload {
  roomId: string;
  type: string;
  content?: string;
  attachmentUrl?: string;
  attachmentMeta?: Record<string, unknown>;
}

@WebSocketGateway({
  cors: { origin: '*' },
  transports: ['websocket', 'polling'],
})
export class ChatGateway implements OnGatewayConnection, OnGatewayDisconnect {
  private readonly logger = new Logger(ChatGateway.name);

  @WebSocketServer()
  server!: Server;

  constructor(
    private messages: MessagesService,
    private rooms: RoomsService,
    private redis: RedisService,
    private prisma: PrismaService,
    private jwt: JwtService,
    private config: ConfigService,
  ) {}

  async handleConnection(client: Socket) {
    const token =
      client.handshake.auth?.token ??
      client.handshake.headers?.authorization?.replace('Bearer ', '');
    if (!token) {
      client.disconnect();
      return;
    }
    try {
      const payload = await this.jwt.verifyAsync<JwtPayload>(token, {
        secret: this.config.get('JWT_SECRET', 'dev-secret'),
      });
      client.data.userId = payload.sub;
      client.data.email = payload.email;
    } catch {
      client.disconnect();
    }
  }

  async handleDisconnect(client: Socket) {
    const userId = client.data.userId as string | undefined;
    if (!userId) return;
    for (const roomId of client.rooms) {
      if (roomId === client.id) continue;
      await this.redis.client.srem(this.redis.roomOnlineKey(roomId), userId);
      await this.broadcastPresence(roomId);
    }
  }

  @UseGuards(WsJwtGuard)
  @SubscribeMessage('room.join')
  async onRoomJoin(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: RoomJoinPayload,
  ) {
    const userId = client.data.userId as string;
    await this.rooms.ensureMember(body.roomId, userId);
    await client.join(body.roomId);
    await this.redis.client.sadd(
      this.redis.roomOnlineKey(body.roomId),
      userId,
    );
    await this.broadcastPresence(body.roomId);
    client.emit('room.ready', { roomId: body.roomId });
    return { ok: true };
  }

  @UseGuards(WsJwtGuard)
  @SubscribeMessage('room.leave')
  async onRoomLeave(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: RoomJoinPayload,
  ) {
    const userId = client.data.userId as string;
    await client.leave(body.roomId);
    await this.redis.client.srem(
      this.redis.roomOnlineKey(body.roomId),
      userId,
    );
    await this.broadcastPresence(body.roomId);
    return { ok: true };
  }

  @UseGuards(WsJwtGuard)
  @SubscribeMessage('message.send')
  async onMessageSend(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: MessageSendPayload,
  ) {
    const userId = client.data.userId as string;
    const rateKey = `ratelimit:msg:${body.roomId}:${userId}`;
    const count = await this.redis.client.incr(rateKey);
    if (count === 1) {
      await this.redis.client.expire(rateKey, 1);
    }
    if (count > 10) {
      client.emit('error', { code: 'RATE_LIMIT', message: 'Too many messages' });
      return { ok: false };
    }
    const message = await this.messages.send({
      roomId: body.roomId,
      senderId: userId,
      type: body.type,
      content: body.content,
      attachmentUrl: body.attachmentUrl,
      attachmentMeta: body.attachmentMeta,
    });
    this.server.to(body.roomId).emit('message.new', message);
    return { ok: true, message };
  }

  @UseGuards(WsJwtGuard)
  @SubscribeMessage('call.join')
  async onCallJoin(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: RoomJoinPayload,
  ) {
    const userId = client.data.userId as string;
    await this.rooms.ensureMember(body.roomId, userId);
    const key = this.redis.voiceParticipantsKey(body.roomId);
    await this.redis.client.hset(key, userId, JSON.stringify({ muted: false }));
    await this.broadcastCallState(body.roomId);
    return { ok: true };
  }

  @UseGuards(WsJwtGuard)
  @SubscribeMessage('call.leave')
  async onCallLeave(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: RoomJoinPayload,
  ) {
    const userId = client.data.userId as string;
    await this.redis.client.hdel(
      this.redis.voiceParticipantsKey(body.roomId),
      userId,
    );
    await this.broadcastCallState(body.roomId);
    return { ok: true };
  }

  private async broadcastPresence(roomId: string) {
    const count = await this.redis.client.scard(
      this.redis.roomOnlineKey(roomId),
    );
    this.server.to(roomId).emit('presence.update', { roomId, count });
  }

  private async broadcastCallState(roomId: string) {
    const key = this.redis.voiceParticipantsKey(roomId);
    const raw = await this.redis.client.hgetall(key);
    const userIds = Object.keys(raw);
    const users = await this.prisma.user.findMany({
      where: { id: { in: userIds } },
      select: { id: true, nickname: true },
    });
    const byId = new Map(
      users.map((u: { id: string; nickname: string }) => [u.id, u]),
    );
    const participants = userIds.map((id) => {
      const meta = JSON.parse(raw[id] ?? '{}') as { muted?: boolean };
      const user = byId.get(id);
      return {
        userId: id,
        nickname: user?.nickname ?? 'User',
        muted: meta.muted ?? false,
      };
    });
    this.server.to(roomId).emit('call.state', { roomId, participants });
  }
}
