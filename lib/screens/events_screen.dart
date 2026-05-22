import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';
import '../services/firestore_access_guard.dart';
import '../theme/labmate_theme.dart';
import '../widgets/responsive_page_container.dart';
import 'add_event_screen.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  String _formatDateTime(DateTime value) {
    final monthNames = const [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final meridiem = value.hour >= 12 ? 'PM' : 'AM';
    return '${value.day} ${monthNames[value.month - 1]} ${value.year}, $hour:$minute $meridiem';
  }

  Future<void> _openCreateEvent(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddEventScreen()),
    );
  }

  Future<void> _markDone(BuildContext context, EventModel event) async {
    try {
      await EventService().markDone(docId: event.id);
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Event marked as done')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not mark event done: $error')),
      );
    }
  }

  bool _isCreator(
    EventModel event, {
    required String currentUserId,
    required String currentUserEmail,
  }) {
    final creatorId = event.createdById.trim();
    if (creatorId.isNotEmpty) {
      return creatorId == currentUserId.trim();
    }

    final creatorIdentity = event.createdBy.trim().toLowerCase();
    final email = currentUserEmail.trim().toLowerCase();
    return creatorIdentity.isNotEmpty &&
        creatorIdentity.contains('@') &&
        creatorIdentity == email;
  }

  bool _canReschedule(EventModel event) {
    return !event.isCompleted &&
        event.scheduledAt.isAfter(
          DateTime.now().add(const Duration(minutes: 15)),
        );
  }

  Future<DateTime?> _pickRescheduledDateTime(
    BuildContext context,
    DateTime initial,
  ) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(data: Theme.of(context), child: child!);
      },
    );

    if (pickedDate == null) {
      return null;
    }
    if (!context.mounted) {
      return null;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (context, child) {
        return Theme(data: Theme.of(context), child: child!);
      },
    );

    if (pickedTime == null) {
      return null;
    }
    if (!context.mounted) {
      return null;
    }

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  Future<void> _rescheduleEvent(BuildContext context, EventModel event) async {
    final newDateTime = await _pickRescheduledDateTime(
      context,
      event.scheduledAt,
    );
    if (newDateTime == null) {
      return;
    }

    try {
      await EventService().rescheduleEvent(
        docId: event.id,
        scheduledAt: newDateTime,
      );
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Event rescheduled')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not reschedule event: $error')),
      );
    }
  }

  Future<void> _deleteEvent(BuildContext context, EventModel event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final palette = dialogContext.labmate;
        final colorScheme = dialogContext.colorScheme;
        return AlertDialog(
          backgroundColor: palette.panel,
          title: Text(
            'Delete Event?',
            style: TextStyle(color: colorScheme.onSurface),
          ),
          content: Text(
            'Remove "${event.normalizedTitle}" from this lab?',
            style: TextStyle(color: palette.mutedText, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('Cancel', style: TextStyle(color: palette.mutedText)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text('Delete', style: TextStyle(color: palette.danger)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await EventService().deleteEvent(docId: event.id);
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Event deleted')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete event: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final labName = AppState.instance.selectedLabName.trim();
    final currentUserId = AppState.instance.authenticatedUserId;
    final currentUserEmail = AppState.instance.authenticatedUserEmail;
    final palette = context.labmate;
    final colorScheme = context.colorScheme;

    return SafeArea(
      child: ResponsivePageContainer(
        child: StreamBuilder<List<EventModel>>(
          stream: EventService().getEvents(),
          builder: (context, snapshot) {
            if (!FirestoreAccessGuard.shouldQueryLabScopedData()) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    FirestoreAccessGuard.userMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.mutedText, height: 1.4),
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    FirestoreAccessGuard.messageFor(snapshot.error),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: palette.mutedText, height: 1.4),
                  ),
                ),
              );
            }

            final events = snapshot.data ?? [];

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: palette.panel,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: palette.border),
                    boxShadow: Theme.of(context).brightness == Brightness.dark
                        ? const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lab Events',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              labName.isEmpty
                                  ? 'Create and track shared lab events.'
                                  : 'Managing events for $labName',
                              style: TextStyle(
                                fontSize: 13,
                                color: palette.subtleText,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _openCreateEvent(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF14B8A6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Create'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (snapshot.connectionState == ConnectionState.waiting &&
                    events.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 28),
                      child: CircularProgressIndicator(
                        color: Color(0xFF14B8A6),
                      ),
                    ),
                  )
                else if (events.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: palette.panel,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: palette.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No events added for this lab yet.',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create meetings, reminders, duties, and other shared lab events here.',
                          style: TextStyle(
                            fontSize: 13,
                            color: palette.subtleText,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...events.map((event) {
                    final scheduledAt = event.scheduledAt;
                    final isCreator = _isCreator(
                      event,
                      currentUserId: currentUserId,
                      currentUserEmail: currentUserEmail,
                    );
                    final canMarkDone = isCreator && !event.isCompleted;
                    final canReschedule = isCreator && _canReschedule(event);
                    final showRescheduleLockNote =
                        isCreator && !event.isCompleted && !canReschedule;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: palette.panel,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: palette.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      event.normalizedTitle,
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _EventTypeChip(
                                          label: event.normalizedEventType,
                                        ),
                                        _EventMetaChip(
                                          icon: Icons.schedule_rounded,
                                          label: _formatDateTime(scheduledAt),
                                        ),
                                        if (event.hasVenue)
                                          _EventMetaChip(
                                            icon: Icons.place_outlined,
                                            label: event.normalizedVenue,
                                          ),
                                        _EventMetaChip(
                                          icon: Icons.person_outline_rounded,
                                          label: event.createdBy.trim().isEmpty
                                              ? 'Unknown creator'
                                              : event.createdBy.trim(),
                                        ),
                                        _EventStatusChip(
                                          isCompleted: event.isCompleted,
                                          isUpcoming: !event.scheduledAt
                                              .isBefore(DateTime.now()),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (isCreator)
                                IconButton(
                                  onPressed: () => _deleteEvent(context, event),
                                  tooltip: 'Delete event',
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Color(0xFFFB7185),
                                  ),
                                ),
                            ],
                          ),
                          if (event.description.trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              event.description.trim(),
                              style: TextStyle(
                                color: palette.mutedText,
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          if (isCreator) ...[
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                if (canMarkDone)
                                  OutlinedButton.icon(
                                    onPressed: () => _markDone(context, event),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF34D399),
                                      side: const BorderSide(
                                        color: Color(0xFF34D399),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Mark as Done'),
                                  )
                                else
                                  const Text(
                                    'Completed',
                                    style: TextStyle(
                                      color: Color(0xFF34D399),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                if (!event.isCompleted)
                                  OutlinedButton.icon(
                                    onPressed: canReschedule
                                        ? () => _rescheduleEvent(context, event)
                                        : null,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF38BDF8),
                                      disabledForegroundColor:
                                          palette.subtleText,
                                      side: BorderSide(
                                        color: canReschedule
                                            ? const Color(0xFF38BDF8)
                                            : palette.border,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.update_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Reschedule'),
                                  ),
                              ],
                            ),
                            if (showRescheduleLockNote) ...[
                              const SizedBox(height: 10),
                              Text(
                                'Reschedule becomes unavailable within 15 minutes of start time.',
                                style: TextStyle(
                                  color: palette.subtleText,
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ] else if (!event.isCompleted) ...[
                            Text(
                              'Only the creator can update this event.',
                              style: TextStyle(
                                color: palette.subtleText,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EventTypeChip extends StatelessWidget {
  final String label;

  const _EventTypeChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: palette.selected,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EventMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _EventMetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: palette.panelAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: palette.mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventStatusChip extends StatelessWidget {
  final bool isCompleted;
  final bool isUpcoming;

  const _EventStatusChip({required this.isCompleted, required this.isUpcoming});

  @override
  Widget build(BuildContext context) {
    final color = isCompleted
        ? const Color(0xFF34D399)
        : isUpcoming
        ? const Color(0xFFF59E0B)
        : const Color(0xFF38BDF8);
    final label = isCompleted
        ? 'Done'
        : isUpcoming
        ? 'Upcoming'
        : 'Pending';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
