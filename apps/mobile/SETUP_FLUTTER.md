# Flutter 平台工程

本机未检测到 `flutter` 命令时，请在安装 Flutter SDK 后于本目录执行：

```bash
flutter create . --project-name chat_mobile
```

将生成完整的 `android/`、`ios/`、`windows/` 等平台目录。当前已包含最小 `lib/` 源码与 `pubspec.yaml`。

运行：

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000 --dart-define=WS_URL=http://10.0.2.2:3000
```
