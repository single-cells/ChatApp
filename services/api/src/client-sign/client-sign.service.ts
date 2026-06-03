import { createHash, createHmac, timingSafeEqual } from 'crypto';
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class ClientSignService {
  constructor(private config: ConfigService) {}

  isSkipped(): boolean {
    return this.config.get('CLIENT_SIGN_SKIP', 'false') === 'true';
  }

  private secret(): string {
    return this.config.get('CLIENT_APP_SECRET', 'dev-client-secret');
  }

  /** Stable digest for device auth (field order independent). */
  deviceAuthBodyDigest(deviceId: string, nickname?: string): string {
    const raw = `${deviceId}|${nickname ?? ''}`;
    return createHash('sha256').update(raw).digest('hex');
  }

  /** Login/auth paths: METHOD\\nPATH\\nchallengeId\\nnonce\\ndeviceId\\nbodySha256 */
  buildAuthCanonical(params: {
    method: string;
    path: string;
    challengeId: string;
    nonce: string;
    deviceId: string;
    bodySha256: string;
  }): string {
    const { method, path, challengeId, nonce, deviceId, bodySha256 } = params;
    return [method.toUpperCase(), path, challengeId, nonce, deviceId, bodySha256].join(
      '\n',
    );
  }

  sign(canonical: string): string {
    return createHmac('sha256', this.secret()).update(canonical).digest('hex');
  }

  verify(canonical: string, signatureHex: string): void {
    const expected = this.sign(canonical);
    const a = Buffer.from(expected, 'hex');
    const b = Buffer.from(signatureHex, 'hex');
    if (a.length !== b.length || !timingSafeEqual(a, b)) {
      throw new UnauthorizedException('Invalid client signature');
    }
  }
}
