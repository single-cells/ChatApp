import { Injectable, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  CreateBucketCommand,
  HeadBucketCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { v4 as uuid } from 'uuid';

const ALLOWED_MIME: Record<string, string[]> = {
  image: ['image/jpeg', 'image/png', 'image/gif', 'image/webp'],
  file: [
    'application/pdf',
    'text/plain',
    'application/zip',
    'application/octet-stream',
  ],
  voice: ['audio/m4a', 'audio/aac', 'audio/mpeg', 'audio/mp4', 'audio/wav'],
};

@Injectable()
export class StorageService implements OnModuleInit {
  private client: S3Client;
  private bucket: string;

  constructor(private config: ConfigService) {
    const endpoint = config.get('MINIO_ENDPOINT', 'localhost');
    const port = config.get('MINIO_PORT', '9000');
    const useSsl = config.get('MINIO_USE_SSL', 'false') === 'true';
    this.bucket = config.get('MINIO_BUCKET', 'chat-media');
    this.client = new S3Client({
      region: 'us-east-1',
      endpoint: `${useSsl ? 'https' : 'http'}://${endpoint}:${port}`,
      forcePathStyle: true,
      credentials: {
        accessKeyId: config.get('MINIO_ACCESS_KEY', 'minio'),
        secretAccessKey: config.get('MINIO_SECRET_KEY', 'minio123'),
      },
    });
  }

  async onModuleInit() {
    try {
      await this.client.send(new HeadBucketCommand({ Bucket: this.bucket }));
    } catch {
      try {
        await this.client.send(
          new CreateBucketCommand({ Bucket: this.bucket }),
        );
      } catch {
        // MinIO may not be running in dev
      }
    }
  }

  async presign(
    roomId: string,
    userId: string,
    kind: 'image' | 'file' | 'voice',
    mime: string,
    filename?: string,
  ) {
    const allowed = ALLOWED_MIME[kind];
    if (!allowed?.includes(mime)) {
      throw new Error(`MIME type not allowed: ${mime}`);
    }
    const ext = filename?.split('.').pop() ?? mime.split('/')[1] ?? 'bin';
    const key = `rooms/${roomId}/${userId}/${uuid()}.${ext}`;
    const command = new PutObjectCommand({
      Bucket: this.bucket,
      Key: key,
      ContentType: mime,
    });
    const uploadUrl = await getSignedUrl(this.client, command, {
      expiresIn: 900,
    });
    const publicBase = this.config.get(
      'MINIO_PUBLIC_URL',
      `http://${this.config.get('MINIO_ENDPOINT', 'localhost')}:${this.config.get('MINIO_PORT', '9000')}`,
    );
    const attachmentUrl = `${publicBase}/${this.bucket}/${key}`;
    return { uploadUrl, attachmentUrl, key };
  }
}
