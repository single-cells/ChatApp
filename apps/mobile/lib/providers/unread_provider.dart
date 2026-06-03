import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_badge_service.dart';

final appBadgeServiceProvider = Provider((ref) => AppBadgeService());

class UnreadNotifier extends StateNotifier<Map<String, int>> {
  UnreadNotifier(this._badge) : super({});

  final AppBadgeService _badge;
  String? _activeRoomId;

  int get totalRoomsWithUnread =>
      state.values.where((c) => c > 0).length;

  void setActiveRoom(String? roomId) {
    _activeRoomId = roomId;
    if (roomId != null) {
      markRoomRead(roomId);
    }
  }

  void onIncomingMessage({
    required String roomId,
    required String senderId,
    required String? myUserId,
  }) {
    if (myUserId != null && senderId == myUserId) return;
    if (roomId == _activeRoomId) return;
    final next = Map<String, int>.from(state);
    next[roomId] = (next[roomId] ?? 0) + 1;
    state = next;
    _syncBadge();
  }

  void markRoomRead(String roomId) {
    if (!state.containsKey(roomId) || state[roomId] == 0) return;
    final next = Map<String, int>.from(state);
    next.remove(roomId);
    state = next;
    _syncBadge();
  }

  void clearAll() {
    if (state.isEmpty) return;
    state = {};
    _syncBadge();
  }

  void _syncBadge() {
    _badge.syncUnreadCount(totalRoomsWithUnread);
  }
}

final unreadProvider =
    StateNotifierProvider<UnreadNotifier, Map<String, int>>((ref) {
  return UnreadNotifier(ref.watch(appBadgeServiceProvider));
});
