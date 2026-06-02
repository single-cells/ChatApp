import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/room.dart';
import '../providers/app_providers.dart';
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
    reload();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    await Future.wait([_loadRecent(), _loadAll()]);
  }

  Future<void> _loadRecent() async {
    deferSetState(() => _loadingRecent = true);
    try {
      final list = await ref.read(apiProvider).recentRooms();
      if (mounted) {
        deferSetState(() {
          _recent = list;
          _loadingRecent = false;
        });
      }
    } catch (_) {
      if (mounted) deferSetState(() => _loadingRecent = false);
    }
  }

  Future<void> _loadAll() async {
    deferSetState(() => _loadingAll = true);
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
                rooms: _filter(_recent),
                emptyText: _query.isEmpty
                    ? '暂无聊天室\n点击底部 + 创建或加入'
                    : '没有匹配的聊天室',
                bottomPad: bottomPad,
                onRefresh: _loadRecent,
              ),
              _roomList(
                loading: _loadingAll,
                rooms: _filter(_allRooms),
                emptyText: _query.isEmpty ? '暂无已创建的聊天室' : '没有匹配的聊天室',
                bottomPad: bottomPad,
                onRefresh: _loadAll,
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
  }) {
    if (loading) {
      return const Center(
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
              itemBuilder: (_, i) => RoomConversationTile(
                room: rooms[i],
                onTap: () => RoomActionsSheet.openChatWithTitle(
                  context,
                  ref,
                  roomId: rooms[i].roomId,
                  title: rooms[i].title,
                  onRoomsChanged: reload,
                ),
              ),
            ),
    );
  }
}
