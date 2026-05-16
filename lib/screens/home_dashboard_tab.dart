import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_state.dart';
import '../models/attendance_record_model.dart';
import '../models/chemical_model.dart';
import '../models/event_model.dart';
import '../models/order_model.dart';
import '../models/requirement_model.dart';
import '../models/user_profile.dart';
import '../services/attendance_service.dart';
import '../services/consumables_inventory_service.dart';
import '../services/event_service.dart';
import '../services/firestore_access_guard.dart';
import '../services/inventory_service.dart';
import '../services/order_service.dart';
import '../services/requirement_service.dart';
import '../widgets/newly_arrived_section.dart';
import '../widgets/search_bar_widget.dart';
import 'attendance_screen.dart';
import 'consumables_inventory_screen.dart';
import 'lab_members_screen.dart';
import 'lab_settings_screen.dart';
import 'recent_activity_screen.dart';

class HomeDashboardTab extends StatelessWidget {
  final AppState appState;
  final VoidCallback onOpenChemicals;
  final VoidCallback onOpenCalculator;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenEvents;
  final VoidCallback onOpenArticles;
  final VoidCallback onOpenInstruments;
  final VoidCallback onOpenGlassApparatus;
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
    required this.onOpenGlassApparatus,
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

  Future<void> _openAttendance(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AttendanceScreen()),
    );
  }

  void _showComingSoonMessage(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(content: Text(message)));
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
    return ConsumablesInventoryService().getConsumablesInventoryDocs();
  }

  String? _firstAccessMessage(List<Object?> errors) {
    if (!FirestoreAccessGuard.shouldQueryLabScopedData(appState: appState)) {
      return FirestoreAccessGuard.userMessage;
    }

    for (final error in errors) {
      if (error != null) {
        return FirestoreAccessGuard.messageFor(error);
      }
    }

    return null;
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

  Widget _buildAccessNotice(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.lock_outline_rounded,
              color: Color(0xFFF59E0B),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12.8,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowGrid({
    required List<_DashboardToolItem> workflowItems,
    required int pendingApprovalCount,
    required int ordersInProgressCount,
    required int chemicalAttentionCount,
    required int consumablesLowStockCount,
  }) {
    final itemsWithBadges = workflowItems.map((item) {
      final badgeCount = item.id == 'cart'
          ? pendingApprovalCount
          : item.id == 'orders'
          ? ordersInProgressCount
          : item.id == 'chemical_inventory'
          ? chemicalAttentionCount
          : item.id == 'consumables_inventory'
          ? consumablesLowStockCount
          : 0;

      return item.copyWith(badgeCount: badgeCount);
    }).toList();

    return _ReorderableWorkflowGrid(items: itemsWithBadges);
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
                    'View members or open settings for the current workspace.',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                      height: 1.4,
                    ),
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
    final List<_DashboardToolItem> workflowItems = [
      _DashboardToolItem(
        id: 'chemical_inventory',
        title: 'Chemical Inventory',
        icon: Icons.science_rounded,
        accentColor: const Color(0xFF2DD4BF),
        onTap: onOpenChemicals,
      ),
      _DashboardToolItem(
        id: 'consumables_inventory',
        title: 'Consumables Inventory',
        icon: Icons.inventory_rounded,
        accentColor: const Color(0xFF60A5FA),
        onTap: () => _openConsumablesInventory(context),
      ),
      _DashboardToolItem(
        id: 'cart',
        title: 'Cart',
        icon: Icons.assignment_rounded,
        accentColor: const Color(0xFFFBBF24),
        onTap: onOpenCart,
      ),
      _DashboardToolItem(
        id: 'orders',
        title: 'Orders',
        icon: Icons.local_shipping_rounded,
        accentColor: const Color(0xFF38BDF8),
        onTap: onOpenOrders,
      ),
      _DashboardToolItem(
        id: 'calculator',
        title: 'Calculator',
        icon: Icons.calculate_rounded,
        accentColor: const Color(0xFFA78BFA),
        onTap: onOpenCalculator,
      ),
      _DashboardToolItem(
        id: 'instruments',
        title: 'Instruments',
        icon: Icons.precision_manufacturing_rounded,
        accentColor: const Color(0xFF94A3B8),
        onTap: onOpenInstruments,
      ),
      _DashboardToolItem(
        id: 'lab_manual',
        title: 'Lab Manual',
        icon: Icons.description_rounded,
        accentColor: const Color(0xFF34D399),
        onTap: onOpenLabManual,
      ),
      _DashboardToolItem(
        id: 'chemdraw',
        title: 'ChemDraw',
        icon: Icons.draw_rounded,
        accentColor: const Color(0xFFF472B6),
        onTap: onOpenChemDraw,
      ),
      _DashboardToolItem(
        id: 'log_books',
        title: 'Log books',
        icon: Icons.menu_book_outlined,
        accentColor: const Color(0xFF22C55E),
        onTap: () => _showComingSoonMessage(context, 'Log books coming soon'),
      ),
      _DashboardToolItem(
        id: 'glass_apparatus',
        title: 'Glass apparatus',
        icon: Icons.science_outlined,
        accentColor: const Color(0xFFFB923C),
        onTap: onOpenGlassApparatus,
      ),
      _DashboardToolItem(
        id: 'lab_notebook',
        title: 'Lab notebook',
        icon: Icons.edit_note_outlined,
        accentColor: const Color(0xFF38BDF8),
        onTap: () =>
            _showComingSoonMessage(context, 'Lab notebook coming soon'),
      ),
      _DashboardToolItem(
        id: 'more',
        title: 'More',
        icon: Icons.apps_outlined,
        accentColor: const Color(0xFF94A3B8),
        onTap: () => _showComingSoonMessage(context, 'More tools coming soon'),
        isFixed: true,
      ),
    ];

    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final isDesktopLayout = MediaQuery.sizeOf(context).width >= 900;
        final pagePadding = isDesktopLayout
            ? const EdgeInsets.fromLTRB(12, 8, 12, 16)
            : const EdgeInsets.fromLTRB(16, 8, 16, 20);
        final compactGap = isDesktopLayout ? 10.0 : 12.0;
        final sectionGap = isDesktopLayout ? 14.0 : 20.0;
        final heroPadding = isDesktopLayout
            ? const EdgeInsets.all(10)
            : const EdgeInsets.all(12);
        final heroRadius = BorderRadius.circular(isDesktopLayout ? 18 : 22);
        final profile = appState.profile;
        final profileName = profile.name.trim();
        final resolvedName = profileName.isEmpty || profileName == 'Your Name'
            ? appState.authenticatedUserName
            : profileName;
        final photoReference = profile.photoUrl.trim();
        final selectedLabName = appState.selectedLabName.trim();
        final visibleLabName = selectedLabName.isEmpty
            ? 'No lab selected'
            : selectedLabName;

        return SafeArea(
          child: SingleChildScrollView(
            padding: pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktopLayout ? 680 : double.infinity,
                    ),
                    child: isDesktopLayout
                        ? _DesktopDashboardSearchBar(onTap: onOpenChemicals)
                        : SearchBarWidget(onTap: onOpenChemicals),
                  ),
                ),
                SizedBox(height: compactGap),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: heroRadius,
                    onTap: () => _openHeroActions(context),
                    child: Ink(
                      width: double.infinity,
                      padding: heroPadding,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F766E), Color(0xFF0EA5E9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: heroRadius,
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
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      resolvedName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 19,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      visibleLabName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13.4,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _AttendanceStatusButton(
                                    appState: appState,
                                    onOpen: () => _openAttendance(context),
                                  ),
                                  const SizedBox(height: 8),
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
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: sectionGap),
                if (appState.shouldShowProfileReminder) ...[
                  _WorkflowEntryCard(
                    title: 'Complete Personal Information',
                    subtitle:
                        'Your profile is still incomplete. You can keep using Labmate and finish it when convenient.',
                    icon: Icons.person_outline_rounded,
                    accentColor: const Color(0xFFF59E0B),
                    onTap: onOpenProfile,
                  ),
                  SizedBox(height: sectionGap),
                ],
                if (isDesktopLayout)
                  SizedBox(
                    height: 176,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Expanded(
                          flex: 3,
                          child: NewlyArrivedSection(),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 2,
                          child: _UpcomingEventsPreview(
                            onViewAll: onOpenEvents,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  const NewlyArrivedSection(),
                  SizedBox(height: sectionGap),
                  _UpcomingEventsPreview(onViewAll: onOpenEvents),
                ],
                SizedBox(height: sectionGap),
                StreamBuilder<List<RequirementModel>>(
                  stream: RequirementService().getRequirements(),
                  builder: (context, requirementsSnapshot) {
                    final requirementsAccessMessage = _firstAccessMessage([
                      requirementsSnapshot.error,
                    ]);
                    if (requirementsAccessMessage != null) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAccessNotice(requirementsAccessMessage),
                          const SizedBox(height: 12),
                          _buildWorkflowGrid(
                            workflowItems: workflowItems,
                            pendingApprovalCount: _pendingApprovalCount(
                              requirementsSnapshot.data ?? [],
                            ),
                            ordersInProgressCount: 0,
                            chemicalAttentionCount: 0,
                            consumablesLowStockCount: 0,
                          ),
                        ],
                      );
                    }

                    return StreamBuilder<List<OrderModel>>(
                      stream: OrderService().getOrders(),
                      builder: (context, ordersSnapshot) {
                        final ordersAccessMessage = _firstAccessMessage([
                          ordersSnapshot.error,
                        ]);
                        if (ordersAccessMessage != null) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildAccessNotice(ordersAccessMessage),
                              const SizedBox(height: 12),
                              _buildWorkflowGrid(
                                workflowItems: workflowItems,
                                pendingApprovalCount: _pendingApprovalCount(
                                  requirementsSnapshot.data ?? [],
                                ),
                                ordersInProgressCount: 0,
                                chemicalAttentionCount: 0,
                                consumablesLowStockCount: 0,
                              ),
                            ],
                          );
                        }

                        return StreamBuilder<List<ChemicalModel>>(
                          stream: InventoryService().getChemicals(),
                          builder: (context, chemicalsSnapshot) {
                            final chemicalsAccessMessage = _firstAccessMessage([
                              chemicalsSnapshot.error,
                            ]);
                            if (chemicalsAccessMessage != null) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildAccessNotice(chemicalsAccessMessage),
                                  const SizedBox(height: 12),
                                  _buildWorkflowGrid(
                                    workflowItems: workflowItems,
                                    pendingApprovalCount: _pendingApprovalCount(
                                      requirementsSnapshot.data ?? [],
                                    ),
                                    ordersInProgressCount:
                                        _ordersInProgressCount(
                                          ordersSnapshot.data ?? [],
                                        ),
                                    chemicalAttentionCount: 0,
                                    consumablesLowStockCount: 0,
                                  ),
                                ],
                              );
                            }

                            return StreamBuilder<
                              List<QueryDocumentSnapshot<Map<String, dynamic>>>
                            >(
                              stream: _consumablesInventoryStream(),
                              builder: (context, consumablesSnapshot) {
                                final consumablesAccessMessage =
                                    _firstAccessMessage([
                                      consumablesSnapshot.error,
                                    ]);

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (consumablesAccessMessage != null) ...[
                                      _buildAccessNotice(
                                        consumablesAccessMessage,
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    _buildWorkflowGrid(
                                      workflowItems: workflowItems,
                                      pendingApprovalCount:
                                          _pendingApprovalCount(
                                            requirementsSnapshot.data ?? [],
                                          ),
                                      ordersInProgressCount:
                                          _ordersInProgressCount(
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
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
                SizedBox(height: sectionGap),
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

class _DesktopDashboardSearchBar extends StatelessWidget {
  final VoidCallback onTap;

  const _DesktopDashboardSearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.search_rounded,
                color: Color(0xFF5EEAD4),
                size: 19,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Search chemical by name, CAS, or functional group',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
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
      height: 72,
      width: 72,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.24), width: 1.5),
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

enum _AttendanceDashboardState { notCheckedIn, present, checkedOut }

class _AttendanceStatusButton extends StatefulWidget {
  final AppState appState;
  final Future<void> Function() onOpen;

  const _AttendanceStatusButton({required this.appState, required this.onOpen});

  @override
  State<_AttendanceStatusButton> createState() =>
      _AttendanceStatusButtonState();
}

class _AttendanceStatusButtonState extends State<_AttendanceStatusButton> {
  final AttendanceService _attendanceService = AttendanceService();
  _AttendanceDashboardState _status = _AttendanceDashboardState.notCheckedIn;
  String _trackedLabId = '';
  String _trackedUserId = '';

  String get _currentLabId => widget.appState.selectedLabId.trim();
  String get _currentUserId =>
      FirebaseAuth.instance.currentUser?.uid.trim() ?? '';

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  @override
  void didUpdateWidget(covariant _AttendanceStatusButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_trackedLabId != _currentLabId || _trackedUserId != _currentUserId) {
      _refreshStatus();
    }
  }

  _AttendanceDashboardState _statusFromRecord(AttendanceRecordModel? record) {
    if (record == null) {
      return _AttendanceDashboardState.notCheckedIn;
    }

    if (record.isCheckedOut) {
      return _AttendanceDashboardState.checkedOut;
    }

    return _AttendanceDashboardState.present;
  }

  Future<void> _refreshStatus() async {
    final labId = _currentLabId;
    final userId = _currentUserId;

    _trackedLabId = labId;
    _trackedUserId = userId;

    if (!FirestoreAccessGuard.shouldQueryLabScopedData(
          appState: widget.appState,
        ) ||
        userId.isEmpty) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status = _AttendanceDashboardState.notCheckedIn;
      });
      return;
    }

    try {
      final record = await _attendanceService.getTodayRecord(
        labId: labId,
        userId: userId,
      );
      if (!mounted) {
        return;
      }

      if (labId != _currentLabId || userId != _currentUserId) {
        return;
      }

      setState(() {
        _status = _statusFromRecord(record);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status = _AttendanceDashboardState.notCheckedIn;
      });
    }
  }

  Future<void> _handleTap() async {
    await widget.onOpen();
    if (!mounted) {
      return;
    }

    await _refreshStatus();
  }

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final IconData icon;
    late final Color accentColor;
    late final Color backgroundColor;

    switch (_status) {
      case _AttendanceDashboardState.present:
        label = 'Present';
        icon = Icons.check_circle_rounded;
        accentColor = const Color(0xFFBBF7D0);
        backgroundColor = const Color(0x3334D399);
        break;
      case _AttendanceDashboardState.checkedOut:
        label = 'Checked out';
        icon = Icons.logout_rounded;
        accentColor = const Color(0xFFBFDBFE);
        backgroundColor = const Color(0x3338BDF8);
        break;
      case _AttendanceDashboardState.notCheckedIn:
        label = 'Check in';
        icon = Icons.qr_code_scanner_rounded;
        accentColor = Colors.white;
        backgroundColor = Colors.white.withOpacity(0.14);
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: _handleTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: accentColor.withOpacity(0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14.5, color: accentColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 11.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
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
      child: Icon(icon, color: Colors.white, size: 36),
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
          fontSize: 24,
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
        .where(
          (event) => !event.isCompleted && !event.scheduledAt.isBefore(now),
        )
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
    final isDesktopLayout = MediaQuery.sizeOf(context).width >= 900;
    final eventItemHeight = isDesktopLayout ? 36.0 : _eventItemHeight;

    return Container(
      padding: isDesktopLayout
          ? const EdgeInsets.fromLTRB(12, 10, 12, 10)
          : const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: isDesktopLayout
            ? Border.all(color: Colors.white.withOpacity(0.06))
            : null,
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
              if (!FirestoreAccessGuard.shouldQueryLabScopedData()) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      FirestoreAccessGuard.userMessage,
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12.8,
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      FirestoreAccessGuard.messageFor(snapshot.error),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12.8,
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              }

              final upcomingEvents = _nextUpcomingEvents(snapshot.data ?? []);

              if (snapshot.connectionState == ConnectionState.waiting &&
                  upcomingEvents.isEmpty) {
                return SizedBox(
                  height: eventItemHeight,
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF14B8A6)),
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
                    height: eventItemHeight,
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
  final double height;

  const _UpcomingEventTile({
    required this.title,
    required this.detail,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
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

class _DashboardToolItem {
  final String id;
  final String title;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;
  final int badgeCount;
  final bool isFixed;

  const _DashboardToolItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.onTap,
    this.badgeCount = 0,
    this.isFixed = false,
  });

  _DashboardToolItem copyWith({int? badgeCount}) {
    return _DashboardToolItem(
      id: id,
      title: title,
      icon: icon,
      accentColor: accentColor,
      onTap: onTap,
      badgeCount: badgeCount ?? this.badgeCount,
      isFixed: isFixed,
    );
  }
}

class _ReorderableWorkflowGrid extends StatefulWidget {
  final List<_DashboardToolItem> items;

  const _ReorderableWorkflowGrid({required this.items});

  @override
  State<_ReorderableWorkflowGrid> createState() =>
      _ReorderableWorkflowGridState();
}

class _ReorderableWorkflowGridState extends State<_ReorderableWorkflowGrid> {
  static const String _prefsKey = 'dashboard_tool_order_v1';
  static const double _spacing = 14.0;

  List<String>? _savedMovableIds;

  @override
  void initState() {
    super.initState();
    _loadSavedOrder();
  }

  Future<void> _loadSavedOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIds = prefs.getStringList(_prefsKey);
    if (!mounted) {
      return;
    }

    setState(() {
      _savedMovableIds = savedIds;
    });
  }

  List<_DashboardToolItem> get _movableItems {
    return widget.items.where((item) => !item.isFixed).toList();
  }

  List<_DashboardToolItem> get _fixedItems {
    return widget.items.where((item) => item.isFixed).toList();
  }

  List<String> _normalizedMovableOrderIds() {
    final availableIds = _movableItems.map((item) => item.id).toList();
    final savedIds = _savedMovableIds ?? availableIds;

    final orderedIds = savedIds
        .where((id) => availableIds.contains(id))
        .toList();

    for (final id in availableIds) {
      if (!orderedIds.contains(id)) {
        orderedIds.add(id);
      }
    }

    return orderedIds;
  }

  List<_DashboardToolItem> _orderedItems() {
    final itemsById = {for (final item in widget.items) item.id: item};

    final orderedMovableItems = _normalizedMovableOrderIds()
        .map((id) => itemsById[id])
        .whereType<_DashboardToolItem>()
        .toList();

    return [...orderedMovableItems, ..._fixedItems];
  }

  Future<void> _persistMovableOrder(List<String> ids) async {
    _savedMovableIds = ids;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, ids);
  }

  Future<void> _reorderTile({
    required String draggedId,
    required String targetId,
  }) async {
    if (draggedId == targetId) {
      return;
    }

    final movableIds = _normalizedMovableOrderIds();
    if (!movableIds.contains(draggedId) || !movableIds.contains(targetId)) {
      return;
    }

    final nextOrder = List<String>.from(movableIds);
    nextOrder.remove(draggedId);
    final targetIndex = nextOrder.indexOf(targetId);
    if (targetIndex == -1) {
      nextOrder.add(draggedId);
    } else {
      nextOrder.insert(targetIndex, draggedId);
    }

    if (mounted) {
      setState(() {
        _savedMovableIds = nextOrder;
      });
    }

    await _persistMovableOrder(nextOrder);
  }

  int _columnCountForWidth(double width) {
    if (width >= 1100) {
      return 6;
    }
    if (width >= 900) {
      return 5;
    }
    if (width > 700) {
      return 4;
    }
    if (width < 360) {
      return 3;
    }
    return 4;
  }

  double _aspectRatioForWidth({
    required double width,
    required int columnCount,
  }) {
    if (width > 700) {
      return 1.12;
    }
    return columnCount == 3 ? 0.96 : 0.92;
  }

  double? _tileExtentForWidth(double width) {
    if (width > 700) {
      return 118;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final orderedItems = _orderedItems();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = _columnCountForWidth(width);
        final childAspectRatio = _aspectRatioForWidth(
          width: width,
          columnCount: crossAxisCount,
        );
        final tileExtent = _tileExtentForWidth(width);
        final tileWidth =
            (width - ((crossAxisCount - 1) * _spacing)) /
            crossAxisCount;
        final tileHeight = tileExtent ?? tileWidth / childAspectRatio;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: orderedItems.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: _spacing,
            crossAxisSpacing: _spacing,
            childAspectRatio: childAspectRatio,
            mainAxisExtent: tileExtent,
          ),
          itemBuilder: (context, index) {
            final item = orderedItems[index];
            final card = _HomeToolCard(
              title: item.title,
              icon: item.icon,
              accentColor: item.accentColor,
              onTap: item.onTap,
              badgeCount: item.badgeCount,
            );

            if (item.isFixed) {
              return card;
            }

            return DragTarget<String>(
              onWillAcceptWithDetails: (details) {
                final candidate = details.data;
                return candidate != item.id &&
                    !_fixedItems.any((fixedItem) => fixedItem.id == candidate);
              },
              onAcceptWithDetails: (details) {
                _reorderTile(draggedId: details.data, targetId: item.id);
              },
              builder: (context, candidateData, rejectedData) {
                final isActiveTarget = candidateData.isNotEmpty;

                return AnimatedScale(
                  scale: isActiveTarget ? 1.03 : 1.0,
                  duration: const Duration(milliseconds: 140),
                  child: LongPressDraggable<String>(
                    data: item.id,
                    dragAnchorStrategy: pointerDragAnchorStrategy,
                    feedback: SizedBox(
                      width: tileWidth,
                      height: tileHeight,
                      child: Material(color: Colors.transparent, child: card),
                    ),
                    childWhenDragging: Opacity(opacity: 0.35, child: card),
                    child: card,
                  ),
                );
              },
            );
          },
        );
      },
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight <= 130;
        final cardRadius = BorderRadius.circular(isCompact ? 14 : 18);
        final iconBoxSize = isCompact ? 36.0 : 42.0;
        final iconSize = isCompact ? 20.0 : 22.0;
        final verticalPadding = isCompact ? 8.0 : 10.0;
        final labelFontSize = isCompact ? 10.5 : 11.0;

        return Material(
          color: const Color(0xFF1E293B),
          borderRadius: cardRadius,
          elevation: 1,
          child: InkWell(
            borderRadius: cardRadius,
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 6,
                vertical: verticalPadding,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: iconBoxSize,
                        width: iconBoxSize,
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(
                            isCompact ? 10 : 12,
                          ),
                        ),
                        child: Icon(icon, color: accentColor, size: iconSize),
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
                  SizedBox(height: isCompact ? 7 : 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: labelFontSize,
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
      },
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
