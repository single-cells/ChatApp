# 跨平台多人聊天室

Flutter 客户端 + NestJS API。多房间按 `roomId` 进入，支持文字/图片/文件/语音消息与房间内语音连麦。

## 结构

- `apps/mobile` — Flutter
- `services/api` — NestJS + Prisma + Socket.io
- `docs/DEVELOPMENT_PLAN.md` — 完整方案

## Windows 单机测试

详见 **[docs/WINDOWS_LOCAL_TEST.md](docs/WINDOWS_LOCAL_TEST.md)**，或运行：

```powershell
.\scripts\start-dev.ps1
```

（需先启动 **Docker Desktop**）

## 快速开始

### 1. 基础设施

```bash
docker compose up -d
```

### 2. API

```bash
cd services/api
cp ../.env.example .env   # 或已含 services/api/.env
npm install
npx prisma db push
npm run start:dev
```

API: http://localhost:3000/health

### 3. Flutter

```bash
cd apps/mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:3000 --dart-define=WS_URL=http://localhost:3000
```

> Android 模拟器请用 `http://10.0.2.2:3000` 替代 localhost。

## 主要 API

| 方法 | 路径 |
|------|------|
| POST | `/auth/register`, `/auth/login` |
| POST | `/rooms` |
| GET | `/rooms/:roomId`, `/rooms/recent` |
| POST | `/rooms/:roomId/join` |
| GET | `/rooms/:roomId/messages` |
| POST | `/rooms/:roomId/uploads/presign` |
| POST | `/rooms/:roomId/voice/token` |

WebSocket（Socket.io）：`room.join`, `message.send`, `message.new`, `call.join`, `call.leave`, `call.state`

## 无 Flutter 时测试客户端

后端已启动后，在浏览器用 Web 测试页（登录、进房、发消息）：

```powershell
cd F:\_app
.\scripts\run-web-client.ps1
```

打开 http://localhost:8080 ，API 地址填 `http://localhost:3000`（手机访问填 `http://电脑IP:3000`）。
