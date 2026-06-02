import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Runs [action] after the current pointer/gesture frame.
void deferAction(VoidCallback action) {
  WidgetsBinding.instance.addPostFrameCallback((_) => action());
}

/// Avoids calling [setState] during pointer dispatch (Windows `mouse_tracker` assert).
mixin DeferSetStateMixin<T extends StatefulWidget> on State<T> {
  void deferSetState(VoidCallback fn) {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      setState(fn);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(fn);
    });
  }
}
