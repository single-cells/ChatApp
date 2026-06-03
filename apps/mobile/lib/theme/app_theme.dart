import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_palette.dart';

/// WeChat-like layout with user-selectable accent palette.
abstract final class AppTheme {
  static AppPalette _palette = AppPalette.defaultPreset;

  static void applyPalette(AppPalette palette) => _palette = palette;

  static Color get primary => _palette.primary;
  static Color get primaryDark => _palette.primaryDark;
  static Color get primaryLight => _palette.primaryLight;

  static LinearGradient get brandGradient => _palette.brandGradient;
  static LinearGradient get subtleGradient => _palette.subtleGradient;

  static const Color chatBackground = Color(0xFFF3F4F8);
  static const Color listBackground = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE8E8ED);
  static const Color subtitleGray = Color(0xFF9CA3AF);
  static const Color titleBlack = Color(0xFF1F2937);
  static Color get bubbleSelf => _palette.bubbleSelf;
  static const Color bubbleOther = Color(0xFFFFFFFF);
  static const Color navBar = Color(0xFFF9FAFB);
  static const Color tabInactive = Color(0xFF9CA3AF);

  static Color get ownedRoomListBackground => _palette.ownedRoomListBackground;
  static Color get statusBarGradientTop => _palette.subtleGradientTop;

  static SystemUiOverlayStyle overlayFor(Color statusBarColor) {
    return SystemUiOverlayStyle(
      statusBarColor: statusBarColor,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: navBar,
      systemNavigationBarIconBrightness: Brightness.dark,
    );
  }

  static SystemUiOverlayStyle get systemUiOverlay => overlayFor(navBar);

  static ThemeData light() {
    final scheme = ColorScheme.light(
      primary: primary,
      onPrimary: Colors.white,
      surface: listBackground,
      onSurface: titleBlack,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: listBackground,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: navBar,
        foregroundColor: titleBlack,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          color: titleBlack,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        systemOverlayStyle: systemUiOverlay,
      ),
      dividerTheme: const DividerThemeData(color: divider, thickness: 0.5),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 12,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _palette.inputFillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: primary, width: 1),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        hintStyle: const TextStyle(color: subtitleGray, fontSize: 15),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
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
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final double height;
  final bool enabled;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final looksActive = enabled && (isLoading || onPressed != null);
    final tappable = enabled && !isLoading && onPressed != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: looksActive
            ? AppTheme.brandGradient
            : LinearGradient(
                colors: [
                  AppTheme.subtitleGray.withValues(alpha: 0.5),
                  AppTheme.subtitleGray.withValues(alpha: 0.4),
                ],
              ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: looksActive
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
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: tappable ? onPressed : null,
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : child,
            ),
          ),
        ),
      ),
    );
  }
}
