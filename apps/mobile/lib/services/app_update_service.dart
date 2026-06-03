import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';
import '../models/app_release.dart';

class AppUpdateService {
  AppUpdateService() : _dio = Dio();

  final Dio _dio;

  Future<({int versionCode, String versionName})> localVersion() async {
    final info = await PackageInfo.fromPlatform();
    return (
      versionCode: int.tryParse(info.buildNumber) ?? 0,
      versionName: info.version,
    );
  }

  Future<AppReleaseInfo?> checkForUpdate() async {
    if (!AppConfig.enableAppUpdate) return null;
    if (kIsWeb || !Platform.isAndroid) return null;

    final local = await localVersion();
    final res = await _dio.get<dynamic>(
      AppConfig.updateManifestUrl,
      options: Options(
        responseType: ResponseType.json,
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    final data = res.data;
    if (data is! Map) return null;

    final remote = AppReleaseInfo.fromJson(Map<String, dynamic>.from(data));
    if (remote.versionCode <= local.versionCode) return null;
    return remote;
  }

  Future<void> downloadAndInstall(
    AppReleaseInfo release, {
    void Function(double progress)? onProgress,
  }) async {
    if (!AppConfig.enableAppUpdate) return;
    if (!Platform.isAndroid) return;

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/app-release-${release.versionCode}.apk';

    await _dio.download(
      release.apkUrl,
      path,
      onReceiveProgress: (received, total) {
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      },
    );

    final result = await OpenFilex.open(
      path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw Exception(result.message);
    }
  }
}
