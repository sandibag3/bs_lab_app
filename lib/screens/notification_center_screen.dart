import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import 'lab_members_screen.dart';

class NotificationCenterScreen extends StatelessWidget {
  final AppState appState;

  const NotificationCenterScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final notificationService = NotificationService();
    final userId = appState.authenticatedUserId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: userId.trim().isEmpty
                ? null
                : () async {
                    try {
                      await notificationService.markAllAsRead(userId: userId);
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Could not mark notifications as read.',
                          ),
                        ),
                      );
                    }
                  },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: notificationService.streamNotifications(userId: userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Notifications are unavailable.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data!;
          if (notifications.isEmpty) {
            return const Center(child: Text('No notifications yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationTile(
                notification: notification,
                onTap: () => _openNotification(
                  context,
                  notificationService,
                  notification,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openNotification(
    BuildContext context,
    NotificationService notificationService,
    NotificationModel notification,
  ) async {
    try {
      await notificationService.markAsRead(
        userId: appState.authenticatedUserId,
        notificationId: notification.id,
      );
    } catch (_) {
      // A notification can still be opened when its read marker fails.
    }

    if (!context.mounted) {
      return;
    }

    final isJoinRequest =
        notification.type == NotificationModel.typeJoinRequest &&
        appState.isPi &&
        appState.selectedLabId.trim() == notification.labId.trim();
    if (isJoinRequest) {
      final navigator = Navigator.of(context);
      navigator.pop();
      navigator.push(
        MaterialPageRoute(builder: (_) => LabMembersScreen(appState: appState)),
      );
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = notification.isUnread
        ? colorScheme.primary.withValues(alpha: 0.10)
        : colorScheme.surface;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                notification.isUnread
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_none_rounded,
                color: notification.isUnread
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: notification.isUnread
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        Text(
                          _formatTimestamp(notification.createdAt),
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        if (notification.labId.trim().isNotEmpty)
                          Text(
                            'Lab: ${notification.labId.trim()}',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (notification.isUnread)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 5),
                  child: CircleAvatar(
                    radius: 4,
                    backgroundColor: colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatTimestamp(DateTime? value) {
    if (value == null) {
      return 'Just now';
    }

    final now = DateTime.now();
    final difference = now.difference(value);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }
}
