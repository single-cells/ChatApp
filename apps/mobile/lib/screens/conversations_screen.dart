import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/room.dart';
import '../providers/app_providers.dart';
import '../providers/unread_provider.dart';
import '../theme/app_theme.dart';
import '../utils/defer_set_state.dart';
import '../widgets/room_actions_sheet.dart';
import '../widgets/room_conversation_tile.dart';

/// 聊天室列表：最近参与 / 全部已创建房间。
class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConversationsScreenState createState() => ConversationsScreenState();
}

class ConversationsScreenState extends ConsumerState<ConversationsScreen>
    with DeferSetStateMixin, SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  late final TabController _tabCtrl;
  List<RoomSummary> _recent = [];
  List<RoomSummary> _allRooms = [];
  bool _loadingRecent = true;
  bool _loadingAll = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(_onTabChanged);
    reload();
  }

  void _onTabChanged() {
    if (_tabCtrl.indexIsChanging) return;
    if (_tabCtrl.index == 0) {
      _loadRecent(showPrunedHint: true, silent: true);
    }
  }

  @override
  void dispose() {
    _tabCtrl.removeListener(_onTabChanged);
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> reload({bool silent = true}) async {
    await Future.wait([
      _loadRecent(silent: silent),
      _loadAll(silent: silent),
    ]);
  }

  void _removeRecentLocally(String roomId) {
    deferSetState(() {
      _recent = _recent.where((r) => r.roomId != roomId).toList();
    });
  }

  Future<void> _loadRecent({
    bool showPrunedHint = false,
    bool silent = false,
  }) async {
    final showSpinner = !silent && _recent.isEmpty;
    if (showSpinner) deferSetState(() => _loadingRecent = true);
    try {
      final result = await ref.read(apiProvider).recentRooms();
      if (mounted) {
        deferSetState(() {
          _recent = result.items;
          _loadingRecent = false;
        });
        if (showPrunedHint && result.prunedCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '已移除 ${result.prunedCount} 个已删除的聊天室',
              ),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) deferSetState(() => _loadingRecent = false);
    }
  }

  Future<void> _loadAll({bool silent = false}) async {
    final showSpinner = !silent && _allRooms.isEmpty;
    if (showSpinner) deferSetState(() => _loadingAll = true);
    try {
      final list = await ref.read(apiProvider).listAllRooms();
      if (mounted) {
        deferSetState(() {
          _allRooms = list;
          _loadingAll = false;
        });
      }
    } catch (_) {
      if (mounted) deferSetState(() => _loadingAll = false);
    }
  }

  List<RoomSummary> _filter(List<RoomSummary> source) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return source;
    return source
        .where(
          (r) =>
              r.title.toLowerCase().contains(q) ||
              r.roomId.toLowerCase().contains(q) ||
              r.listSubtitle.toLowerCase().contains(q) ||
              (r.creatorNickname?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  List<RoomSummary> _sortRecentOwnedFirst(List<RoomSummary> rooms) {
    final userId = ref.read(authUserProvider)?.id;
    if (userId == null) return rooms;
    final owned = <RoomSummary>[];
    final other = <RoomSummary>[];
    for (final r in rooms) {
      if (r.createdBy == userId) {
        owned.add(r);
      } else {
        other.add(r);
      }
    }
    return [...owned, ...other];
  }

  @override
  Widget build(BuildContext context) {
    const bottomPad = 24.0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: '搜索聊天室',
              prefixIcon: const Icon(
                Icons.search,
                size: 20,
                color: AppTheme.subtitleGray,
              ),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchCtrl.clear();
                        deferSetState(() => _query = '');
                      },
                    )
                  : null,
            ),
            textInputAction: TextInputAction.search,
            onChanged: (v) => deferSetState(() => _query = v),
          ),
        ),
        TabBar(
          controller: _tabCtrl,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.subtitleGray,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(text: '最近'),
            Tab(text: '全部房间'),
          ],
        ),
        const Divider(height: 0.5, thickness: 0.5),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _roomList(
                loading: _loadingRecent,
                rooms: _sortRecentOwnedFirst(_filter(_recent)),
                emptyText: _query.isEmpty
                    ? '暂无聊天室\n点击底部 + 创建或加入'
                    : '没有匹配的聊天室',
                bottomPad: bottomPad,
                onRefresh: () => _loadRecent(showPrunedHint: true, silent: true),
                highlightOwned: true,
              ),
              _roomList(
                loading: _loadingAll,
                rooms: _filter(_allRooms),
                emptyText: _query.isEmpty ? '暂无已创建的聊天室' : '没有匹配的聊天室',
                bottomPad: bottomPad,
                onRefresh: () => _loadAll(silent: true),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _roomList({
    required bool loading,
    required List<RoomSummary> rooms,
    required String emptyText,
    required double bottomPad,
    required Future<void> Function() onRefresh,
    bool highlightOwned = false,
  }) {
    final userId = ref.read(authUserProvider)?.id;
    final unreadMap = ref.watch(unreadProvider);
    if (loading) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.primary,
      child: rooms.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(bottom: bottomPad),
              children: [
                const SizedBox(height: 100),
                Center(
                  child: Text(
                    emptyText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.subtitleGray,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(bottom: bottomPad),
              itemCount: rooms.length,
              separatorBuilder: (_, __) => const Divider(
                height: 0.5,
                thickness: 0.5,
                indent: 76,
              ),
              itemBuilder: (_, i) {
                final room = rooms[i];
                final isOwned =
                    highlightOwned && userId != null && room.createdBy == userId;
                return RoomConversationTile(
                  key: ValueKey(room.roomId),
                  room: room,
                  highlightAsOwned: isOwned,
                  unreadCount: unreadMap[room.roomId] ?? 0,
                  onTap: () => RoomActionsSheet.openChatWithTitle(
                    context,
                    ref,
                    roomId: room.roomId,
                    title: room.title,
                    onRoomsChanged: () {
                      _removeRecentLocally(room.roomId);
                      reload();
                    },
                  ),
                );
              },
            ),
    );
  }
}
