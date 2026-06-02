import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Play / loading / animated playing bars for voice messages.
class VoicePlaybackIndicator extends StatefulWidget {
  const VoicePlaybackIndicator({
    super.key,
    required this.loading,
    required this.playing,
    required this.durationLabel,
    required this.accentColor,
    this.onTap,
  });

  final bool loading;
  final bool playing;
  final String durationLabel;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  State<VoicePlaybackIndicator> createState() => _VoicePlaybackIndicatorState();
}

class _VoicePlaybackIndicatorState extends State<VoicePlaybackIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _barsCtrl;

  @override
  void initState() {
    super.initState();
    _barsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(VoicePlaybackIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playing != widget.playing) {
      _syncAnimation();
    }
  }

  /// SingleTickerProvider allows only one controller per State — never dispose/recreate.
  void _syncAnimation() {
    if (widget.playing) {
      if (!_barsCtrl.isAnimating) {
        _barsCtrl.repeat();
      }
    } else {
      _barsCtrl.stop();
    }
  }

  @override
  void dispose() {
    _barsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: _buildLeading(),
          ),
          const SizedBox(width: 8),
          Text(
            widget.durationLabel,
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.titleBlack,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeading() {
    if (widget.loading) {
      return Padding(
        padding: const EdgeInsets.all(6),
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: widget.accentColor,
        ),
      );
    }
    if (widget.playing) {
      return AnimatedBuilder(
        animation: _barsCtrl,
        builder: (_, __) => _WaveBars(
          t: _barsCtrl.value,
          color: widget.accentColor,
        ),
      );
    }
    return Icon(
      Icons.play_circle_fill,
      size: 32,
      color: widget.accentColor,
    );
  }
}

class _WaveBars extends StatelessWidget {
  const _WaveBars({required this.t, required this.color});

  final double t;
  final Color color;

  @override
  Widget build(BuildContext context) {
    double h(int i) {
      final phase = (t + i * 0.22) % 1.0;
      return 6 + 14 * (0.5 + 0.5 * math.sin(phase * math.pi * 2));
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _bar(h(0)),
        const SizedBox(width: 3),
        _bar(h(1)),
        const SizedBox(width: 3),
        _bar(h(2)),
      ],
    );
  }

  Widget _bar(double height) {
    return Container(
      width: 4,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

}
