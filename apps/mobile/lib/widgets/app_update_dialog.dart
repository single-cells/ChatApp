import 'package:flutter/material.dart';

import '../models/app_release.dart';
import '../services/app_update_service.dart';
import '../theme/app_theme.dart';

class AppUpdateDialog extends StatefulWidget {
  const AppUpdateDialog({
    super.key,
    required this.release,
    required this.updateService,
  });

  final AppReleaseInfo release;
  final AppUpdateService updateService;

  static Future<void> show(
    BuildContext context, {
    required AppReleaseInfo release,
    required AppUpdateService updateService,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !release.forceUpdate,
      builder: (ctx) => AppUpdateDialog(
        release: release,
        updateService: updateService,
      ),
    );
  }

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  String? _error;

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _error = null;
      _progress = 0;
    });
    try {
      await widget.updateService.downloadAndInstall(
        widget.release,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.release;
    return PopScope(
      canPop: !r.forceUpdate && !_downloading,
      child: AlertDialog(
        title: Text(r.forceUpdate ? '需要更新' : '发现新版本'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('版本 ${r.versionName}'),
            if (r.changelog.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(r.changelog),
            ],
            if (_downloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                color: AppTheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                '${(_progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.subtitleGray,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (!r.forceUpdate && !_downloading)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('稍后'),
            ),
          TextButton(
            onPressed: _downloading ? null : _startDownload,
            child: Text(_downloading ? '下载中…' : '立即更新'),
          ),
        ],
      ),
    );
  }
}
