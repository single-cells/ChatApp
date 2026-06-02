import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'subtle_idle_pulse.dart';

/// Center create-room button. Hit target is fixed 64x64; pulse only scales visuals.
class CreateRoomFab extends StatelessWidget {
  const CreateRoomFab({super.key, required this.onPressed});

  final VoidCallback onPressed;

  static const double size = 64;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SubtleIdlePulse(
          curve: BreathingEase.curve,
          minScale: 0.92,
          maxScale: 1.0,
          pulseDuration: const Duration(milliseconds: 1200),
          pauseDuration: const Duration(seconds: 2),
          animateOpacity: true,
          minOpacity: 0.92,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.brandGradient,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 1,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.add, size: 40, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// FAB half-overlaps the top edge of [bottomNavigationBar] (WeChat-style).
class FabDockedAboveNavLocation extends FloatingActionButtonLocation {
  const FabDockedAboveNavLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final fab = scaffoldGeometry.floatingActionButtonSize;
    final x = (scaffoldGeometry.scaffoldSize.width - fab.width) / 2.0;
    final y = scaffoldGeometry.contentBottom - fab.height / 2;
    return Offset(x, y);
  }
}
