import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/activity_model.dart';
import '../services/activity_service.dart';

class RecentActivityScreen extends StatelessWidget {
  final AppState appState;

  const RecentActivityScreen({super.key, required this.appState});

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

  @override
  Widget build(BuildContext context) {
    final labId = appState.selectedLabId.trim();
    final activityService = ActivityService();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Recent Activity',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<ActivityModel>>(
          stream: activityService.getActivitiesForLab(labId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final activities = snapshot.data ?? [];
            if (activities.isEmpty) {
              return const Center(
                child: Text(
                  'No recent activity yet.',
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: activities.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final activity = activities[index];
                final actor = activity.actorName.trim();

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              actor.isEmpty
                                  ? _formatDate(activity)
                                  : '$actor · ${_formatDate(activity)}',
                              style: const TextStyle(
                                color: Colors.white60,
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
