import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );
  const corsEnv = process.env.CORS_ORIGIN?.trim();
  const allowAllOrigins = !corsEnv || corsEnv === '*';
  app.enableCors({
    origin: allowAllOrigins
      ? (origin, callback) => callback(null, origin ?? true)
      : corsEnv.split(',').map((o) => o.trim()),
    // 开发环境反射任意来源；credentials 与 * 组合会导致浏览器收不到 ACAO
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
