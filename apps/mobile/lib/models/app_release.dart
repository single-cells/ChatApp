class AppReleaseInfo {
  const AppReleaseInfo({
    required this.versionName,
    required this.versionCode,
    required this.apkUrl,
    required this.changelog,
    required this.forceUpdate,
  });

  final String versionName;
  final int versionCode;
  final String apkUrl;
  final String changelog;
  final bool forceUpdate;

  factory AppReleaseInfo.fromJson(Map<String, dynamic> json) {
    return AppReleaseInfo(
      versionName: json['versionName'] as String? ?? '',
      versionCode: (json['versionCode'] as num).toInt(),
      apkUrl: json['apkUrl'] as String,
      changelog: json['changelog'] as String? ?? '',
      forceUpdate: json['forceUpdate'] as bool? ?? false,
    );
  }
}
