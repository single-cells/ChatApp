/**
 * Delete all rooms (messages and members cascade). Users are kept.
 * Usage: npm run rooms:clear
 */
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

try {
  const result = await prisma.room.deleteMany();
  console.log(`Deleted ${result.count} room(s) and related messages/members.`);
} finally {
  await prisma.$disconnect();
}
