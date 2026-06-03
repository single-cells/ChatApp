import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Request } from 'express';
import { ClientSignChallengeService } from './client-sign-challenge.service';
import { ClientSignService } from './client-sign.service';
import { DeviceCredentialService } from './device-credential.service';

@Injectable()
export class ClientSignGuard implements CanActivate {
  constructor(
    private clientSign: ClientSignService,
    private challenge: ClientSignChallengeService,
    private deviceCredential: DeviceCredentialService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    if (this.clientSign.isSkipped()) {
      return true;
    }

    const req = context.switchToHttp().getRequest<Request>();
    const challengeId = req.header('x-client-challenge-id');
    const nonce = req.header('x-client-nonce');
    const signature = req.header('x-client-signature');

    if (!challengeId || !nonce || !signature) {
      throw new UnauthorizedException('Missing client signature headers');
    }

    const body = req.body as Record<string, unknown> | undefined;
    const deviceId =
      typeof body?.deviceId === 'string' ? body.deviceId.trim() : '';
    if (!deviceId) {
      throw new UnauthorizedException('deviceId required');
    }

    const challengeIdBody =
      typeof body?.challengeId === 'string' ? body.challengeId : challengeId;
    const deviceSignature =
      typeof body?.deviceSignature === 'string' ? body.deviceSignature : '';
    if (!deviceSignature) {
      throw new UnauthorizedException('deviceSignature required');
    }

    const publicKey =
      typeof body?.publicKey === 'string' ? body.publicKey : undefined;
    const nickname =
      typeof body?.nickname === 'string' ? body.nickname.trim() : undefined;

    await this.challenge.consume(challengeIdBody, nonce);

    const canonical = this.clientSign.buildAuthCanonical({
      method: req.method,
      path: req.path,
      challengeId: challengeIdBody,
      nonce,
      deviceId,
      bodySha256: this.clientSign.deviceAuthBodyDigest(deviceId, nickname),
    });
    this.clientSign.verify(canonical, signature);

    await this.deviceCredential.verifyOrRegister({
      deviceId,
      publicKey,
      deviceSignature,
      challengeId: challengeIdBody,
      nonce,
    });

    return true;
  }
}
