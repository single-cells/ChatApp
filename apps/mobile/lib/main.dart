import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_shell.dart';
import 'config/app_config.dart';
import 'config/insecure_ssl_overrides.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(AppTheme.systemUiOverlay);
  applyInsecureSslIfConfigured(AppConfig.allowInsecureSsl);
  runApp(const ProviderScope(child: AppShell()));
}
