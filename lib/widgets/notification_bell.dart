import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/notification_model.dart';
import '../screens/notification_center_screen.dart';
import '../services/notification_service.dart';

class NotificationBell extends StatefulWidget {
  final AppState appState;

  const NotificationBell({super.key, required this.appState});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final NotificationService _notificationService = NotificationService();
  late String _userId;
  late Stream<List<NotificationModel>> _notificationsStream;
  Set<String> _knownNotificationIds = <String>{};
  DateTime _sessionStartedAt = DateTime.now();
  bool _hasInitialSnapshot = false;

  @override
  void initState() {
    super.initState();
    _setUserId(widget.appState.authenticatedUserId);
  }

  @override
  void didUpdateWidget(covariant NotificationBell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextUserId = widget.appState.authenticatedUserId;
    if (nextUserId != _userId) {
      _setUserId(nextUserId);
    }
  }

  void _setUserId(String value) {
    _userId = value.trim();
    _notificationsStream = _notificationService.streamNotifications(
      userId: _userId,
    );
    _knownNotificationIds = <String>{};
    _sessionStartedAt = DateTime.now();
    _hasInitialSnapshot = false;
  }

  void _observeNotifications(List<NotificationModel> notifications) {
    if (!_hasInitialSnapshot) {
      _knownNotificationIds = notifications.map((item) => item.id).toSet();
      _hasInitialSnapshot = true;
      return;
    }

    final newNotifications = notifications
        .where(
          (notification) =>
              !_knownNotificationIds.contains(notification.id) &&
              notification.isUnread &&
              notification.createdAt != null &&
              !notification.createdAt!.isBefore(_sessionStartedAt),
        )
        .toList();
    _knownNotificationIds.addAll(notifications.map((item) => item.id));

    if (newNotifications.isEmpty || !mounted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final notification = newNotifications.first;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(
        SnackBar(
          content: Text(notification.title),
          action: SnackBarAction(
            label: 'View',
            onPressed: _openNotificationCenter,
          ),
        ),
      );
    });
  }

  void _openNotificationCenter() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationCenterScreen(appState: widget.appState),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NotificationModel>>(
      stream: _notificationsStream,
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? const <NotificationModel>[];
        _observeNotifications(notifications);
        final unreadCount = notifications.where((item) => item.isUnread).length;

        return IconButton(
          tooltip: 'Notifications',
          onPressed: _openNotificationCenter,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none_rounded),
              if (unreadCount > 0)
                Positioned(
                  top: -7,
                  right: -8,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 17),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
