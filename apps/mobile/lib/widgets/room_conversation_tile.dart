import 'package:flutter/material.dart';
import '../models/room.dart';
import '../theme/app_theme.dart';
import 'room_avatar.dart';

class RoomConversationTile extends StatelessWidget {
  const RoomConversationTile({
    super.key,
    required this.room,
    required this.onTap,
    this.highlightAsOwned = false,
    this.unreadCount = 0,
  });

  final RoomSummary room;
  final VoidCallback onTap;
  final bool highlightAsOwned;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final time = formatRoomListTime(room.lastMessageAt);
    final bg = highlightAsOwned
        ? AppTheme.ownedRoomListBackground
        : AppTheme.listBackground;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ColoredBox(
        color: bg,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RoomAvatar(title: room.title),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            room.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: highlightAsOwned
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: AppTheme.titleBlack,
                            ),
                          ),
                        ),
                        if (highlightAsOwned) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '我创建',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.primaryDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        if (unreadCount > 0)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFA5151),
                              shape: BoxShape.circle,
                            ),
                          )
                        else if (time.isNotEmpty)
                          Text(
                            time,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.subtitleGray,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      room.listSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.subtitleGray,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
