import 'dart:math' as math;

import 'package:flutter/material.dart';

/// CSS `cubic-bezier(0.25, 0.1, 0.25, 1)`.
abstract final class BreathingEase {
  static const Curve curve = Cubic(0.25, 0.1, 0.25, 1.0);
}

/// One breath (expand + contract) inside [0, activeFraction), then hold until t=1.
class BreathingPauseCurve extends Curve {
  const BreathingPauseCurve({
    required this.activeFraction,
    this.ease = BreathingEase.curve,
  });

  final double activeFraction;
  final Curve ease;

  @override
  double transform(double t) {
    if (t >= activeFraction) return 0;
    final u = t / activeFraction;
    if (u <= 0.5) {
      return ease.transform(u * 2);
    }
    return ease.transform((1 - u) * 2);
  }
}

/// Sinusoidal 0→1→0 in one controller cycle (optional).
class BreathingSineCurve extends Curve {
  const BreathingSineCurve();

  @override
  double transform(double t) {
    return 0.5 + 0.5 * math.sin(2 * math.pi * t - math.pi / 2);
  }
}

/// Idle pulse: [pulseDuration] anim, [pauseDuration] rest, repeat.
class SubtleIdlePulse extends StatefulWidget {
  const SubtleIdlePulse({
    super.key,
    required this.child,
    this.enabled = true,
    this.minScale = 0.96,
    this.maxScale = 1.0,
    this.pulseDuration = const Duration(milliseconds: 1200),
    this.pauseDuration = const Duration(seconds: 2),
    this.curve,
    this.animateOpacity = false,
    this.minOpacity = 0.9,
  });

  final Widget child;
  final bool enabled;
  final double minScale;
  final double maxScale;
  final Duration pulseDuration;
  final Duration pauseDuration;
  final Curve? curve;
  final bool animateOpacity;
  final double minOpacity;

  Duration get cycleDuration => pulseDuration + pauseDuration;

  Curve get resolvedEase => curve ?? BreathingEase.curve;

  double get activeFraction {
    final total = cycleDuration.inMicroseconds;
    if (total <= 0) return 1;
    return pulseDuration.inMicroseconds / total;
  }

  @override
  State<SubtleIdlePulse> createState() => _SubtleIdlePulseState();
}

class _SubtleIdlePulseState extends State<SubtleIdlePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.cycleDuration);
    _buildAnimations();
    _startLoop();
  }

  void _buildAnimations() {
    final curve = BreathingPauseCurve(
      activeFraction: widget.activeFraction,
      ease: widget.resolvedEase,
    );
    final curved = CurvedAnimation(parent: _ctrl, curve: curve);
    _scale = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(curved);

    if (widget.animateOpacity) {
      _opacity = Tween<double>(
        begin: widget.minOpacity,
        end: 1.0,
      ).animate(curved);
    } else {
      _opacity = const AlwaysStoppedAnimation(1.0);
    }
  }

  void _startLoop() {
    if (!widget.enabled) return;
    _ctrl.repeat();
  }

  @override
  void didUpdateWidget(SubtleIdlePulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cycleDuration != widget.cycleDuration ||
        oldWidget.pulseDuration != widget.pulseDuration ||
        oldWidget.pauseDuration != widget.pauseDuration ||
        oldWidget.minScale != widget.minScale ||
        oldWidget.maxScale != widget.maxScale ||
        oldWidget.minOpacity != widget.minOpacity ||
        oldWidget.animateOpacity != widget.animateOpacity ||
        oldWidget.resolvedEase != widget.resolvedEase) {
      _ctrl.stop();
      _ctrl.duration = widget.cycleDuration;
      _buildAnimations();
    }
    if (widget.enabled) {
      if (!_ctrl.isAnimating) _startLoop();
    } else {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.scale(
            scale: _scale.value,
            alignment: Alignment.center,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
