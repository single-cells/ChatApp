import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateUserDto } from './dto/update-user.dto';

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  async updateMe(userId: string, dto: UpdateUserDto) {
    return this.prisma.user.update({
      where: { id: userId },
      data: {
        nickname: dto.nickname,
        avatarUrl: dto.avatarUrl,
      },
      select: {
        id: true,
        email: true,
        nickname: true,
        avatarUrl: true,
      },
    });
  }
}
