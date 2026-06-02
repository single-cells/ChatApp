# 跨平台多人聊天室

Flutter 客户端 + NestJS API。多房间按 `roomId` 进入，支持文字/图片/文件/语音消息与房间内语音连麦。

## 结构

- `apps/mobile` — Flutter
- `services/api` — NestJS + Prisma + Socket.io
- [`DEPLOY.md`](DEPLOY.md) — 服务器部署 + APK 导出
- `docs/DEVELOPMENT_PLAN.md` — 完整方案
- `docs/DEV_WORKFLOW.md` — 边开发边调试（热重载、三终端、VS Code）

## 边开发边调试

详见 **[docs/DEV_WORKFLOW.md](docs/DEV_WORKFLOW.md)**。

**一键测试**（仅 API + Flutter，不启动数据库等容器；需已自行 `docker compose up -d`）：

```powershell
.\start-test.ps1
```

或双击 `start-test.cmd`。Chrome / USB 真机：`.\start-test.ps1 -Device chrome` / `-Device usb`

**Docker 已运行**时，也可手动开两个终端：

```powershell
.\scripts\start-api.ps1      # 终端 1：API
.\scripts\run-flutter.ps1    # 终端 2：Flutter Windows
```

## Windows 单机测试

详见 **[docs/WINDOWS_LOCAL_TEST.md](docs/WINDOWS_LOCAL_TEST.md)**。首次或需拉起容器：

```powershell
.\scripts\start-dev.ps1
```

（需 **Docker Desktop**）

## 清理聊天室数据

```powershell
.\scripts\clear-rooms.ps1
```

或在 `services/api` 下执行 `npm run rooms:clear`（删除全部房间及消息，保留用户账号）。

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
| POST | `/auth/device`（主登录）, `/auth/login`, `/auth/register`（调试） |
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
