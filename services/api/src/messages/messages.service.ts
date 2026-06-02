import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { RoomsService } from '../rooms/rooms.service';

type MessageWithSender = {
  id: string;
  roomId: string;
  senderId: string;
  type: string;
  content: string;
  attachmentUrl: string | null;
  attachmentMeta: unknown;
  seq: number;
  createdAt: Date;
  sender: { id: string; nickname: string; avatarUrl: string | null };
};

export interface SendMessageInput {
  roomId: string;
  senderId: string;
  type: string;
  content?: string;
  attachmentUrl?: string;
  attachmentMeta?: Record<string, unknown>;
}

@Injectable()
export class MessagesService {
  constructor(
    private prisma: PrismaService,
    private rooms: RoomsService,
  ) {}

  async list(
    roomId: string,
    userId: string,
    opts: { before?: number; after?: number; limit?: number },
  ) {
    await this.rooms.ensureMember(roomId, userId);
    const limit = Math.min(opts.limit ?? 50, 100);
    const where: {
      roomId: string;
      seq?: { lt?: number; gt?: number };
    } = { roomId };
    if (opts.before != null) {
      where.seq = { lt: opts.before };
    } else if (opts.after != null) {
      where.seq = { gt: opts.after };
    }
    const messages = await this.prisma.message.findMany({
      where,
      orderBy: { seq: opts.after != null ? 'asc' : 'desc' },
      take: limit,
      include: {
        sender: { select: { id: true, nickname: true, avatarUrl: true } },
      },
    });
    const ordered =
      opts.after != null ? messages : [...messages].reverse();
    return ordered.map((m: MessageWithSender) => this.toDto(m));
  }

  async send(input: SendMessageInput) {
    await this.rooms.ensureMember(input.roomId, input.senderId);
    const seq = await this.nextSeq(input.roomId);
    const message = await this.prisma.message.create({
      data: {
        roomId: input.roomId,
        senderId: input.senderId,
        type: input.type,
        content: input.content ?? '',
        attachmentUrl: input.attachmentUrl,
        attachmentMeta: input.attachmentMeta as Prisma.InputJsonValue | undefined,
        seq,
      },
      include: {
        sender: { select: { id: true, nickname: true, avatarUrl: true } },
      },
    });
    return this.toDto(message as MessageWithSender);
  }

  private async nextSeq(roomId: string): Promise<number> {
    const agg = await this.prisma.message.aggregate({
      where: { roomId },
      _max: { seq: true },
    });
    return (agg._max.seq ?? 0) + 1;
  }

  toDto(m: MessageWithSender) {
    return {
      id: m.id,
      roomId: m.roomId,
      senderId: m.senderId,
      senderName: m.sender.nickname,
      senderAvatar: m.sender.avatarUrl,
      type: m.type,
      content: m.content,
      attachmentUrl: m.attachmentUrl,
      attachmentMeta: m.attachmentMeta,
      seq: m.seq,
      createdAt: m.createdAt.toISOString(),
    };
  }
}
