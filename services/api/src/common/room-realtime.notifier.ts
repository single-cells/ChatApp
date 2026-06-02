import { Injectable } from '@nestjs/common';
import { Server } from 'socket.io';
import { RedisService } from './redis.service';

/** Socket + Redis cleanup when a room is deleted (avoids Rooms <-> Realtime circular imports). */
@Injectable()
export class RoomRealtimeNotifier {
  private server?: Server;

  constructor(private redis: RedisService) {}

  setServer(server: Server) {
    this.server = server;
  }

  async notifyRoomRemoved(roomId: string) {
    const server = this.server;
    if (server) {
      server.to(roomId).emit('room.deleted', { roomId });
      const room = server.sockets.adapter.rooms.get(roomId);
      if (room) {
        for (const socketId of room) {
          const client = server.sockets.sockets.get(socketId);
          await client?.leave(roomId);
        }
      }
    }
    await this.redis.client.del(
      this.redis.roomOnlineKey(roomId),
      this.redis.voiceParticipantsKey(roomId),
    );
  }
}
