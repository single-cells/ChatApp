import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Prompt for room password before join.
Future<String?> showRoomPasswordDialog(
  BuildContext context, {
  String title = '输入房间密码',
  String? errorText,
}) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '房间密码',
            errorText: errorText,
          ),
          onSubmitted: (_) {
            final v = ctrl.text.trim();
            if (v.isNotEmpty) Navigator.pop(ctx, v);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isEmpty) {
                setLocal(() {});
                return;
              }
              Navigator.pop(ctx, v);
            },
            child: Text('确定', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    ),
  );
}

/// Creator sets or changes room password (empty = remove password).
Future<String?> showRoomPasswordManageDialog(
  BuildContext context, {
  required bool hasPassword,
}) {
  final ctrl = TextEditingController();
  return showDialog<String?>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(hasPassword ? '修改房间密码' : '设置房间密码'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: ctrl,
            obscureText: true,
            decoration: InputDecoration(
              hintText: hasPassword ? '新密码（留空则取消密码）' : '新密码',
            ),
          ),
          if (hasPassword) ...[
            const SizedBox(height: 12),
            const Text(
              '留空并确认将取消房间密码，已在房间的用户不受影响。',
              style: TextStyle(fontSize: 12, color: AppTheme.subtitleGray),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text),
          child: Text('保存', style: TextStyle(color: AppTheme.primary)),
        ),
      ],
    ),
  );
}
