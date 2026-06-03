# 部署说明

## 服务器部署 API

### 1. 准备

- 安装 Node.js 20+、PostgreSQL、Redis、MinIO（或 S3 兼容存储）
- 可选：LiveKit（连麦，见 [`docs/RELEASE.md`](docs/RELEASE.md)）

### 2. 配置

在服务器 `services/api` 目录创建 `.env`（参考 [`.env.example`](.env.example)）：

| 变量 | 说明 |
|------|------|
| `DATABASE_URL` | 生产数据库连接串 |
| `JWT_SECRET` | Access Token 签名密钥，**必须更换** |
| `JWT_REFRESH_SECRET` | Refresh Token 签名密钥，**必须更换**（与 `JWT_SECRET` 不同） |
| `JWT_EXPIRES_IN` | Access 有效期，默认 `15m` |
| `JWT_REFRESH_EXPIRES_IN` | Refresh 有效期，默认 `7d` |
| `CLIENT_APP_SECRET` | 客户端请求 HMAC 密钥，**必须更换**；须与 APK 内 `CLIENT_APP_SECRET` 一致 |
| `CLIENT_SIGN_SKIP` | 生产设为 `false`；仅本地调试可 `true`（跳过签名校验） |
| `REDIS_URL` | Redis 地址（Challenge nonce、Refresh `jti`、限流） |
| `MINIO_*` | 对象存储 |
| `HOST` | `0.0.0.0` |
| `PORT` | `3000` |
| `CORS_ORIGIN` | 前端域名，勿用 `*` |

对外提供 **HTTPS / WSS**（Nginx/Caddy 反代到本机 `:3000`）。

**客户端流量校验（无应用商店依赖）**

- `POST /auth/device` 需先 `GET /auth/challenge`，再带 HMAC 头（`X-Client-Challenge-Id`、`X-Client-Nonce`、`X-Client-Signature`）与设备 Ed25519 签名（`deviceSignature` / `publicKey`）。
- 已登录请求须带 `Authorization: Bearer <access>` 与 **`X-Device-Id`**（须与 JWT 内 `deviceId` 一致）。
- WebSocket 握手：`auth.token` + `auth.deviceId`（与 JWT 一致）。

### 3. 构建与启动

```bash
cd services/api
npm ci
npx prisma generate
npx prisma migrate deploy   # 或首次：npx prisma db push
npm run build
node dist/main.js
```

首次上线若尚无迁移目录，可用 `npx prisma db push` 同步表结构（含 `DeviceCredential`）。

建议用 **pm2**、**systemd** 或 Docker 守护进程，保证崩溃自动重启。

### 4. 验收

```bash
curl https://api.example.com/health
```

**设备登录**请用正式 Flutter APK 或内测包验证（`curl` 无法完成 Challenge + 设备签名）。临时用脚本测 API 时，可在服务器设 `CLIENT_SIGN_SKIP=true`，再执行 [`scripts/test-api.ps1`](scripts/test-api.ps1)。

完整链路：设备登录 → 创建房间 → WebSocket 收发消息。

---

## 客户端导出 APK

### 1. 配置 API 地址与签名密钥

将 `api.example.com` 换成实际上线域名（须与服务器 HTTPS 一致）。**`CLIENT_APP_SECRET` 必须与服务器 `.env` 中相同**（生产请使用强随机串，勿用示例值）。

```bash
cd apps/mobile
flutter pub get
```

### 2. 打包

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.example.com \
  --dart-define=WS_URL=https://api.example.com \
  --dart-define=CLIENT_APP_SECRET=你的生产密钥
```

产物路径：

`apps/mobile/build/app/outputs/flutter-apk/app-release.apk`

### 3. 安装测试

- 真机安装 APK，确认能登录（首次填昵称）、进房、收发消息  
- 若登录报 401/403：检查服务器 `CLIENT_SIGN_SKIP=false`、`CLIENT_APP_SECRET` 与 APK 内 dart-define 是否一致，Redis 是否可达  
- 上架前：图标、权限说明（麦克风等）见 [`docs/RELEASE.md`](docs/RELEASE.md)

---

## 生产检查清单

| 项 | 要求 |
|----|------|
| `JWT_SECRET` / `JWT_REFRESH_SECRET` | 已更换为强随机值 |
| `CLIENT_APP_SECRET` | 已更换；服务端与 APK dart-define 一致 |
| `CLIENT_SIGN_SKIP` | `false` |
| `CORS_ORIGIN` | 具体域名，非 `*` |
| HTTPS / WSS | 反代已配置 |
| PostgreSQL + Redis | 可连且已迁移 schema |
