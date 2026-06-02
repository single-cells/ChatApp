# Windows 单机测试指南

## 前置条件

| 软件 | 用途 | 检查命令 |
|------|------|----------|
| **Docker Desktop** | Postgres、Redis、MinIO | `docker info` |
| **Node.js 20+** | NestJS API | `node -v` |
| **Flutter SDK**（可选） | 手机/模拟器客户端 | `flutter -v` |

## 方式一：一键脚本（推荐）

1. 打开 **Docker Desktop**，等待左下角显示 Running。
2. PowerShell 在项目根目录执行：

```powershell
cd F:\_app
.\scripts\start-dev.ps1
```

脚本会：`docker compose up` → `prisma db push` → `npm run start:dev`。

3. 浏览器验证 API：

```
http://localhost:3000/health
```

应返回 `{"status":"ok",...}`。

## 方式二：手动分步

### 1. 基础设施

```powershell
cd F:\_app
docker compose up -d
```

### 2. API

```powershell
cd F:\_app\services\api
npm install
npx prisma db push
npm run start:dev
```

环境变量已写在 `services/api/.env`（连本机 `localhost`）。

### 3. 用 curl 测注册/建房（无 Flutter 时）

```powershell
# 注册
$reg = Invoke-RestMethod -Method Post -Uri http://localhost:3000/auth/register `
  -ContentType "application/json" `
  -Body '{"email":"test@local.dev","password":"123456","nickname":"测试"}'

$token = $reg.accessToken

# 创建房间
$room = Invoke-RestMethod -Method Post -Uri http://localhost:3000/rooms `
  -Headers @{ Authorization = "Bearer $token" } `
  -ContentType "application/json" `
  -Body '{"title":"我的房间"}'

$room.roomId
```

记下 `roomId`，后续 Flutter 或 Socket.io 客户端进房使用。

### 4. Flutter（本机已装 Flutter）

```powershell
cd F:\_app\apps\mobile
flutter create . --project-name chat_mobile
flutter pub get
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:3000 --dart-define=WS_URL=http://localhost:3000
```

- **Android 模拟器**：`API_BASE_URL` / `WS_URL` 改为 `http://10.0.2.2:3000`
- **真机（同 WiFi）**：改为电脑局域网 IP，如 `http://192.168.1.100:3000`

## 手机浏览器（Web 测试页）

1. 本机已运行 `.\scripts\start-dev.ps1`（API 监听 `0.0.0.0:3000`）。
2. 另开终端：`.\scripts\run-web-client.ps1`。
3. 手机与电脑同一 WiFi，浏览器打开脚本输出的 `http://<电脑IP>:8080`。
4. 页面会自动把 API 填为 `http://<电脑IP>:3000`，点「检查 /health」。

若仍显示 **Failed to fetch**：

- 不要用 `localhost`（在手机上指向手机自己）。
- Windows 防火墙：允许 Node.js 专用网络，或临时放行入站 TCP **3000**、**8080**。
- 确认手机能 ping 通电脑 IP。

## 连麦（可选）

本地未配置 LiveKit 时，**文字/图片/文件/语音消息**仍可用；点连麦会失败，属正常。需要时再部署 LiveKit 并改 `.env` 中 `LIVEKIT_*`。

## Docker 镜像拉取失败（504 / mirror.iscas.ac.cn）

若 `docker compose up` 报 **504 Gateway Time-out** 且 URL 含 `mirror.iscas.ac.cn`：

1. 打开 **Docker Desktop** → **Settings** → **Docker Engine**
2. 删除或注释 `registry-mirrors` 中的失效镜像，Apply & Restart
3. 重新执行：`docker compose pull` 再 `docker compose up -d`

或换网络/时段后重试 `docker compose pull`。

## 常见问题

| 现象 | 处理 |
|------|------|
| `docker ... pipe/dockerDesktopLinuxEngine` | 打开 Docker Desktop |
| API 连不上数据库 | 确认 `DATABASE_URL` 端口为 **5433**（本机 5432 常被占用）；`docker compose ps` |
| `prisma db push` 失败 | 等 Postgres 启动 10 秒后再试 |
| MinIO 上传失败 | 确认 `docker compose` 中 minio 已启动 |
| 端口 3000 占用 | 修改 `services/api/.env` 中 `PORT` |

## MinIO 控制台（可选）

浏览器打开 http://localhost:9001 ，账号 `minio` / 密码 `minio123`。
