import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/chemical_model.dart';
import '../models/event_model.dart';
import '../models/order_model.dart';
import '../models/requirement_model.dart';
import '../models/user_profile.dart';
import '../services/event_service.dart';
import '../services/inventory_service.dart';
import '../services/order_service.dart';
import '../services/requirement_service.dart';
import '../widgets/newly_arrived_section.dart';
import '../widgets/search_bar_widget.dart';
import 'consumables_inventory_screen.dart';
import 'lab_members_screen.dart';
import 'lab_settings_screen.dart';
import 'lab_switcher_screen.dart';
import 'recent_activity_screen.dart';

class HomeDashboardTab extends StatelessWidget {
  final AppState appState;
  final VoidCallback onOpenChemicals;
  final VoidCallback onOpenCalculator;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenEvents;
  final VoidCallback onOpenArticles;
  final VoidCallback onOpenInstruments;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenCart;
  final VoidCallback onOpenLabManual;
  final VoidCallback onOpenChemDraw;
  final VoidCallback onOpenMore;

  const HomeDashboardTab({
    super.key,
    required this.appState,
    required this.onOpenChemicals,
    required this.onOpenCalculator,
    required this.onOpenProfile,
    required this.onOpenEvents,
    required this.onOpenArticles,
    required this.onOpenInstruments,
    required this.onOpenOrders,
    required this.onOpenCart,
    required this.onOpenLabManual,
    required this.onOpenChemDraw,
    required this.onOpenMore,
  });

  void _openConsumablesInventory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConsumablesInventoryScreen()),
    );
  }

  Future<void> _openLabSwitcher(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LabSwitcherScreen(appState: appState)),
    );
  }

  void _openLabMembers(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LabMembersScreen(appState: appState)),
    );
  }

  void _openLabSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LabSettingsScreen(appState: appState)),
    );
  }

  void _openRecentActivity(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecentActivityScreen(appState: appState),
      ),
    );
  }

  int _pendingApprovalCount(List<RequirementModel> requirements) {
    if (!appState.isPiAdmin) {
      return 0;
    }

    return requirements.where((requirement) {
      final status = requirement.status.trim().toLowerCase();
      return status == 'pending' ||
          status == 'waiting approval' ||
          status == 'waiting_approval';
    }).length;
  }

  int _ordersInProgressCount(List<OrderModel> orders) {
    return orders.where((order) {
      final status = order.status.trim().toLowerCase();
      return status == 'ordered';
    }).length;
  }

  bool _chemicalNeedsAttention(ChemicalModel chemical) {
    final availability = chemical.availability.trim().toLowerCase();
    return availability == 'low' ||
        availability.contains('about') ||
        availability.contains('finished') ||
        availability.contains('empty') ||
        availability.contains('not available') ||
        availability.contains('unavailable') ||
        availability == 'nil' ||
        availability == '0';
  }

  int _chemicalAttentionCount(List<ChemicalModel> chemicals) {
    final grouped = InventoryService().groupByCas(chemicals);
    return grouped.values.where((group) {
      return group.any(_chemicalNeedsAttention);
    }).length;
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _consumablesInventoryStream() {
    return FirebaseFirestore.instance
        .collection('consumables_inventory')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.where((doc) {
            final labId = (doc.data()['labId'] ?? '').toString().trim();
            return appState.matchesSelectedLabId(labId);
          }).toList();
        });
  }

  double? _readQuantityNumber(String quantity) {
    final match = RegExp(r'[-+]?\d*\.?\d+').firstMatch(quantity.trim());
    if (match == null) {
      return null;
    }

    return double.tryParse(match.group(0) ?? '');
  }

  int _consumablesLowStockCount(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) {
      final quantity = (doc.data()['quantity'] ?? '').toString();
      final numericQuantity = _readQuantityNumber(quantity);
      return numericQuantity != null && numericQuantity <= 2;
    }).length;
  }

  Widget _buildWorkflowGrid({
    required BuildContext context,
    required List<Map<String, dynamic>> workflowItems,
    required int pendingApprovalCount,
    required int ordersInProgressCount,
    required int chemicalAttentionCount,
    required int consumablesLowStockCount,
  }) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: workflowItems.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.92,
      ),
      itemBuilder: (context, index) {
        final item = workflowItems[index];
        final title = item['title'] as String;
        final icon = item['icon'] as IconData;
        final onTap = item['onTap'] as VoidCallback;
        final accentColor = item['accentColor'] as Color;
        final badgeCount = title == 'Cart'
            ? pendingApprovalCount
            : title == 'Orders'
            ? ordersInProgressCount
            : title == 'Chemical Inventory'
            ? chemicalAttentionCount
            : title == 'Consumables Inventory'
            ? consumablesLowStockCount
            : 0;

        return _HomeToolCard(
          title: title,
          icon: icon,
          accentColor: accentColor,
          onTap: onTap,
          badgeCount: badgeCount,
        );
      },
    );
  }

  Future<void> _openHeroActions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lab Actions',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Switch labs, view members, or open settings for the current workspace.',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _LabActionTile(
                    icon: Icons.swap_horiz_rounded,
                    title: 'Switch Lab',
                    subtitle: 'Choose a different lab context you belong to.',
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _openLabSwitcher(context);
                    },
                  ),
                  const SizedBox(height: 10),
                  _LabActionTile(
                    icon: Icons.groups_rounded,
                    title: 'Lab Members',
                    subtitle: 'View the current lab membership list and roles.',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _openLabMembers(context);
                    },
                  ),
                  const SizedBox(height: 10),
                  _LabActionTile(
                    icon: Icons.settings_rounded,
                    title: 'Lab Settings',
                    subtitle:
                        'Open join code, lab details, and workspace settings.',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _openLabSettings(context);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> workflowItems = [
      {
        'title': 'Chemical Inventory',
        'icon': Icons.science_rounded,
        'accentColor': const Color(0xFF2DD4BF),
        'onTap': onOpenChemicals,
      },
      {
        'title': 'Consumables Inventory',
        'icon': Icons.inventory_rounded,
        'accentColor': const Color(0xFF60A5FA),
        'onTap': () => _openConsumablesInventory(context),
      },
      {
        'title': 'Cart',
        'icon': Icons.assignment_rounded,
        'accentColor': const Color(0xFFFBBF24),
        'onTap': onOpenCart,
      },
      {
        'title': 'Orders',
        'icon': Icons.local_shipping_rounded,
        'accentColor': const Color(0xFF38BDF8),
        'onTap': onOpenOrders,
      },
      {
        'title': 'Calculator',
        'icon': Icons.calculate_rounded,
        'accentColor': const Color(0xFFA78BFA),
        'onTap': onOpenCalculator,
      },
      {
        'title': 'Instruments',
        'icon': Icons.precision_manufacturing_rounded,
        'accentColor': const Color(0xFF94A3B8),
        'onTap': onOpenInstruments,
      },
      {
        'title': 'Lab Manual',
        'icon': Icons.description_rounded,
        'accentColor': const Color(0xFF34D399),
        'onTap': onOpenLabManual,
      },
      {
        'title': 'ChemDraw',
        'icon': Icons.draw_rounded,
        'accentColor': const Color(0xFFF472B6),
        'onTap': onOpenChemDraw,
      },
    ];

    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final profile = appState.profile;
        final profileName = profile.name.trim();
        final resolvedName = profileName.isEmpty || profileName == 'Your Name'
            ? appState.authenticatedUserName
            : profileName;
        final photoReference = profile.photoUrl.trim();
        final selectedLabName = appState.selectedLabName.trim();

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SearchBarWidget(onTap: onOpenChemicals),
                const SizedBox(height: 12),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => _openHeroActions(context),
                    child: Ink(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F766E), Color(0xFF0EA5E9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Labmate',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.16),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  appState.currentRoleLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _HeroProfileAvatar(
                                photoReference: photoReference,
                                displayName: resolvedName,
                                fallbackEmail: appState.authenticatedUserEmail,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      resolvedName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.apartment_rounded,
                                          color: Colors.white,
                                          size: 15,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            selectedLabName.isEmpty
                                                ? 'Tap to open lab actions'
                                                : selectedLabName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12.8,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white70,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (appState.shouldShowProfileReminder) ...[
                  _WorkflowEntryCard(
                    title: 'Complete Personal Information',
                    subtitle:
                        'Your profile is still incomplete. You can keep using Labmate and finish it when convenient.',
                    icon: Icons.person_outline_rounded,
                    accentColor: const Color(0xFFF59E0B),
                    onTap: onOpenProfile,
                  ),
                  const SizedBox(height: 20),
                ],
                const NewlyArrivedSection(),
                const SizedBox(height: 20),
                _UpcomingEventsPreview(onViewAll: onOpenEvents),
                const SizedBox(height: 20),
                StreamBuilder<List<RequirementModel>>(
                  stream: RequirementService().getRequirements(),
                  builder: (context, requirementsSnapshot) {
                    return StreamBuilder<List<OrderModel>>(
                      stream: OrderService().getOrders(),
                      builder: (context, ordersSnapshot) {
                        return StreamBuilder<List<ChemicalModel>>(
                          stream: InventoryService().getChemicals(),
                          builder: (context, chemicalsSnapshot) {
                            return StreamBuilder<
                              List<QueryDocumentSnapshot<Map<String, dynamic>>>
                            >(
                              stream: _consumablesInventoryStream(),
                              builder: (context, consumablesSnapshot) {
                                return _buildWorkflowGrid(
                                  context: context,
                                  workflowItems: workflowItems,
                                  pendingApprovalCount: _pendingApprovalCount(
                                    requirementsSnapshot.data ?? [],
                                  ),
                                  ordersInProgressCount: _ordersInProgressCount(
                                    ordersSnapshot.data ?? [],
                                  ),
                                  chemicalAttentionCount:
                                      _chemicalAttentionCount(
                                        chemicalsSnapshot.data ?? [],
                                      ),
                                  consumablesLowStockCount:
                                      _consumablesLowStockCount(
                                        consumablesSnapshot.data ?? [],
                                      ),
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 20),
                _WorkflowEntryCard(
                  title: 'Recent Activity',
                  subtitle:
                      'View recent requirements, orders, deliveries, and inventory entries for this lab.',
                  icon: Icons.notifications_rounded,
                  accentColor: const Color(0xFF14B8A6),
                  onTap: () => _openRecentActivity(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeroProfileAvatar extends StatelessWidget {
  final String photoReference;
  final String displayName;
  final String fallbackEmail;

  const _HeroProfileAvatar({
    required this.photoReference,
    required this.displayName,
    required this.fallbackEmail,
  });

  ImageProvider<Object>? _resolveImageProvider() {
    final cleanReference = photoReference.trim();
    if (cleanReference.isEmpty ||
        UserProfile.isScientificAvatarReference(cleanReference)) {
      return null;
    }

    final uri = Uri.tryParse(cleanReference);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https')) {
      return NetworkImage(cleanReference);
    }

    if (uri != null && uri.scheme == 'file') {
      final file = File.fromUri(uri);
      if (file.existsSync()) {
        return FileImage(file);
      }
    }

    final file = File(cleanReference);
    if (file.existsSync()) {
      return FileImage(file);
    }

    return null;
  }

  String _fallbackInitials() {
    final identity = displayName.trim().isNotEmpty
        ? displayName.trim()
        : fallbackEmail.trim();
    if (identity.isEmpty) {
      return 'U';
    }

    final words = identity
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList();

    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }

    final cleanIdentity = identity.contains('@')
        ? identity.split('@').first
        : identity;
    if (cleanIdentity.isEmpty) {
      return 'U';
    }
    final maxLength = cleanIdentity.length >= 2 ? 2 : 1;
    return cleanIdentity.substring(0, maxLength).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scientificAvatar = UserProfile.scientificAvatarFromReference(
      photoReference,
    );
    final imageProvider = _resolveImageProvider();
    final initials = _fallbackInitials();

    return Container(
      height: 42,
      width: 42,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: ClipOval(
        child: scientificAvatar != null
            ? _HeroProfileScientificAvatar(icon: scientificAvatar.icon)
            : imageProvider == null
            ? _HeroProfileInitials(initials: initials)
            : Image(
                image: imageProvider,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _HeroProfileInitials(initials: initials);
                },
              ),
      ),
    );
  }
}

class _HeroProfileScientificAvatar extends StatelessWidget {
  final IconData icon;

  const _HeroProfileScientificAvatar({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withOpacity(0.08),
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}

class _HeroProfileInitials extends StatelessWidget {
  final String initials;

  const _HeroProfileInitials({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withOpacity(0.08),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _UpcomingEventsPreview extends StatelessWidget {
  final VoidCallback onViewAll;

  const _UpcomingEventsPreview({required this.onViewAll});

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
    return '${value.day} ${monthNames[value.month - 1]}, $hour:$minute $meridiem';
  }

  List<EventModel> _nextUpcomingEvents(List<EventModel> events) {
    final now = DateTime.now();
    return events
        .where((event) => !event.isCompleted && !event.scheduledAt.isBefore(now))
        .take(3)
        .toList();
  }

  String _previewDetail(EventModel event) {
    final segments = <String>[_formatDateTime(event.scheduledAt)];
    final type = event.eventType.trim();
    final venue = event.venue.trim();

    if (type.isNotEmpty) {
      segments.add(type);
    } else if (venue.isNotEmpty) {
      segments.add(venue);
    }

    return segments.join(' - ');
  }

  static const double _eventItemHeight = 52;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Upcoming Events',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFF59E0B),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'View All',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          StreamBuilder<List<EventModel>>(
            stream: EventService().getEvents(),
            builder: (context, snapshot) {
              final upcomingEvents = _nextUpcomingEvents(snapshot.data ?? []);

              if (snapshot.connectionState == ConnectionState.waiting &&
                  upcomingEvents.isEmpty) {
                return const SizedBox(
                  height: _eventItemHeight,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF14B8A6),
                    ),
                  ),
                );
              }

              if (upcomingEvents.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'No upcoming events for this lab yet.',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12.8,
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: upcomingEvents.map((event) {
                  return _UpcomingEventTile(
                    title: event.normalizedTitle,
                    detail: _previewDetail(event),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _UpcomingEventTile extends StatelessWidget {
  final String title;
  final String detail;

  const _UpcomingEventTile({required this.title, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _UpcomingEventsPreview._eventItemHeight,
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            height: 8,
            width: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFF59E0B),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeToolCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;
  final int badgeCount;

  const _HomeToolCard({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(18),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accentColor, size: 22),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: -8,
                      top: -8,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 22,
                          minHeight: 22,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFB7185),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0xFF1E293B),
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkflowEntryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _WorkflowEntryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accentColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withOpacity(0.6),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LabActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0x2214B8A6),
                child: Icon(icon, color: const Color(0xFF14B8A6)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

