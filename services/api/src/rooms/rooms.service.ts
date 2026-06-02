import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { RoomRealtimeNotifier } from '../common/room-realtime.notifier';
import { RedisService } from '../common/redis.service';
import { PrismaService } from '../prisma/prisma.service';
import { CreateRoomDto } from './dto/create-room.dto';

export const MAX_ROOMS_PER_USER = 3;

@Injectable()
export class RoomsService {
  constructor(
    private prisma: PrismaService,
    private redis: RedisService,
    private config: ConfigService,
    private roomNotifier: RoomRealtimeNotifier,
  ) {}

  async create(userId: string, dto: CreateRoomDto) {
    const createdCount = await this.prisma.room.count({
      where: { createdBy: userId },
    });
    if (createdCount >= MAX_ROOMS_PER_USER) {
      throw new BadRequestException(
        `每人最多创建 ${MAX_ROOMS_PER_USER} 个聊天室`,
      );
    }
    const room = await this.prisma.room.create({
      data: {
        title: dto.title,
        createdBy: userId,
        members: {
          create: { userId },
        },
      },
    });
    return { roomId: room.id, title: room.title, createdAt: room.createdAt };
  }

  async findOne(roomId: string) {
    const room = await this.prisma.room.findUnique({
      where: { id: roomId },
      include: { _count: { select: { members: true } } },
    });
    if (!room) {
      throw new NotFoundException('Room not found');
    }
    return {
      roomId: room.id,
      title: room.title,
      memberCount: room._count.members,
      createdAt: room.createdAt,
      createdBy: room.createdBy,
    };
  }

  async join(roomId: string, userId: string) {
    await this.ensureRoom(roomId);
    await this.prisma.roomMember.upsert({
      where: { roomId_userId: { roomId, userId } },
      create: { roomId, userId },
      update: { joinedAt: new Date() },
    });
    return { roomId, joined: true };
  }

  async recent(userId: string) {
    const memberships = await this.prisma.roomMember.findMany({
      where: { userId },
      include: {
        room: {
          include: {
            _count: { select: { members: true } },
            messages: {
              orderBy: { createdAt: 'desc' },
              take: 1,
              include: { sender: { select: { nickname: true } } },
            },
          },
        },
      },
    });
    const items = memberships.map((m: (typeof memberships)[number]) => {
      const last = m.room.messages[0];
      return {
        roomId: m.room.id,
        title: m.room.title,
        memberCount: m.room._count.members,
        joinedAt: m.joinedAt,
        lastMessagePreview: last ? this.messagePreview(last) : null,
        lastMessageSender: last?.sender.nickname ?? null,
        lastMessageAt: last?.createdAt ?? null,
      };
    });
    items.sort((a, b) => {
      const ta = (a.lastMessageAt ?? a.joinedAt) as Date;
      const tb = (b.lastMessageAt ?? b.joinedAt) as Date;
      return tb.getTime() - ta.getTime();
    });
    return items.slice(0, 20);
  }

  async listAll() {
    const rooms = await this.prisma.room.findMany({
      orderBy: { createdAt: 'desc' },
      take: 100,
      include: {
        _count: { select: { members: true } },
        creator: { select: { nickname: true } },
      },
    });
    return rooms.map((room) => ({
      roomId: room.id,
      title: room.title,
      memberCount: room._count.members,
      createdAt: room.createdAt,
      creatorNickname: room.creator.nickname,
    }));
  }

  async createdQuota(userId: string) {
    const count = await this.prisma.room.count({
      where: { createdBy: userId },
    });
    return { count, max: MAX_ROOMS_PER_USER };
  }

  async deleteRoom(roomId: string, userId: string) {
    const room = await this.ensureRoom(roomId);
    if (room.createdBy !== userId) {
      throw new ForbiddenException('Only the room creator can delete this room');
    }
    await this.prisma.room.delete({ where: { id: roomId } });
    await this.roomNotifier.notifyRoomRemoved(roomId);
    return { roomId, deleted: true };
  }

  async leaveRoom(roomId: string, userId: string) {
    const room = await this.ensureRoom(roomId);
    if (room.createdBy === userId) {
      throw new BadRequestException(
        'Room creator cannot leave; delete the room instead',
      );
    }
    const member = await this.prisma.roomMember.findUnique({
      where: { roomId_userId: { roomId, userId } },
    });
    if (!member) {
      throw new NotFoundException('You are not a member of this room');
    }
    await this.prisma.roomMember.delete({
      where: { roomId_userId: { roomId, userId } },
    });
    await this.redis.client.srem(this.redis.roomOnlineKey(roomId), userId);
    return { roomId, left: true };
  }

  async purgeAllRooms() {
    if (this.config.get('ALLOW_ROOM_PURGE') !== 'true') {
      throw new ForbiddenException(
        'Set ALLOW_ROOM_PURGE=true to purge all rooms',
      );
    }
    const rooms = await this.prisma.room.findMany({ select: { id: true } });
    for (const { id } of rooms) {
      await this.roomNotifier.notifyRoomRemoved(id);
    }
    const result = await this.prisma.room.deleteMany();
    return { deletedCount: result.count };
  }

  private messagePreview(msg: {
    type: string;
    content: string;
    attachmentMeta?: unknown;
  }) {
    switch (msg.type) {
      case 'image':
        return '[图片]';
      case 'file':
        return '[文件]';
      case 'voice':
        return '[语音]';
      default:
        return msg.content || '';
    }
  }

  async ensureMember(roomId: string, userId: string) {
    await this.ensureRoom(roomId);
    const member = await this.prisma.roomMember.findUnique({
      where: { roomId_userId: { roomId, userId } },
    });
    if (!member) {
      await this.prisma.roomMember.create({
        data: { roomId, userId },
      });
    }
  }

  private async ensureRoom(roomId: string) {
    const room = await this.prisma.room.findUnique({ where: { id: roomId } });
    if (!room) {
      throw new NotFoundException('Room not found');
    }
    return room;
  }
}
