# Flutter 平台工程

## Windows 安装（本机已配置示例）

| 项 | 值 |
|----|-----|
| SDK 路径 | `%LOCALAPPDATA%\flutter` |
| PATH | 已加入用户环境变量 `...\flutter\bin` |
| 国内镜像 | `FLUTTER_STORAGE_BASE_URL` / `PUB_HOSTED_URL` → `flutter-io.cn` |
| 源码镜像 | `FLUTTER_GIT_URL` → Gitee `mirrors/Flutter` |

**新开终端或重启 Cursor** 后执行 `flutter --version` 验证。

若 `flutter run` 提示需要 symlink，在 Windows 设置中开启 **开发人员模式**：`ms-settings:developers`。

### 「设备发现」要求 Win10 SDK 1803+

设置里打开 **设备发现** 时，若提示需要 **Windows 10 SDK 版本 1803 或更高**（对应 SDK `10.0.17134`），说明本机缺少完整 SDK 头文件。可任选一种安装方式：

```powershell
winget install Microsoft.WindowsSDK.10.0.17134 --accept-package-agreements
```

或在 **Visual Studio Installer** → 修改 VS 2022 → 单个组件 → 勾选 **Windows 10 SDK (10.0.17134.0)** 或更新的 **10.0.22621.0**。

安装后**重启电脑或至少注销**，再打开 `ms-settings:developers` 重试设备发现。

---

本机未检测到 `flutter` 命令时，请先安装 [Flutter SDK](https://docs.flutter.dev/get-started/install/windows)，再在项目根目录执行：

```powershell
.\scripts\flutter-setup-platforms.ps1
```

将生成 `android/`、`windows/`、`web/` 等平台目录。当前已包含 `lib/` 源码与 `pubspec.yaml`。

日常开发（热重载、各平台 API 地址）见 **[docs/DEV_WORKFLOW.md](../../docs/DEV_WORKFLOW.md)**。

Android 模拟器：

```powershell
flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:3000 --dart-define=WS_URL=http://10.0.2.2:3000
```

Android **USB 真机**（需先装 Android Studio / SDK，`flutter doctor` 通过 Android 项）：

```powershell
# 项目根目录
.\scripts\start-api.ps1    # 终端 1
.\scripts\run-flutter-usb.ps1   # 终端 2
```

手机打开 USB 调试；若 `flutter devices` 仍无手机，执行 `flutter config --android-sdk %LOCALAPPDATA%\Android\Sdk` 后重开终端。
