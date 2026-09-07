import 'package:flutter/material.dart';

import '../driver_models.dart';
import '../driver_theme.dart';
import '../widgets/driver_shared_widgets.dart';

class DriverChatListScreen extends StatelessWidget {
  final List<ChatThread> threads;
  final ValueChanged<ChatThread> onOpenThread;

  /// Pull-to-refresh for the conversation list.
  final Future<void> Function() onRefresh;

  const DriverChatListScreen({
    super.key,
    required this.threads,
    required this.onOpenThread,
    required this.onRefresh,
  });

  String _timeLabel(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DriverColors.background,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, foregroundColor: DriverColors.textPrimary, title: const Text('Messages', style: TextStyle(fontWeight: FontWeight.w800))),
      body: DriverRefreshable(
        onRefresh: onRefresh,
        child: threads.isEmpty
          // A single-item scroll view rather than a bare Padding: an empty
          // list still has to be pullable for the refresh to be reachable.
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 110),
              children: const [
                DriverEmptyState(icon: Icons.chat_bubble_outline_rounded, title: 'No conversations yet', subtitle: 'Messages from customers on active deliveries will show up here.'),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
              itemCount: threads.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final thread = threads[i];
                final unread = thread.unreadCount > 0;
                return InkWell(
                  onTap: () => onOpenThread(thread),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: unread ? DriverColors.primary.withOpacity(0.3) : DriverColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(gradient: LinearGradient(colors: DriverColors.primaryGradient), shape: BoxShape.circle),
                          child: Text(thread.avatarInitial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(thread.customerName, style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w700, fontSize: 14, color: DriverColors.textPrimary)),
                              const SizedBox(height: 2),
                              Text(
                                thread.lastMessage.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12.5, color: unread ? DriverColors.textPrimary : DriverColors.textSecondary, fontWeight: unread ? FontWeight.w600 : FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_timeLabel(thread.lastMessage.sentAt), style: DriverText.caption),
                            const SizedBox(height: 6),
                            if (unread)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: DriverColors.primary, borderRadius: BorderRadius.circular(20)),
                                child: Text('${thread.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      ),
    );
  }
}
