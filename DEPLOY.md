# 部署说明

## Docker 部署（推荐）

除 Flutter 客户端外，PostgreSQL、Redis、MinIO、NestJS API 均在服务器上用 Docker Compose 运行。API 镜像在本地构建，经 `docker save/load` 传到服务器；HTTPS/WSS 由服务器已有 Nginx/Caddy 反代到本机 `127.0.0.1:3000`。

### 1. 本地构建 API 镜像

需已安装 Docker Desktop（或 Docker Engine）。

```powershell
# 仓库根目录
.\scripts\build-image.ps1 -Tag 0.1.0
```

产物：`dist/chat-api-0.1.0.tar.gz`（镜像名 `chat-api:0.1.0`）。

### 2. 上传到服务器

建议服务器目录 `/opt/chat/`：

```powershell
scp dist/chat-api-0.1.0.tar.gz deploy/* user@your-server:~/myapp/ChatApp/
```

### 3. 服务器配置

```bash
cd /opt/chat
cp deploy.env.example deploy/.env   # 编辑生产密钥与 CORS_ORIGIN
chmod 600 .env
# 编辑 .env：更换 POSTGRES_PASSWORD、JWT_*、CLIENT_APP_SECRET、MINIO_*、CORS_ORIGIN
# IMAGE_TAG 与本地构建 tag 一致，例如 0.1.0
nano .env

chmod +x deploy-server.sh
./deploy-server.sh load chat-api-0.1.0.tar.gz
./deploy-server.sh up
curl -sf http://127.0.0.1:3000/health
```

`deploy-server.sh` 子命令：`load`、`pull`、`up`、`down`、`restart-api`、`logs`、`ps`。

**升级 API**：构建新 tar → `load` → 更新 `.env` 中 `IMAGE_TAG` → `./deploy-server.sh restart-api` 或 `up -d api`。

### 4. Nginx 反代与 SSL

Compose 将 API 绑定 **`127.0.0.1:3000`**。Nginx 监听 **80/443** 反代到该地址（含 WebSocket、`client_max_body_size 50m`）。

服务器上已提供 [`deploy/setup-ssl.sh`](deploy/setup-ssl.sh)：

```bash
cd ~/myapp/ChatApp   # 或你的部署目录
chmod +x setup-ssl.sh

# 无自有域名：自签名 HTTPS（临时）
./setup-ssl.sh bootstrap

# 有域名且 DNS A 记录已指向服务器：Let's Encrypt
./setup-ssl.sh letsencrypt api.example.com
```

**Let's Encrypt 前提**：须使用**自有域名**（`nip.io` / `sslip.io` 等动态域名在腾讯云上会被拦截，无法完成验证）。安全组需放行 **80、443**。

证书自动续期：`systemctl enable --now certbot-renew.timer`

配置模板见 [`deploy/nginx/chatapp.conf`](deploy/nginx/chatapp.conf)。`.env` 中 `CORS_ORIGIN` 须与 APK 的 `API_BASE_URL` 一致。

**APK 下载与 OTA**（当前默认**关闭**以节省带宽）：

- 客户端：`ENABLE_APP_UPDATE=false`（`build-apk.ps1` 已写入），不自动检查更新，「我」页无「检查更新」入口；逻辑代码保留。
- 服务器：`/releases/` 返回 **503**（见 [`deploy/nginx/chatapp.production.conf`](deploy/nginx/chatapp.production.conf)）；APK 文件仍可留在 `/var/www/chat-releases/` 供日后启用。
- **重新开放**：Nginx 改回 `alias`（或 `PUBLIC_APK_DOWNLOAD=1 ./setup-ssl.sh bootstrap`），APK 打包加 `--dart-define=ENABLE_APP_UPDATE=true`，再 `publish-apk.ps1`。

开放后浏览器地址：

- `https://<你的主机>/releases/app-release.apk`
- `https://<你的主机>/releases/latest.json`

Flutter APK 的 `API_BASE_URL` / `WS_URL` 使用公网 HTTPS 地址（如 `https://api.example.com`），见下方「客户端导出 APK」。

### 5. 环境变量（[`deploy.env.example`](deploy.env.example) → 复制为 `deploy/.env`，该目录已 gitignore）

| 变量 | 说明 |
|------|------|
| `IMAGE_TAG` | 与本地 `docker build -t chat-api:TAG` 一致 |
| `POSTGRES_*` | 数据库凭证；须与 `DATABASE_URL` 一致 |
| `DATABASE_URL` | 容器内地址：`postgresql://...@postgres:5432/chat` |
| `JWT_SECRET` / `JWT_REFRESH_SECRET` | **必须更换** |
| `CLIENT_APP_SECRET` | **必须更换**；与 APK `dart-define` 一致 |
| `CLIENT_SIGN_SKIP` | 生产 `false` |
| `REDIS_URL` | `redis://redis:6379` |
| `MINIO_*` | 内网 `minio:9000`；`MINIO_ACCESS_KEY`/`SECRET_KEY` 与 `MINIO_ROOT_*` 一致 |
| `CORS_ORIGIN` | 具体域名，勿用 `*` |

**MinIO 媒体 URL**：当前 presigned URL 使用内网 MinIO 主机名；公网直传媒体需在后续迭代增加公网 endpoint 或反代 `/media`。首版可验证聊天与 REST，媒体上传按内网/测试环境验证。

**LiveKit**：未纳入 compose；连麦见 [`docs/RELEASE.md`](docs/RELEASE.md)，单独部署后配置 `LIVEKIT_*`。

### 6. 验收

```bash
# 服务器本机
curl -sf http://127.0.0.1:3000/health
# 公网（需已配置 Nginx/Caddy 反代 80/443 → 127.0.0.1:3000）
curl -sf https://api.example.com/health
```

设备登录请用正式 APK 验证。临时可用 `CLIENT_SIGN_SKIP=true` + [`scripts/test-api.ps1`](scripts/test-api.ps1)。

---

## 服务器部署 API（裸机备选）

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
curl -sf https://api.example.com/health
```

**设备登录**请用正式 Flutter APK 或内测包验证（`curl` 无法完成 Challenge + 设备签名）。临时用脚本测 API 时，可在服务器设 `CLIENT_SIGN_SKIP=true`，再执行 [`scripts/test-api.ps1`](scripts/test-api.ps1)。

完整链路：设备登录 → 创建房间 → WebSocket 收发消息。

---

## 客户端导出 APK

### 0. 版本号（每次发版必做）

编辑 [`apps/mobile/pubspec.yaml`](apps/mobile/pubspec.yaml)，格式为 **`显示版本+构建号`**：

```yaml
version: 0.1.2+3
#        │     └─ 构建号（Android versionCode，每次发版必须递增，用于 OTA 比较）
#        └─ 显示版本（用户可见，如「关于」页、文件名中的 0.1.2）
```

**`+3` 不是「在 2 上加 3」**，而是独立的整数构建号；与前面的 `0.1.2` 用 `+` 连接，是 Flutter/Android 约定写法。发新包时通常只把 `+` 后数字 +1（如 `0.1.2+4`）；若功能大改可同时改显示版本（如 `0.2.0+4`）。

App 启动时会拉取 `/releases/latest.json`，仅当服务器 `versionCode`（即 `+` 后数字）**大于** 本机时才提示更新。

### 1. 配置 API 地址与签名密钥

将 `api.example.com` 换成实际上线域名或公网地址（须与 Nginx/Caddy 反代及 `.env` 中 `CORS_ORIGIN` 一致）。**`CLIENT_APP_SECRET` 必须与服务器 `.env` 中相同**（生产请使用强随机串，勿用示例值）。

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

无独立域名时，可将上述 URL 改为 `http://<你的公网IP>`；配置 HTTPS 后改用 `https://…`。

**自签名 HTTPS**（`./setup-ssl.sh bootstrap`）：浏览器会提示「不安全」或「证书有问题」（自签名，非权威 CA）；**不是真的过期**时，多为用 IP 访问但证书 CN 不匹配。在 `deploy/.env` 中设置 `ALLOW_INSECURE_SSL=true` 后重新执行 `.\scripts\build-apk.ps1`（仅用于内测；正式环境请用 Let's Encrypt 域名证书并保持 `ALLOW_INSECURE_SSL=false`）。

**证书日期 / IP 访问**：在服务器执行（已为 IP 生成 SAN 证书示例）：

```bash
cd ~/myapp/ChatApp
./renew-self-signed-cert.sh 124.220.36.45
```

若仍提示过期，请检查手机/电脑**系统日期**是否正确。要消除浏览器红字警告，需使用自有域名并 `./setup-ssl.sh letsencrypt 你的域名`。

使用脚本打包时，产物在仓库根目录 `deploy_apk/`（以 **FreeChat** 命名）：

- `FreeChat-0.1.2-build3-20260604-012851.apk` — 带时间戳的归档
- `FreeChat-0.1.2-build3.apk` — 当前版本
- `FreeChat.apk` — 始终指向最近一次构建（`publish-apk.ps1` 使用此文件）

Flutter 原始输出仍在 `apps/mobile/build/app/outputs/flutter-apk/app-release.apk`（Gradle 默认名，脚本会复制并重命名）。

### 3. 发布到服务器（构建 + 上传 + Nginx）

在项目根目录（会调用 `build-apk.ps1` 并上传到 SSH 主机 `tencent`）：

```powershell
.\scripts\publish-apk.ps1 -Changelog "修改昵称；检查更新"
```

仅上传已构建的 APK（跳过编译）：

```powershell
.\scripts\publish-apk.ps1 -SkipBuild -Changelog "说明文字"
```

强制更新（用户不可点「稍后」）：

```powershell
.\scripts\publish-apk.ps1 -ForceUpdate
```

### 4. 安装测试

- 真机安装 APK，确认能登录（首次填昵称）、进房、收发消息  
- 「我」→ 检查更新；或浏览器打开 `https://<CORS_ORIGIN 主机>/releases/app-release.apk` 下载  
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
