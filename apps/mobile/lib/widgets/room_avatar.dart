import 'package:flutter/material.dart';
/// Square avatar with room initials (WeChat-style list icon).
class RoomAvatar extends StatelessWidget {
  const RoomAvatar({
    super.key,
    required this.title,
    this.size = 48,
  });

  final String title;
  final double size;

  static Color _colorForTitle(String title) {
    const palette = [
      Color(0xFF4F46E5),
      Color(0xFF6D5DF6),
      Color(0xFF7C3AED),
      Color(0xFF9333EA),
      Color(0xFF6366F1),
    ];
    if (title.isEmpty) return palette[0];
    return palette[title.codeUnitAt(0) % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final label = title.isNotEmpty ? title[0] : '室';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _colorForTitle(title),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

String formatRoomListTime(DateTime? dt) {
  if (dt == null) return '';
  final now = DateTime.now();
  final local = dt.toLocal();
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
  if (local.year == now.year) {
    return '${local.month}/${local.day}';
  }
  return '${local.year}/${local.month}/${local.day}';
}
