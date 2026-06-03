import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
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

  private roomHasPassword(passwordHash: string | null | undefined) {
    return !!passwordHash;
  }

  private async hashPassword(password: string) {
    return bcrypt.hash(password, 10);
  }

  private async verifyPassword(password: string, hash: string) {
    return bcrypt.compare(password, hash);
  }

  private toRoomDto(room: {
    id: string;
    title: string;
    createdAt: Date;
    createdBy: string;
    passwordHash?: string | null;
    _count?: { members: number };
    creator?: { nickname: string };
  }) {
    return {
      roomId: room.id,
      title: room.title,
      createdAt: room.createdAt,
      createdBy: room.createdBy,
      hasPassword: this.roomHasPassword(room.passwordHash),
      ...(room._count
        ? { memberCount: room._count.members }
        : {}),
      ...(room.creator ? { creatorNickname: room.creator.nickname } : {}),
    };
  }

  async create(userId: string, dto: CreateRoomDto) {
    const createdCount = await this.prisma.room.count({
      where: { createdBy: userId },
    });
    if (createdCount >= MAX_ROOMS_PER_USER) {
      throw new BadRequestException(
        `每人最多创建 ${MAX_ROOMS_PER_USER} 个聊天室`,
      );
    }
    const password = dto.password?.trim();
    const passwordHash =
      password && password.length > 0
        ? await this.hashPassword(password)
        : null;
    const room = await this.prisma.room.create({
      data: {
        title: dto.title,
        createdBy: userId,
        passwordHash,
        members: {
          create: { userId },
        },
      },
    });
    return this.toRoomDto(room);
  }

  async findOne(roomId: string) {
    const room = await this.prisma.room.findUnique({
      where: { id: roomId },
      include: { _count: { select: { members: true } } },
    });
    if (!room) {
      throw new NotFoundException('Room not found');
    }
    return this.toRoomDto({ ...room, _count: room._count });
  }

  async join(roomId: string, userId: string, password?: string) {
    const room = await this.ensureRoom(roomId);
    const existing = await this.prisma.roomMember.findUnique({
      where: { roomId_userId: { roomId, userId } },
    });
    if (existing) {
      return { roomId, joined: true };
    }
    if (this.roomHasPassword(room.passwordHash)) {
      const provided = password?.trim() ?? '';
      if (!provided) {
        throw new UnauthorizedException({
          code: 'ROOM_PASSWORD_REQUIRED',
          message: '需要输入房间密码',
        });
      }
      const ok = await this.verifyPassword(provided, room.passwordHash!);
      if (!ok) {
        throw new UnauthorizedException({
          code: 'ROOM_PASSWORD_INVALID',
          message: '房间密码错误',
        });
      }
    }
    await this.prisma.roomMember.create({
      data: { roomId, userId },
    });
    return { roomId, joined: true };
  }

  async updatePassword(roomId: string, userId: string, rawPassword?: string) {
    const room = await this.ensureRoom(roomId);
    if (room.createdBy !== userId) {
      throw new ForbiddenException('Only the room creator can change password');
    }
    const password = rawPassword?.trim() ?? '';
    const passwordHash =
      password.length > 0 ? await this.hashPassword(password) : null;
    await this.prisma.room.update({
      where: { id: roomId },
      data: { passwordHash },
    });
    return {
      roomId,
      hasPassword: this.roomHasPassword(passwordHash),
    };
  }

  /** Drop recent-list rows whose room was deleted (e.g. by creator). */
  private async pruneStaleMemberships(userId: string): Promise<number> {
    const memberships = await this.prisma.roomMember.findMany({
      where: { userId },
      select: { roomId: true },
    });
    if (memberships.length === 0) return 0;

    const roomIds = memberships.map((m) => m.roomId);
    const existing = await this.prisma.room.findMany({
      where: { id: { in: roomIds } },
      select: { id: true },
    });
    const existingIds = new Set(existing.map((r) => r.id));
    const staleIds = roomIds.filter((id) => !existingIds.has(id));
    if (staleIds.length === 0) return 0;

    const result = await this.prisma.roomMember.deleteMany({
      where: { userId, roomId: { in: staleIds } },
    });
    return result.count;
  }

  async recent(userId: string) {
    const prunedCount = await this.pruneStaleMemberships(userId);

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
        createdBy: m.room.createdBy,
        hasPassword: this.roomHasPassword(m.room.passwordHash),
        joinedAt: m.joinedAt,
        lastMessagePreview: last ? this.messagePreview(last) : null,
        lastMessageSender: last?.sender.nickname ?? null,
        lastMessageAt: last?.createdAt ?? null,
      };
    });
    items.sort((a, b) => {
      const aOwn = a.createdBy === userId;
      const bOwn = b.createdBy === userId;
      if (aOwn !== bOwn) return aOwn ? -1 : 1;
      const ta = (a.lastMessageAt ?? a.joinedAt) as Date;
      const tb = (b.lastMessageAt ?? b.joinedAt) as Date;
      return tb.getTime() - ta.getTime();
    });
    return { items: items.slice(0, 20), prunedCount };
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
    return rooms.map((room) =>
      this.toRoomDto({
        ...room,
        _count: room._count,
        creator: room.creator,
      }),
    );
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

  async dismissMembership(roomId: string, userId: string) {
    await this.prisma.roomMember.deleteMany({
      where: { roomId, userId },
    });
    return { roomId, dismissed: true };
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
      throw new ForbiddenException('Not a member of this room');
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
