import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// WeChat-like layout with premium blue–violet gradient accents.
abstract final class AppTheme {
  static const Color primary = Color(0xFF6D5DF6);
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFF9333EA);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primary, primaryLight],
  );

  static const LinearGradient subtleGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF5F3FF), Color(0xFFFAFAFC)],
  );

  static const Color chatBackground = Color(0xFFF3F4F8);
  static const Color listBackground = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE8E8ED);
  static const Color subtitleGray = Color(0xFF9CA3AF);
  static const Color titleBlack = Color(0xFF1F2937);
  static const Color bubbleSelf = Color(0xFFD4D0FF);
  static const Color bubbleOther = Color(0xFFFFFFFF);
  static const Color navBar = Color(0xFFF9FAFB);
  static const Color tabInactive = Color(0xFF9CA3AF);

  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: primary,
      onPrimary: Colors.white,
      surface: listBackground,
      onSurface: titleBlack,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: listBackground,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: navBar,
        foregroundColor: titleBlack,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: titleBlack,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      dividerTheme: const DividerThemeData(color: divider, thickness: 0.5),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 12,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F3FF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: primary, width: 1),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        hintStyle: const TextStyle(color: subtitleGray, fontSize: 15),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: navBar,
        selectedItemColor: primary,
        unselectedItemColor: tabInactive,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}

/// Gradient primary button (login, etc.).
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.height = 48,
    this.enabled = true,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final double height;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = enabled && onPressed != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: active
            ? AppTheme.brandGradient
            : LinearGradient(
                colors: [
                  AppTheme.subtitleGray.withValues(alpha: 0.5),
                  AppTheme.subtitleGray.withValues(alpha: 0.4),
                ],
              ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: active
            ? [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: active ? onPressed : null,
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
