import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateRoomDto } from './dto/create-room.dto';

@Injectable()
export class RoomsService {
  constructor(private prisma: PrismaService) {}

  async create(userId: string, dto: CreateRoomDto) {
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
      orderBy: { joinedAt: 'desc' },
      take: 20,
      include: { room: true },
    });
    return memberships.map((m: (typeof memberships)[number]) => ({
      roomId: m.room.id,
      title: m.room.title,
      joinedAt: m.joinedAt,
    }));
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
