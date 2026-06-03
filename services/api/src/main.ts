import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const httpAdapter = app.getHttpAdapter();
  if (httpAdapter.getType() === 'express') {
    httpAdapter.getInstance().set('trust proxy', 1);
  }
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );
  const corsEnv = process.env.CORS_ORIGIN?.trim();
  const allowAllOrigins = !corsEnv || corsEnv === '*';
  const allowedOrigins = allowAllOrigins
    ? []
    : corsEnv.split(',').map((o) => o.trim()).filter(Boolean);
  const localDevOrigin = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/;
  app.enableCors({
    origin: allowAllOrigins
      ? (origin, callback) => callback(null, origin ?? true)
      : (origin, callback) => {
          if (!origin || allowedOrigins.includes(origin)) {
            callback(null, origin ?? true);
            return;
          }
          // Flutter Web / 本机工具页调试
          if (localDevOrigin.test(origin)) {
            callback(null, origin);
            return;
          }
          callback(new Error('Not allowed by CORS'));
        },
    credentials: !allowAllOrigins,
  });
  const port = Number(process.env.PORT ?? 3000);
  const host = process.env.HOST?.trim() || '0.0.0.0';
  await app.listen(port, host);
  console.log(`API listening on http://localhost:${port} (bind ${host})`);
  if (host === '0.0.0.0') {
    console.log('局域网设备请用 http://<本机IP>:' + port);
  }
}
bootstrap();
