import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final nickname = ref.watch(authUserProvider)?.nickname;
    final onMessagesTab = _index == 0;

    return Scaffold(
      backgroundColor: AppTheme.listBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(onMessagesTab ? '聊天室' : '我'),
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
            Icon(selected ? activeIcon : icon, color: color, size: 26),
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
