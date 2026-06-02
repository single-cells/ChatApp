# 边开发边调试（Web 式工作流）

前后端并行：后端保存自动重启，客户端热重载或浏览器刷新。更细的 Windows 排错见 [WINDOWS_LOCAL_TEST.md](WINDOWS_LOCAL_TEST.md)。

## 清理全部聊天室

```powershell
.\scripts\clear-rooms.ps1
```

仅删 `Room` / `Message` / `RoomMember`，不删用户。也可在 API 环境变量 `ALLOW_ROOM_PURGE=true` 时调用 `DELETE /rooms/purge-all`（需 JWT）。

## 房间操作（App）

- **创建者**：聊天页右上角菜单 → 删除聊天室
- **参与者**：退出聊天室（创建者需删除，不能退出）

## 一键启动（推荐）

在仓库根目录：

```powershell
.\start-test.ps1              # Windows 桌面 Flutter + API 新窗口
.\start-test.ps1 -Device chrome
.\start-test.ps1 -Device usb   # USB 真机（adb reverse）
```

或双击 `start-test.cmd`。脚本**不会**启动 Docker/数据库，只开 API 新窗口并等待 `/health` 后在本终端 `flutter run`（基础设施需已 `docker compose up -d`）。

## 日常流程（Docker 已部署时，两个终端）

| 终端 | 作用 | 命令 |
|------|------|------|
| 1 | API（watch，改代码自动重启） | `.\scripts\start-api.ps1` |
| 2 | Flutter（热重载 `r`） | `.\scripts\run-flutter.ps1` |

验证 API：http://localhost:3000/health → `{"status":"ok",...}`。

Chrome 代替 Windows 桌面：`.\scripts\run-flutter.ps1 -Device chrome`

可选第三终端：Web 测试页 `.\scripts\run-web-client.ps1`（不必开 Flutter 时测 Socket）。

### 首次或 Docker 未起

| 场景 | 命令 |
|------|------|
| 一键：Docker + 数据库 + API | `.\scripts\start-dev.ps1` |
| 仅拉起容器 | `docker compose up -d` |

## 其他终端（可选）

| 终端 | 作用 | 命令 |
|------|------|------|
| Web 测试页 | 浏览器测 REST / Socket（F5 刷新） | `.\scripts\run-web-client.ps1` |
| VS Code | 断点调试 | **Full stack (Nest + Flutter)** 或单独 Nest / Flutter |

## API / WebSocket 地址对照表

Flutter 通过 `--dart-define` 注入（编译期常量，**改 URL 后需重新 `flutter run`**）。Web 测试页在页面输入框填写，手机访问勿用 `localhost`。

| 运行环境 | `API_BASE_URL` / `WS_URL` |
|----------|---------------------------|
| Windows 本机 / Flutter Windows / Chrome Web | `http://localhost:3000` |
| Android 模拟器 | `http://10.0.2.2:3000` |
| 真机或手机浏览器（同 WiFi） | `http://<电脑局域网IP>:3000` |

Web 测试页默认会根据当前访问的 host 推断 API 地址（见 `tools/web-client/index.html`）。

## 后端热重载

```powershell
cd F:\_app\services\api
npm run start:dev      # 无断点
npm run start:debug    # 开启 Node inspector（9229），供编辑器 attach
```

修改 `services/api/src/**/*.ts` 保存后，终端会自动重编译并重启进程。

## Web 测试客户端

```powershell
cd F:\_app
.\scripts\run-web-client.ps1
```

- 本机：http://localhost:8080
- 改 `tools/web-client/index.html` → 浏览器 **F5**
- Chrome DevTools → Network / WS 查看请求与 `message.new`

适合快速验证房间、消息、Socket 事件，无需 Flutter 编译。

## Flutter 运行

### Android SDK（真机 / 模拟器）

| 步骤 | 命令 / 操作 |
|------|-------------|
| 安装 Android Studio | `winget install -e --id Google.AndroidStudio`（已完成可跳过） |
| 安装 SDK 组件 | `.\scripts\setup-android-sdk.ps1`（需联网，使用 Studio 自带 JBR） |
| 接受许可 | 脚本结束后执行：`("y`n" * 50) \| flutter doctor --android-licenses` |
| 验证 | `flutter doctor`，Android toolchain 应为 √ |

USB 真机：`.\scripts\run-flutter-usb.ps1`（见上文 **Android 真机（USB）**）。

### 首次：补全平台工程

仓库若仅有 `android/`，需一次性生成 Windows / Web 等目录：

```powershell
cd F:\_app
.\scripts\flutter-setup-platforms.ps1
```

或手动：

```powershell
cd F:\_app\apps\mobile
flutter create . --project-name chat_mobile
flutter pub get
```

### Windows 桌面（推荐本机 UI 调试）

```powershell
cd F:\_app\apps\mobile
flutter run -d windows `
  --dart-define=API_BASE_URL=http://localhost:3000 `
  --dart-define=WS_URL=http://localhost:3000
```

### Chrome（Web 目标，UI 调试方便）

```powershell
flutter run -d chrome `
  --dart-define=API_BASE_URL=http://localhost:3000 `
  --dart-define=WS_URL=http://localhost:3000
```

> Web 上 `record`、`livekit_client` 等能力可能受限；录音、连麦等请以 Windows / Android 为准。

### Android 模拟器

```powershell
flutter run -d android `
  --dart-define=API_BASE_URL=http://10.0.2.2:3000 `
  --dart-define=WS_URL=http://10.0.2.2:3000
```

### Android 真机（USB）

1. 终端 1：`.\scripts\start-api.ps1`（或 `start-dev.ps1`）
2. 手机：**开发者选项 → USB 调试**，数据线连接电脑并点「允许」
3. 本机需 **Android SDK / adb**（`flutter doctor` 里 Android toolchain 为 √）
4. 终端 2：

```powershell
.\scripts\run-flutter-usb.ps1
```

脚本会执行 `adb reverse tcp:3000 tcp:3000`，App 使用 `http://127.0.0.1:3000` 访问电脑 API（无需填局域网 IP）。

指定设备 ID：`.\scripts\run-flutter-usb.ps1 -DeviceId R5CRxxxx`

**不用 USB、只用 WiFi** 时，把 IP 换成 `ipconfig` 里的 IPv4：

```powershell
cd apps\mobile
flutter run -d <设备ID> `
  --dart-define=API_BASE_URL=http://192.168.x.x:3000 `
  --dart-define=WS_URL=http://192.168.x.x:3000
```

### 热重载快捷键（`flutter run` 运行时）

| 按键 | 效果 |
|------|------|
| `r` | Hot reload：UI、大部分 Dart |
| `R` | Hot restart：`main()`、全局初始化、部分 provider |
| `q` | 退出 |

DevTools：终端会打印链接，或执行 `dart devtools`。

## VS Code / Cursor 一键调试

需安装扩展：**Dart**、**Flutter**。

1. **Run and Debug** 面板选择 **Full stack (Nest + Flutter)**  
   - 先执行任务：Docker Compose + `prisma db push`  
   - 并行启动 Nest（`start:debug`）与 Flutter Windows  
2. 仅调 API：**NestJS: Debug (watch)**  
3. 仅调 Flutter：**Flutter: Windows** 或 **Flutter: Chrome**

Nest 断点打在 `services/api/src`；Flutter 断点打在 `apps/mobile/lib`。

## 前后端联调分工

1. **改 API / Prisma / Socket** → 保存 → 看 API 终端重启 → Web 页或 Flutter 复现  
2. **改 Flutter UI** → 保存 → `r`；连不上先查 `/health` 与上表 URL  
3. **改 Web 测试页** → F5；与 Flutter 可同时进同一 `roomId` 互发消息  

本地未配 LiveKit 时连麦失败属正常；文字/图片/文件/语音消息不依赖 LiveKit。

## 与纯 Web 项目的差异

| Web 习惯 | 本项目 |
|----------|--------|
| 单条 `npm run dev` | Docker + API 一条线；客户端另开终端或 VS Code compound |
| 改 `.env` 刷新 | Flutter 用 `--dart-define`，改后需重跑 `flutter run` |
| 浏览器断点 | Web 测试页用 Chrome；Flutter 用 DevTools / 编辑器 |

## 验收清单

- [ ] `.\scripts\start-dev.ps1` 后 `/health` 正常  
- [ ] `.\scripts\run-web-client.ps1` 能登录、建房、发消息  
- [ ] 改 API 源码保存后自动重启，Web 页无需重启即可再请求  
- [ ] `flutter run` 后改 `lib/screens/*.dart`，`r` 界面即时更新  
- [ ] Web 测试页与 Flutter 同一房间可互相收到消息  
