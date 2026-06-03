import { createPublicKey, verify } from 'crypto';
import {
  BadRequestException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

/** DER prefix for Ed25519 SPKI (32-byte raw key follows). */
const ED25519_SPKI_PREFIX = Buffer.from('302a300506032b6570032100', 'hex');

@Injectable()
export class DeviceCredentialService {
  constructor(private prisma: PrismaService) {}

  signPayload(challengeId: string, nonce: string, deviceId: string): string {
    return `${challengeId}|${nonce}|${deviceId}`;
  }

  verifyEd25519Raw(
    publicKeyB64: string,
    message: string,
    signatureB64: string,
  ): void {
    const publicKeyRaw = Buffer.from(publicKeyB64, 'base64');
    if (publicKeyRaw.length !== 32) {
      throw new BadRequestException('Invalid public key length');
    }
    const signature = Buffer.from(signatureB64, 'base64');
    const key = createPublicKey({
      key: Buffer.concat([ED25519_SPKI_PREFIX, publicKeyRaw]),
      format: 'der',
      type: 'spki',
    });
    const valid = verify(
      null,
      Buffer.from(message, 'utf8'),
      key,
      signature,
    );
    if (!valid) {
      throw new UnauthorizedException('Invalid device signature');
    }
  }

  async verifyOrRegister(params: {
    deviceId: string;
    publicKey?: string;
    deviceSignature: string;
    challengeId: string;
    nonce: string;
  }): Promise<void> {
    const message = this.signPayload(
      params.challengeId,
      params.nonce,
      params.deviceId,
    );
    const existing = await this.prisma.deviceCredential.findUnique({
      where: { deviceId: params.deviceId },
    });

    if (existing) {
      if (params.publicKey && params.publicKey !== existing.publicKey) {
        throw new UnauthorizedException('Device public key mismatch');
      }
      this.verifyEd25519Raw(existing.publicKey, message, params.deviceSignature);
      await this.prisma.deviceCredential.update({
        where: { deviceId: params.deviceId },
        data: { lastUsedAt: new Date() },
      });
      return;
    }

    if (!params.publicKey) {
      throw new BadRequestException('publicKey required for new device');
    }
    this.verifyEd25519Raw(params.publicKey, message, params.deviceSignature);
    await this.prisma.deviceCredential.create({
      data: {
        deviceId: params.deviceId,
        publicKey: params.publicKey,
      },
    });
  }
}
