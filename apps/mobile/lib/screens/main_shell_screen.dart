import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message.dart';
import '../providers/app_providers.dart';
import '../services/socket_service.dart';
import '../providers/unread_provider.dart';
import '../theme/app_theme.dart';
import '../utils/defer_set_state.dart';
import '../widgets/create_room_fab.dart';
import '../widgets/room_actions_sheet.dart';
import 'conversations_screen.dart';
import 'me_screen.dart';

/// Bottom nav + center create button (FAB via Scaffold — full hit target).
class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen>
    with DeferSetStateMixin {
  int _index = 0;
  final _conversationsKey = GlobalKey<ConversationsScreenState>();
  MessageHandler? _unreadHandler;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _attachUnreadListener());
  }

  void _attachUnreadListener() {
    if (_unreadHandler != null) return;
    void onMessage(ChatMessage m) {
      final userId = ref.read(authUserProvider)?.id;
      ref.read(unreadProvider.notifier).onIncomingMessage(
            roomId: m.roomId,
            senderId: m.senderId,
            myUserId: userId,
          );
      if (_index == 0) {
        _conversationsKey.currentState?.reload(silent: true);
      }
    }
    _unreadHandler = onMessage;
    ref.read(socketProvider).onMessageNew(onMessage);
  }

  @override
  void dispose() {
    final handler = _unreadHandler;
    if (handler != null) {
      ref.read(socketProvider).offMessageNew(handler);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final nickname = ref.watch(authUserProvider)?.nickname;
    final onMessagesTab = _index == 0;
    final unreadMap = ref.watch(unreadProvider);
    final hasUnread = unreadMap.values.any((c) => c > 0);

    return Scaffold(
      backgroundColor: AppTheme.navBar,
      appBar: AppBar(
        backgroundColor: AppTheme.navBar,
        systemOverlayStyle: AppTheme.systemUiOverlay,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(onMessagesTab ? 'FreeChat' : '我'),
        leading: onMessagesTab
            ? _nicknameLeading(context, nickname)
            : null,
        leadingWidth: onMessagesTab ? 128 : null,
      ),
      body: IndexedStack(
        index: _index,
        children: [
          ConversationsScreen(key: _conversationsKey),
          const MeScreen(),
        ],
      ),
      floatingActionButton: _index == 0
          ? CreateRoomFab(
              onPressed: () => RoomActionsSheet.show(
                context,
                ref,
                onRoomsChanged: () =>
                    _conversationsKey.currentState?.reload(),
              ),
            )
          : null,
      floatingActionButtonLocation: const FabDockedAboveNavLocation(),
      bottomNavigationBar: Material(
        color: AppTheme.navBar,
        elevation: 8,
        child: SizedBox(
          height: 56 + bottomInset,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Row(
              children: [
                Expanded(
                  child: _navItem(
                    index: 0,
                    icon: Icons.chat_bubble_outline,
                    activeIcon: Icons.chat_bubble,
                    label: '消息',
                    showBadge: hasUnread,
                  ),
                ),
                const SizedBox(width: CreateRoomFab.size + 24),
                Expanded(
                  child: _navItem(
                    index: 1,
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    label: '我',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget? _nicknameLeading(BuildContext context, String? nickname) {
    final label = nickname?.isNotEmpty == true ? nickname! : '未登录';
    final titleStyle = Theme.of(context).appBarTheme.titleTextStyle;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: titleStyle?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    bool showBadge = false,
  }) {
    final selected = _index == index;
    final color = selected ? AppTheme.primary : AppTheme.tabInactive;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_index == index) return;
        deferSetState(() => _index = index);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(selected ? activeIcon : icon, color: color, size: 26),
                if (showBadge)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFA5151),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
