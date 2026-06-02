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
| `JWT_SECRET` | **必须更换** |
| `REDIS_URL` | Redis 地址 |
| `MINIO_*` | 对象存储 |
| `HOST` | `0.0.0.0` |
| `PORT` | `3000` |
| `CORS_ORIGIN` | 前端域名，勿用 `*` |

对外提供 **HTTPS / WSS**（Nginx/Caddy 反代到本机 `:3000`）。

### 3. 构建与启动

```bash
cd services/api
npm ci
npx prisma generate
npx prisma migrate deploy
npm run build
node dist/main.js
```

建议用 **pm2**、**systemd** 或 Docker 守护进程，保证崩溃自动重启。

### 4. 验收

```bash
curl https://api.example.com/health
```

再测：`POST /auth/device`（设备登录）→ 创建房间 → WebSocket 消息。

---

## 客户端导出 APK

### 1. 配置 API 地址

将 `api.example.com` 换成实际上线域名（须与服务器 HTTPS 一致）：

```bash
cd apps/mobile
flutter pub get
```

### 2. 打包

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.example.com \
  --dart-define=WS_URL=https://api.example.com
```

产物路径：

`apps/mobile/build/app/outputs/flutter-apk/app-release.apk`

### 3. 安装测试

- 真机安装 APK，确认能登录（首次填昵称）、进房、收发消息  
- 上架前：图标、权限说明（麦克风等）见 [`docs/RELEASE.md`](docs/RELEASE.md)
