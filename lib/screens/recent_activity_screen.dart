import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/activity_model.dart';
import '../services/activity_service.dart';
import '../services/person_display_resolver.dart';
import '../theme/labmate_theme.dart';

class RecentActivityScreen extends StatefulWidget {
  final AppState appState;

  const RecentActivityScreen({super.key, required this.appState});

  @override
  State<RecentActivityScreen> createState() => _RecentActivityScreenState();
}

class _RecentActivityScreenState extends State<RecentActivityScreen> {
  final PersonDisplayResolver _personDisplayResolver = PersonDisplayResolver();
  final Map<String, String> _personDisplayNameCache = {};
  final Set<String> _personDisplayNameRequests = {};

  String _formatDate(ActivityModel activity) {
    final date = activity.createdAt.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'requirement_created':
        return Icons.add_task_rounded;
      case 'requirement_approved':
        return Icons.verified_rounded;
      case 'requirement_rejected':
        return Icons.cancel_rounded;
      case 'order_placed':
        return Icons.shopping_cart_checkout_rounded;
      case 'order_delivered':
        return Icons.local_shipping_rounded;
      case 'chemical_inventory_added':
        return Icons.science_rounded;
      case 'consumable_inventory_added':
        return Icons.inventory_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  void _scheduleActorNameResolution(List<ActivityModel> activities) {
    final userIds = <String>{};
    final explicitNamesByUid = <String, String>{};
    final emailByUid = <String, String>{};

    for (final activity in activities) {
      final userId = activity.createdBy.trim();
      final actorName = activity.actorName.trim();
      if (userId.isEmpty ||
          _personDisplayNameCache.containsKey(userId) ||
          _personDisplayNameRequests.contains(userId) ||
          PersonDisplayResolver.hasUsableDisplayName(actorName)) {
        continue;
      }

      userIds.add(userId);
      explicitNamesByUid[userId] = actorName;
      if (PersonDisplayResolver.isLikelyEmail(actorName)) {
        emailByUid[userId] = actorName;
      }
    }

    if (userIds.isEmpty) {
      return;
    }

    final pendingUserIds = userIds.toList(growable: false);
    _personDisplayNameRequests.addAll(pendingUserIds);

    Future<void>(() async {
      final resolvedNames = await _personDisplayResolver.resolvePeopleForLab(
        labId: widget.appState.selectedLabId,
        userIds: pendingUserIds,
        explicitDisplayNamesByUid: explicitNamesByUid,
        emailByUid: emailByUid,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _personDisplayNameCache.addAll(resolvedNames);
        _personDisplayNameRequests.removeAll(pendingUserIds);
      });
    }).catchError((_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _personDisplayNameRequests.removeAll(pendingUserIds);
      });
    });
  }

  String _actorLabel(ActivityModel activity) {
    final userId = activity.createdBy.trim();
    final cachedName = _personDisplayNameCache[userId]?.trim() ?? '';
    if (cachedName.isNotEmpty) {
      return cachedName;
    }

    return PersonDisplayResolver.resolvePersonDisplayName(
      explicitDisplayName: activity.actorName,
      email: activity.actorName,
      uid: userId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final labId = widget.appState.selectedLabId.trim();
    final activityService = ActivityService();
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Recent Activity')),
      body: SafeArea(
        child: StreamBuilder<List<ActivityModel>>(
          stream: activityService.getActivitiesForLab(labId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final activities = snapshot.data ?? [];
            _scheduleActorNameResolution(activities);
            if (activities.isEmpty) {
              return Center(
                child: Text(
                  'No recent activity yet.',
                  style: TextStyle(color: palette.mutedText),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: activities.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final activity = activities[index];
                final actor = _actorLabel(activity);

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.panel,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: palette.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0x2214B8A6),
                        child: Icon(
                          _iconForType(activity.type),
                          color: const Color(0xFF14B8A6),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activity.message,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              actor.isEmpty
                                  ? _formatDate(activity)
                                  : '$actor · ${_formatDate(activity)}',
                              style: TextStyle(
                                color: palette.subtleText,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
