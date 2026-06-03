import 'package:flutter/material.dart';

/// One of 12 accent presets (赤→紫 spectrum).
class AppPalette {
  const AppPalette({
    required this.id,
    required this.label,
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
  });

  final String id;
  final String label;
  final Color primary;
  final Color primaryDark;
  final Color primaryLight;

  static const String defaultId = 'violet';

  static const AppPalette defaultPreset = violet;

  static const AppPalette violet = AppPalette(
    id: 'violet',
    label: '紫',
    primary: Color(0xFF6D5DF6),
    primaryDark: Color(0xFF4F46E5),
    primaryLight: Color(0xFF9333EA),
  );

  static const List<AppPalette> presets = [
    AppPalette(
      id: 'red',
      label: '赤',
      primary: Color(0xFFEF4444),
      primaryDark: Color(0xFFDC2626),
      primaryLight: Color(0xFFF87171),
    ),
    AppPalette(
      id: 'rose',
      label: '玫',
      primary: Color(0xFFF43F5E),
      primaryDark: Color(0xFFE11D48),
      primaryLight: Color(0xFFFB7185),
    ),
    AppPalette(
      id: 'orange',
      label: '橙',
      primary: Color(0xFFF97316),
      primaryDark: Color(0xFFEA580C),
      primaryLight: Color(0xFFFB923C),
    ),
    AppPalette(
      id: 'amber',
      label: '琥珀',
      primary: Color(0xFFF59E0B),
      primaryDark: Color(0xFFD97706),
      primaryLight: Color(0xFFFBBF24),
    ),
    AppPalette(
      id: 'yellow',
      label: '黄',
      primary: Color(0xFFEAB308),
      primaryDark: Color(0xFFCA8A04),
      primaryLight: Color(0xFFFACC15),
    ),
    AppPalette(
      id: 'lime',
      label: '柠',
      primary: Color(0xFF84CC16),
      primaryDark: Color(0xFF65A30D),
      primaryLight: Color(0xFFA3E635),
    ),
    AppPalette(
      id: 'green',
      label: '绿',
      primary: Color(0xFF22C55E),
      primaryDark: Color(0xFF16A34A),
      primaryLight: Color(0xFF4ADE80),
    ),
    AppPalette(
      id: 'emerald',
      label: '翠',
      primary: Color(0xFF10B981),
      primaryDark: Color(0xFF059669),
      primaryLight: Color(0xFF34D399),
    ),
    AppPalette(
      id: 'cyan',
      label: '青',
      primary: Color(0xFF06B6D4),
      primaryDark: Color(0xFF0891B2),
      primaryLight: Color(0xFF22D3EE),
    ),
    AppPalette(
      id: 'sky',
      label: '天蓝',
      primary: Color(0xFF0EA5E9),
      primaryDark: Color(0xFF0284C7),
      primaryLight: Color(0xFF38BDF8),
    ),
    AppPalette(
      id: 'blue',
      label: '蓝',
      primary: Color(0xFF3B82F6),
      primaryDark: Color(0xFF2563EB),
      primaryLight: Color(0xFF60A5FA),
    ),
    violet,
  ];

  static AppPalette? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final p in presets) {
      if (p.id == id) return p;
    }
    return null;
  }

  LinearGradient get brandGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primaryDark, primary, primaryLight],
      );

  LinearGradient get subtleGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [subtleGradientTop, const Color(0xFFFAFAFC)],
      );

  Color get subtleGradientTop =>
      Color.alphaBlend(primary.withValues(alpha: 0.1), Colors.white);

  Color get ownedRoomListBackground =>
      Color.alphaBlend(primary.withValues(alpha: 0.12), Colors.white);

  Color get bubbleSelf =>
      Color.alphaBlend(primary.withValues(alpha: 0.28), Colors.white);

  Color get inputFillColor =>
      Color.alphaBlend(primary.withValues(alpha: 0.08), Colors.white);
}
